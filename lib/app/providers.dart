import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/backup/create_backup_snapshot_use_case.dart';
import '../application/diary/create_entry_use_case.dart';
import '../application/recovery/setup_recovery_key_use_case.dart';
import '../application/recovery/unlock_with_recovery_key_use_case.dart';
import '../application/search/search_entries_use_case.dart';
import '../application/security/unlock_app_use_case.dart';
import '../domain/attachment/asset_attachment.dart';
import '../domain/diary/diary_entry.dart';
import '../domain/recovery/recovery_metadata.dart';
import '../domain/security/unlocked_vault_session.dart';
import '../domain/shared/value_objects.dart';
import '../infrastructure/crypto/crypto_service.dart';
import '../infrastructure/database/index_database.dart';
import '../infrastructure/drive/drive_backup_service.dart';
import '../infrastructure/markdown/front_matter_codec.dart';
import '../infrastructure/security/app_lock_service.dart';
import '../infrastructure/security/device_key_manager.dart';
import '../infrastructure/storage/vault_path_strategy.dart';
import '../infrastructure/storage/vault_repository.dart';
import '../presentation/state/app_session_state.dart';

const String kAndroidOnlyMessage = '目前僅支援 Android 裝置。';
const String kStartupNeedsRecoveryKeyMessage = '尚未建立 Recovery Key。';
const String kStartupNeedsTrustedDeviceMessage = '這台裝置尚未註冊，請使用 Recovery Key 解鎖。';
const String kStartupNeedsBiometricMessage = '請先完成裝置驗證。';
const String kUnlockFailedMessage = '裝置驗證失敗。';
const String kRecoveryUnlockSuccessMessage = '已使用 Recovery Key 完成解鎖。';
const String kRecoverySetupSuccessMessage = 'Recovery Key 已建立，裝置已完成註冊。';
const String kAppLockedMessage = 'App 已鎖定。';

enum HomeTab { home, calendar, overview, memories }

enum MemoryScope { month, year }

class OverviewTagStat {
  const OverviewTagStat({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;
}

class OverviewMoodStat {
  const OverviewMoodStat({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;
}

class OverviewSummary {
  const OverviewSummary({
    required this.totalEntries,
    required this.totalWords,
    required this.totalCharacters,
    required this.totalAttachments,
    required this.activeDays,
    required this.topTags,
    required this.moods,
    required this.recentEntries,
  });

  final int totalEntries;
  final int totalWords;
  final int totalCharacters;
  final int totalAttachments;
  final int activeDays;
  final List<OverviewTagStat> topTags;
  final List<OverviewMoodStat> moods;
  final List<EntryIndexRecord> recentEntries;
}

class MemorySummary {
  const MemorySummary({
    required this.title,
    required this.totalEntries,
    required this.totalWords,
    required this.totalAttachments,
    required this.topTags,
    required this.highlightDates,
  });

  final String title;
  final int totalEntries;
  final int totalWords;
  final int totalAttachments;
  final List<OverviewTagStat> topTags;
  final List<DateOnly> highlightDates;
}

final supportedPlatformProvider = Provider<bool>((Ref ref) {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
});

final vaultPathStrategyProvider = Provider<VaultPathStrategy>((Ref ref) {
  return const VaultPathStrategy();
});

final frontMatterCodecProvider = Provider<FrontMatterCodec>((Ref ref) {
  return const FrontMatterCodec();
});

final deviceKeyManagerProvider = Provider<DeviceKeyManager>((Ref ref) {
  if (!ref.watch(supportedPlatformProvider)) {
    return const UnsupportedDeviceKeyManager();
  }
  return AndroidDeviceKeyManager();
});

final cryptoServiceProvider = Provider<CryptoService>((Ref ref) {
  return LocalCryptoService(
    deviceKeyManager: ref.watch(deviceKeyManagerProvider),
  );
});

final appLockServiceProvider = Provider<AppLockService>((Ref ref) {
  if (!ref.watch(supportedPlatformProvider)) {
    return const UnsupportedAppLockService();
  }
  return LocalAppLockService();
});

final driveBackupServiceProvider = Provider<DriveBackupService>((Ref ref) {
  return GoogleDriveBackupService();
});

final indexDatabaseProvider = Provider<IndexDatabase>((Ref ref) {
  return IndexDatabase(ref.watch(vaultPathStrategyProvider));
});

final vaultRepositoryProvider = Provider<VaultRepository>((Ref ref) {
  return VaultRepository(
    pathStrategy: ref.watch(vaultPathStrategyProvider),
    frontMatterCodec: ref.watch(frontMatterCodecProvider),
    cryptoService: ref.watch(cryptoServiceProvider),
    indexDatabase: ref.watch(indexDatabaseProvider),
    deviceKeyManager: ref.watch(deviceKeyManagerProvider),
    driveBackupService: ref.watch(driveBackupServiceProvider),
  );
});

/// Bumped after index DB changes so encrypted cover thumbnails refetch (same path can hold new bytes).
class EntryIndexRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    state = state + 1;
  }
}

final entryIndexRevisionProvider = NotifierProvider<EntryIndexRevision, int>(
  EntryIndexRevision.new,
);

/// Raw decrypted bytes for an encrypted asset file path (e.g. list cover image).
final entryCoverPreviewBytesProvider =
    FutureProvider.autoDispose.family<Uint8List?, String>((Ref ref, String encPath) async {
  ref.watch(entryIndexRevisionProvider);
  final String path = encPath.trim();
  if (path.isEmpty) {
    return null;
  }
  final AppSessionState state = await ref.watch(effectiveAppSessionProvider.future);
  if (!state.isUnlocked || state.session == null) {
    return null;
  }
  return ref.read(vaultRepositoryProvider).readDecryptedAssetBytes(state.session!, path);
});

class AppSessionController extends Notifier<AppSessionState> {
  @override
  AppSessionState build() {
    return const AppSessionState(status: AppLockStatus.uninitialized);
  }

  Future<bool> unlock(UnlockAppUseCase useCase) async {
    state = state.copyWith(status: AppLockStatus.unlocking, clearMessage: true);
    final bool success = await useCase.call();
    state = state.copyWith(
      status: success ? AppLockStatus.unlocked : AppLockStatus.locked,
      message: success ? null : kUnlockFailedMessage,
      clearMessage: success,
    );
    return success;
  }

  Future<void> unlockWithRecovery(
    String recoveryKey,
    UnlockWithRecoveryKeyUseCase useCase,
  ) async {
    state = state.copyWith(status: AppLockStatus.unlocking, clearMessage: true);
    try {
      final UnlockedVaultSession session = await useCase.call(recoveryKey);
      state = AppSessionState(
        status: AppLockStatus.unlocked,
        session: session,
        message: kRecoveryUnlockSuccessMessage,
      );
    } catch (error) {
      state = state.copyWith(
        status: AppLockStatus.recoveryRequired,
        clearSession: true,
        message: '$error',
      );
      rethrow;
    }
  }

  Future<void> lock(AppLockService appLockService) async {
    await appLockService.lock();
    state = state.copyWith(
      status: AppLockStatus.locked,
      message: kAppLockedMessage,
    );
  }

  void activateSession(
    UnlockedVaultSession session, {
    String? message,
  }) {
    state = AppSessionState(
      status: AppLockStatus.unlocked,
      session: session,
      message: message,
    );
  }

  void reset() {
    state = const AppSessionState(status: AppLockStatus.uninitialized);
  }
}

final appSessionProvider = NotifierProvider<AppSessionController, AppSessionState>(
  AppSessionController.new,
);

final appStartupProvider = FutureProvider<AppSessionState>((Ref ref) async {
  if (!ref.watch(supportedPlatformProvider)) {
    return const AppSessionState(
      status: AppLockStatus.fatalError,
      message: kAndroidOnlyMessage,
    );
  }

  final VaultRepository repository = ref.read(vaultRepositoryProvider);
  final AppLockService appLockService = ref.read(appLockServiceProvider);

  try {
    await repository.initialize();

    final RecoveryMetadata? metadata = await repository.readRecoveryMetadata();
    if (metadata == null) {
      return const AppSessionState(
        status: AppLockStatus.unlocked,
        message: kStartupNeedsRecoveryKeyMessage,
      );
    }

    final bool hasTrustedDevice = await repository.hasTrustedDeviceAccess();
    if (!hasTrustedDevice) {
      return const AppSessionState(
        status: AppLockStatus.recoveryRequired,
        message: kStartupNeedsTrustedDeviceMessage,
      );
    }

    final UnlockedVaultSession session = await repository.openTrustedSession();
    if ((await ref.read(indexDatabaseProvider).getAppValue('last_rebuild_at')) == null) {
      await repository.rebuildIndex(session);
    }

    if (await appLockService.isSessionLocked()) {
      return AppSessionState(
        status: AppLockStatus.locked,
        session: session,
        message: kStartupNeedsBiometricMessage,
      );
    }

    return AppSessionState(
      status: AppLockStatus.unlocked,
      session: session,
    );
  } catch (error) {
    return AppSessionState(
      status: AppLockStatus.fatalError,
      message: '$error',
    );
  }
});

final effectiveAppSessionProvider = FutureProvider<AppSessionState>((Ref ref) async {
  final AppSessionState startupState = await ref.watch(appStartupProvider.future);
  final AppSessionState localState = ref.watch(appSessionProvider);
  if (localState.status == AppLockStatus.uninitialized) {
    return startupState;
  }
  return localState;
});

final createEntryUseCaseProvider = Provider<CreateEntryUseCase>((Ref ref) {
  return CreateEntryUseCase(ref.watch(vaultRepositoryProvider));
});

final searchEntriesUseCaseProvider = Provider<SearchEntriesUseCase>((Ref ref) {
  return SearchEntriesUseCase(ref.watch(indexDatabaseProvider));
});

final setupRecoveryKeyUseCaseProvider = Provider<SetupRecoveryKeyUseCase>((Ref ref) {
  return SetupRecoveryKeyUseCase(ref.watch(vaultRepositoryProvider));
});

final unlockWithRecoveryKeyUseCaseProvider =
    Provider<UnlockWithRecoveryKeyUseCase>((Ref ref) {
  return UnlockWithRecoveryKeyUseCase(ref.watch(vaultRepositoryProvider));
});

final createBackupSnapshotUseCaseProvider =
    Provider<CreateBackupSnapshotUseCase>((Ref ref) {
  return CreateBackupSnapshotUseCase(ref.watch(vaultRepositoryProvider));
});

final unlockAppUseCaseProvider = Provider<UnlockAppUseCase>((Ref ref) {
  return UnlockAppUseCase(ref.watch(appLockServiceProvider));
});

class HomeTabController extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.home;

  void set(HomeTab value) => state = value;
}

class HomeSearchQueryController extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
}

class CalendarSelectedDateController extends Notifier<DateOnly?> {
  @override
  DateOnly? build() => null;

  void set(DateOnly? value) => state = value;
}

class CalendarVisibleMonthController extends Notifier<DateTime> {
  @override
  DateTime build() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void set(DateTime value) => state = DateTime(value.year, value.month);
}

class OverviewTagFilterController extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

class MemoryScopeController extends Notifier<MemoryScope> {
  @override
  MemoryScope build() => MemoryScope.month;

  void set(MemoryScope value) => state = value;
}

class MemoryFocusedMonthController extends Notifier<DateTime> {
  @override
  DateTime build() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void set(DateTime value) => state = DateTime(value.year, value.month);
}

class MemoryFocusedYearController extends Notifier<int> {
  @override
  int build() => DateTime.now().year;

  void set(int value) => state = value;
}

final homeTabProvider = NotifierProvider<HomeTabController, HomeTab>(
  HomeTabController.new,
);

final homeSearchQueryProvider = NotifierProvider<HomeSearchQueryController, String>(
  HomeSearchQueryController.new,
);

final calendarSelectedDateProvider =
    NotifierProvider<CalendarSelectedDateController, DateOnly?>(
  CalendarSelectedDateController.new,
);

final calendarVisibleMonthProvider =
    NotifierProvider<CalendarVisibleMonthController, DateTime>(
  CalendarVisibleMonthController.new,
);

final overviewTagFilterProvider = NotifierProvider<OverviewTagFilterController, String?>(
  OverviewTagFilterController.new,
);

final memoryScopeProvider = NotifierProvider<MemoryScopeController, MemoryScope>(
  MemoryScopeController.new,
);

final memoryFocusedMonthProvider =
    NotifierProvider<MemoryFocusedMonthController, DateTime>(
  MemoryFocusedMonthController.new,
);

final memoryFocusedYearProvider = NotifierProvider<MemoryFocusedYearController, int>(
  MemoryFocusedYearController.new,
);

final allEntryIndexRecordsProvider = FutureProvider<List<EntryIndexRecord>>((Ref ref) async {
  final AppSessionState sessionState = await ref.watch(effectiveAppSessionProvider.future);
  if (!sessionState.isUnlocked || sessionState.session == null) {
    return const <EntryIndexRecord>[];
  }

  return ref.read(vaultRepositoryProvider).listEntries();
});

final homeEntriesProvider = FutureProvider<List<EntryIndexRecord>>((Ref ref) async {
  final AppSessionState sessionState = await ref.watch(effectiveAppSessionProvider.future);
  if (!sessionState.isUnlocked || sessionState.session == null) {
    return const <EntryIndexRecord>[];
  }

  final String query = ref.watch(homeSearchQueryProvider);
  return ref.read(vaultRepositoryProvider).listEntries(
        searchQuery: query.isEmpty ? null : query,
      );
});

final calendarEntriesProvider = FutureProvider<List<EntryIndexRecord>>((Ref ref) async {
  final AppSessionState sessionState = await ref.watch(effectiveAppSessionProvider.future);
  if (!sessionState.isUnlocked || sessionState.session == null) {
    return const <EntryIndexRecord>[];
  }

  final DateOnly? date = ref.watch(calendarSelectedDateProvider);
  if (date == null) {
    return const <EntryIndexRecord>[];
  }

  return ref.read(vaultRepositoryProvider).listEntries(date: date);
});

final calendarMonthEntryDatesProvider = FutureProvider<List<DateOnly>>((Ref ref) async {
  final AppSessionState sessionState = await ref.watch(effectiveAppSessionProvider.future);
  if (!sessionState.isUnlocked || sessionState.session == null) {
    return const <DateOnly>[];
  }

  return ref.read(vaultRepositoryProvider).monthEntryDates(
        ref.watch(calendarVisibleMonthProvider),
      );
});

final overviewSummaryProvider = FutureProvider<OverviewSummary>((Ref ref) async {
  final List<EntryIndexRecord> entries = await ref.watch(allEntryIndexRecordsProvider.future);
  final Map<String, int> tagCounts = <String, int>{};
  final Map<String, int> moodCounts = <String, int>{};
  int totalWords = 0;
  int totalCharacters = 0;
  int totalAttachments = 0;

  for (final EntryIndexRecord entry in entries) {
    totalWords += entry.wordCount;
    totalCharacters += entry.charCount;
    totalAttachments += entry.attachmentCount;
    for (final String tag in entry.tags) {
      tagCounts.update(tag, (int count) => count + 1, ifAbsent: () => 1);
    }
    final String? mood = entry.mood?.trim();
    if (mood != null && mood.isNotEmpty) {
      moodCounts.update(mood, (int count) => count + 1, ifAbsent: () => 1);
    }
  }

  final List<OverviewTagStat> topTags = tagCounts.entries
      .map((MapEntry<String, int> item) => OverviewTagStat(label: item.key, count: item.value))
      .toList()
    ..sort((OverviewTagStat a, OverviewTagStat b) => b.count.compareTo(a.count));

  final List<OverviewMoodStat> moods = moodCounts.entries
      .map((MapEntry<String, int> item) => OverviewMoodStat(label: item.key, count: item.value))
      .toList()
    ..sort((OverviewMoodStat a, OverviewMoodStat b) => b.count.compareTo(a.count));

  final List<EntryIndexRecord> recentEntries = List<EntryIndexRecord>.from(entries)
    ..sort((EntryIndexRecord a, EntryIndexRecord b) => b.updatedAt.compareTo(a.updatedAt));

  return OverviewSummary(
    totalEntries: entries.length,
    totalWords: totalWords,
    totalCharacters: totalCharacters,
    totalAttachments: totalAttachments,
    activeDays: entries.map((EntryIndexRecord item) => item.date.value).toSet().length,
    topTags: topTags.take(8).toList(),
    moods: moods.take(6).toList(),
    recentEntries: recentEntries.take(6).toList(),
  );
});

final overviewTaggedEntriesProvider = FutureProvider<List<EntryIndexRecord>>((Ref ref) async {
  final String? tag = ref.watch(overviewTagFilterProvider);
  if (tag == null || tag.isEmpty) {
    return const <EntryIndexRecord>[];
  }

  final List<EntryIndexRecord> entries = await ref.watch(allEntryIndexRecordsProvider.future);
  return entries.where((EntryIndexRecord item) => item.tags.contains(tag)).toList()
    ..sort((EntryIndexRecord a, EntryIndexRecord b) => b.updatedAt.compareTo(a.updatedAt));
});

final memoryAvailableYearsProvider = FutureProvider<List<int>>((Ref ref) async {
  final List<EntryIndexRecord> entries = await ref.watch(allEntryIndexRecordsProvider.future);
  final List<int> years = entries.map((EntryIndexRecord item) => item.date.year).toSet().toList()
    ..sort();
  return years;
});

final memoryEntriesProvider = FutureProvider<List<EntryIndexRecord>>((Ref ref) async {
  final List<EntryIndexRecord> entries = await ref.watch(allEntryIndexRecordsProvider.future);
  final MemoryScope scope = ref.watch(memoryScopeProvider);
  if (scope == MemoryScope.month) {
    final DateTime focusedMonth = ref.watch(memoryFocusedMonthProvider);
    return entries.where((EntryIndexRecord item) {
      final DateTime date = item.date.toDateTime();
      return date.year == focusedMonth.year && date.month == focusedMonth.month;
    }).toList()
      ..sort((EntryIndexRecord a, EntryIndexRecord b) => b.updatedAt.compareTo(a.updatedAt));
  }

  final int focusedYear = ref.watch(memoryFocusedYearProvider);
  return entries.where((EntryIndexRecord item) => item.date.year == focusedYear).toList()
    ..sort((EntryIndexRecord a, EntryIndexRecord b) => b.updatedAt.compareTo(a.updatedAt));
});

final memorySummaryProvider = FutureProvider<MemorySummary>((Ref ref) async {
  final MemoryScope scope = ref.watch(memoryScopeProvider);
  final List<EntryIndexRecord> entries = await ref.watch(memoryEntriesProvider.future);
  final Map<String, int> tagCounts = <String, int>{};
  int totalWords = 0;
  int totalAttachments = 0;

  for (final EntryIndexRecord entry in entries) {
    totalWords += entry.wordCount;
    totalAttachments += entry.attachmentCount;
    for (final String tag in entry.tags) {
      tagCounts.update(tag, (int count) => count + 1, ifAbsent: () => 1);
    }
  }

  final List<OverviewTagStat> topTags = tagCounts.entries
      .map((MapEntry<String, int> item) => OverviewTagStat(label: item.key, count: item.value))
      .toList()
    ..sort((OverviewTagStat a, OverviewTagStat b) => b.count.compareTo(a.count));

  final String title = scope == MemoryScope.month
      ? _formatMemoryMonth(ref.watch(memoryFocusedMonthProvider))
      : '${ref.watch(memoryFocusedYearProvider)} 年回顧';

  return MemorySummary(
    title: title,
    totalEntries: entries.length,
    totalWords: totalWords,
    totalAttachments: totalAttachments,
    topTags: topTags.take(6).toList(),
    highlightDates: entries.map((EntryIndexRecord item) => item.date).take(6).toList(),
  );
});

String _formatMemoryMonth(DateTime value) {
  final String year = value.year.toString().padLeft(4, '0');
  final String month = value.month.toString().padLeft(2, '0');
  return '$year 年 $month 月回顧';
}

/// Reload index-backed lists and drop stale cover/image caches after save, delete, restore, etc.
Future<void> refreshEntryIndexCaches(WidgetRef ref, {EntryId? editedEntryId}) async {
  ref
    ..invalidate(homeEntriesProvider)
    ..invalidate(calendarMonthEntryDatesProvider)
    ..invalidate(calendarEntriesProvider)
    ..invalidate(allEntryIndexRecordsProvider);

  await Future.wait<void>(<Future<void>>[
    ref.read(homeEntriesProvider.future),
    ref.read(calendarMonthEntryDatesProvider.future),
    ref.read(calendarEntriesProvider.future),
    ref.read(allEntryIndexRecordsProvider.future),
  ]);

  ref.read(entryIndexRevisionProvider.notifier).bump();

  final EntryId? id = editedEntryId?.trim();
  if (id != null && id.isNotEmpty) {
    ref.invalidate(entryProvider(id));
  }
}

final recoveryMetadataProvider = FutureProvider<RecoveryMetadata?>((Ref ref) async {
  if (!ref.watch(supportedPlatformProvider)) {
    return null;
  }
  await ref.watch(appStartupProvider.future);
  return ref.read(vaultRepositoryProvider).readRecoveryMetadata();
});

final backupHistoryProvider = FutureProvider<List<BackupHistoryRecord>>((Ref ref) async {
  if (!ref.watch(supportedPlatformProvider)) {
    return const <BackupHistoryRecord>[];
  }
  await ref.watch(appStartupProvider.future);
  return ref.read(indexDatabaseProvider).listBackups();
});

final activeVaultSessionProvider = FutureProvider<UnlockedVaultSession?>((Ref ref) async {
  final AppSessionState sessionState = await ref.watch(effectiveAppSessionProvider.future);
  return sessionState.isUnlocked ? sessionState.session : null;
});

final entryProvider = FutureProvider.family<DiaryEntry?, EntryId>((Ref ref, EntryId entryId) async {
  final UnlockedVaultSession? session = await ref.watch(activeVaultSessionProvider.future);
  if (session == null) {
    return null;
  }
  return ref.read(vaultRepositoryProvider).loadEntry(session, entryId);
});

final entryAttachmentsProvider =
    FutureProvider.family<List<AssetAttachment>, EntryId>((Ref ref, EntryId entryId) async {
  await ref.watch(activeVaultSessionProvider.future);
  return ref.read(vaultRepositoryProvider).loadAttachments(entryId);
});
