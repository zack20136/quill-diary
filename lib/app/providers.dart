import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/backup/create_backup_snapshot_use_case.dart';
import '../application/diary/create_entry_use_case.dart';
import '../application/recovery/setup_recovery_key_use_case.dart';
import '../application/search/search_entries_use_case.dart';
import '../application/security/unlock_app_use_case.dart';
import '../domain/attachment/asset_attachment.dart';
import '../domain/diary/diary_entry.dart';
import '../domain/recovery/recovery_metadata.dart';
import '../domain/shared/value_objects.dart';
import '../infrastructure/crypto/crypto_service.dart';
import '../infrastructure/database/index_database.dart';
import '../infrastructure/drive/drive_backup_service.dart';
import '../infrastructure/markdown/front_matter_codec.dart';
import '../infrastructure/security/app_lock_service.dart';
import '../infrastructure/storage/vault_path_strategy.dart';
import '../infrastructure/storage/vault_repository.dart';
import '../presentation/state/app_session_state.dart';

final vaultPathStrategyProvider = Provider<VaultPathStrategy>((Ref ref) {
  return const VaultPathStrategy();
});

final frontMatterCodecProvider = Provider<FrontMatterCodec>((Ref ref) {
  return const FrontMatterCodec();
});

final cryptoServiceProvider = Provider<CryptoService>((Ref ref) {
  return LocalCryptoService();
});

final appLockServiceProvider = Provider<AppLockService>((Ref ref) {
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
    appLockService: ref.watch(appLockServiceProvider),
    driveBackupService: ref.watch(driveBackupServiceProvider),
  );
});

class AppSessionController extends Notifier<AppSessionState> {
  @override
  AppSessionState build() {
    return const AppSessionState(status: AppLockStatus.uninitialized);
  }

  Future<bool> unlock(UnlockAppUseCase useCase) async {
    state = state.copyWith(status: AppLockStatus.unlocking, message: null);
    final bool success = await useCase.call();
    state = state.copyWith(
      status: success ? AppLockStatus.unlocked : AppLockStatus.locked,
      message: success ? null : '解鎖失敗，請再試一次。',
      clearMessage: success,
    );
    return success;
  }

  Future<void> lock(AppLockService appLockService) async {
    await appLockService.lock();
    state = state.copyWith(status: AppLockStatus.locked, message: 'App 已鎖定。');
  }
}

final appSessionProvider =
    NotifierProvider<AppSessionController, AppSessionState>(
  AppSessionController.new,
);

final appStartupProvider = FutureProvider<AppSessionState>((Ref ref) async {
  final VaultRepository repository = ref.read(vaultRepositoryProvider);
  final AppLockService appLockService = ref.read(appLockServiceProvider);
  await repository.initialize();
  return appLockService.initialize();
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

final createBackupSnapshotUseCaseProvider =
    Provider<CreateBackupSnapshotUseCase>((Ref ref) {
  return CreateBackupSnapshotUseCase(ref.watch(vaultRepositoryProvider));
});

final unlockAppUseCaseProvider = Provider<UnlockAppUseCase>((Ref ref) {
  return UnlockAppUseCase(ref.watch(appLockServiceProvider));
});

class TimelineSearchQueryController extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
}

class SelectedDateController extends Notifier<DateOnly?> {
  @override
  DateOnly? build() => null;

  void set(DateOnly? value) => state = value;
}

class VisibleMonthController extends Notifier<DateTime> {
  @override
  DateTime build() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void set(DateTime value) => state = DateTime(value.year, value.month);
}

final timelineSearchQueryProvider =
    NotifierProvider<TimelineSearchQueryController, String>(
  TimelineSearchQueryController.new,
);

final selectedDateProvider =
    NotifierProvider<SelectedDateController, DateOnly?>(
  SelectedDateController.new,
);

final visibleMonthProvider =
    NotifierProvider<VisibleMonthController, DateTime>(
  VisibleMonthController.new,
);

final timelineEntriesProvider = FutureProvider<List<EntryIndexRecord>>((Ref ref) async {
  await ref.watch(appStartupProvider.future);
  final String query = ref.watch(timelineSearchQueryProvider);
  final DateOnly? date = ref.watch(selectedDateProvider);
  return ref.read(vaultRepositoryProvider).listEntries(
        searchQuery: query.isEmpty ? null : query,
        date: date,
      );
});

final monthEntryDatesProvider = FutureProvider<List<DateOnly>>((Ref ref) async {
  await ref.watch(appStartupProvider.future);
  return ref.read(vaultRepositoryProvider).monthEntryDates(
        ref.watch(visibleMonthProvider),
      );
});

final recoveryMetadataProvider = FutureProvider<RecoveryMetadata?>((Ref ref) async {
  await ref.watch(appStartupProvider.future);
  return ref.read(vaultRepositoryProvider).readRecoveryMetadata();
});

final backupHistoryProvider = FutureProvider<List<BackupHistoryRecord>>((Ref ref) async {
  await ref.watch(appStartupProvider.future);
  return ref.read(indexDatabaseProvider).listBackups();
});

final entryProvider =
    FutureProvider.family<DiaryEntry?, EntryId>((Ref ref, EntryId entryId) async {
  await ref.watch(appStartupProvider.future);
  return ref.read(vaultRepositoryProvider).loadEntry(entryId);
});

final entryAttachmentsProvider = FutureProvider.family<List<AssetAttachment>, EntryId>(
  (Ref ref, EntryId entryId) async {
    await ref.watch(appStartupProvider.future);
    return ref.read(vaultRepositoryProvider).loadAttachments(entryId);
  },
);
