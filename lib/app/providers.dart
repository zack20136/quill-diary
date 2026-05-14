import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/backup/create_backup_snapshot_use_case.dart';
import '../application/diary/create_entry_use_case.dart';
import '../application/diary/diary_presence_tag_counts.dart';
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

enum HomeTab { home, calendar, overview, tags }

enum MemoryScope { all, month, year }

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
    required this.entriesWithTags,
    required this.entriesWithAttachments,
    required this.entriesWithMoodSet,
    required this.avgWordsPerEntryRounded,
    required this.topTags,
    required this.moods,
  });

  final int totalEntries;
  final int totalWords;
  final int totalCharacters;
  final int totalAttachments;
  final int activeDays;
  /// Entries with ≥1 tag.
  final int entriesWithTags;
  /// Entries with ≥1 attachment.
  final int entriesWithAttachments;
  /// Entries with non-empty mood.
  final int entriesWithMoodSet;
  final int avgWordsPerEntryRounded;
  final List<OverviewTagStat> topTags;
  final List<OverviewMoodStat> moods;
}

/// 依「總覽 · 範圍」（全部／年／月篩選後的日記列表）統計資料概覽方塊。
class OverviewScopeMetrics {
  const OverviewScopeMetrics({
    required this.totalEntries,
    required this.totalWords,
    required this.totalCharacters,
    required this.totalAttachments,
    required this.activeDays,
    required this.entriesWithTags,
    required this.entriesWithAttachments,
    required this.entriesWithMoodSet,
    required this.avgWordsPerEntryRounded,
  });

  final int totalEntries;
  final int totalWords;
  final int totalCharacters;
  final int totalAttachments;
  final int activeDays;
  final int entriesWithTags;
  final int entriesWithAttachments;
  final int entriesWithMoodSet;
  final int avgWordsPerEntryRounded;

  factory OverviewScopeMetrics.empty() => const OverviewScopeMetrics(
        totalEntries: 0,
        totalWords: 0,
        totalCharacters: 0,
        totalAttachments: 0,
        activeDays: 0,
        entriesWithTags: 0,
        entriesWithAttachments: 0,
        entriesWithMoodSet: 0,
        avgWordsPerEntryRounded: 0,
      );

  factory OverviewScopeMetrics.fromEntries(List<EntryIndexRecord> entries) {
    if (entries.isEmpty) {
      return OverviewScopeMetrics.empty();
    }
    int totalWords = 0;
    int totalCharacters = 0;
    int totalAttachments = 0;
    int tagged = 0;
    int withAttachments = 0;
    int withMood = 0;

    for (final EntryIndexRecord entry in entries) {
      totalWords += entry.wordCount;
      totalCharacters += entry.charCount;
      totalAttachments += entry.attachmentCount;
      if (entry.tags.isNotEmpty) {
        tagged++;
      }
      if (entry.attachmentCount > 0) {
        withAttachments++;
      }
      final String? mood = entry.mood?.trim();
      if (mood != null && mood.isNotEmpty) {
        withMood++;
      }
    }

    final int activeDays =
        entries.map((EntryIndexRecord item) => item.date.value).toSet().length;
    final int avgWordsRounded = (totalWords / entries.length).round();

    return OverviewScopeMetrics(
      totalEntries: entries.length,
      totalWords: totalWords,
      totalCharacters: totalCharacters,
      totalAttachments: totalAttachments,
      activeDays: activeDays,
      entriesWithTags: tagged,
      entriesWithAttachments: withAttachments,
      entriesWithMoodSet: withMood,
      avgWordsPerEntryRounded: avgWordsRounded,
    );
  }

  String? writingDensitySubtitle() {
    if (totalEntries <= 0 || activeDays <= 0) {
      return null;
    }
    final int numerator = totalEntries * 10 ~/ activeDays;
    final int hi = numerator ~/ 10;
    final int lo = numerator % 10;
    final String pace = lo == 0 ? '$hi' : '$hi.$lo';
    return '有紀錄日約 $pace 篇';
  }

  String annotationMixedDetail() =>
      '$entriesWithTags 篇標籤 · $entriesWithAttachments 篇附件 · $entriesWithMoodSet 篇心情';
}
int _compareEntriesNewestFirst(EntryIndexRecord a, EntryIndexRecord b) {
  final int byDate = b.date.value.compareTo(a.date.value);
  if (byDate != 0) {
    return byDate;
  }
  return b.updatedAt.compareTo(a.updatedAt);
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

/// 依 `normalizeText(標籤)` 對應自訂主色 ARGB（本機索引庫）。
final tagAccentArgbMapProvider = FutureProvider<Map<String, int>>((Ref ref) async {
  return ref.watch(indexDatabaseProvider).fetchTagAccentArgbMap();
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
  MemoryScope build() => MemoryScope.all;

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
  final List<EntryIndexRecord> list = await ref.read(vaultRepositoryProvider).listEntries(
        searchQuery: query.isEmpty ? null : query,
      );
  list.sort(_compareEntriesNewestFirst);
  return list;
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
  final Map<String, int> moodCounts = <String, int>{};
  int totalWords = 0;
  int totalCharacters = 0;
  int totalAttachments = 0;
  int entriesWithTags = 0;
  int entriesWithAttachments = 0;
  int entriesWithMoodSet = 0;

  for (final EntryIndexRecord entry in entries) {
    totalWords += entry.wordCount;
    totalCharacters += entry.charCount;
    totalAttachments += entry.attachmentCount;
    if (entry.tags.isNotEmpty) {
      entriesWithTags++;
    }
    if (entry.attachmentCount > 0) {
      entriesWithAttachments++;
    }
    final String? mood = entry.mood?.trim();
    if (mood != null && mood.isNotEmpty) {
      entriesWithMoodSet++;
      moodCounts.update(mood, (int count) => count + 1, ifAbsent: () => 1);
    }
  }

  final Map<String, int> tagCounts = diaryPresenceTagCounts(entries);

  final List<OverviewTagStat> topTags = tagCounts.entries
      .map((MapEntry<String, int> item) => OverviewTagStat(label: item.key, count: item.value))
      .toList()
    ..sort((OverviewTagStat a, OverviewTagStat b) => b.count.compareTo(a.count));

  final List<OverviewMoodStat> moods = moodCounts.entries
      .map((MapEntry<String, int> item) => OverviewMoodStat(label: item.key, count: item.value))
      .toList()
    ..sort((OverviewMoodStat a, OverviewMoodStat b) => b.count.compareTo(a.count));

  final int avgWordsPerEntryRounded =
      entries.isEmpty ? 0 : (totalWords / entries.length).round();

  return OverviewSummary(
    totalEntries: entries.length,
    totalWords: totalWords,
    totalCharacters: totalCharacters,
    totalAttachments: totalAttachments,
    activeDays: entries.map((EntryIndexRecord item) => item.date.value).toSet().length,
    entriesWithTags: entriesWithTags,
    entriesWithAttachments: entriesWithAttachments,
    entriesWithMoodSet: entriesWithMoodSet,
    avgWordsPerEntryRounded: avgWordsPerEntryRounded,
    topTags: topTags.take(8).toList(),
    moods: moods.take(6).toList(),
  );
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
  if (scope == MemoryScope.all) {
    return List<EntryIndexRecord>.from(entries)..sort(_compareEntriesNewestFirst);
  }
  if (scope == MemoryScope.year) {
    final int focusedYear = ref.watch(memoryFocusedYearProvider);
    return entries.where((EntryIndexRecord item) => item.date.year == focusedYear).toList()
      ..sort(_compareEntriesNewestFirst);
  }

  final DateTime focusedMonth = ref.watch(memoryFocusedMonthProvider);
  return entries.where((EntryIndexRecord item) {
    final DateTime date = item.date.toDateTime();
    return date.year == focusedMonth.year && date.month == focusedMonth.month;
  }).toList()
    ..sort(_compareEntriesNewestFirst);
});

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
  ref.watch(entryIndexRevisionProvider);
  return ref.read(vaultRepositoryProvider).loadAttachments(entryId);
});
