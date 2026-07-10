import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/session/app_session_controller.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/settings/settings_flow_controller.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/security/security_providers.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/external_directory_store.dart';
import 'package:quill_diary/infrastructure/storage/portable_transfer_service.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_backup_service.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/infrastructure/storage/vault_repair_service.dart';
import 'package:quill_diary/infrastructure/storage/vault_restore_service.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_models.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../helpers/session/fake_app_lock_service.dart';
import '../../helpers/session/fake_session_vault_repository.dart';
import '../../helpers/vault/test_vault_path_strategy.dart';

class _FlowBackupService extends VaultBackupService {
  _FlowBackupService({this.driveBackups = const <DriveBackupFile>[]})
    : super(
        archiveIo: VaultArchiveIo(
          pathStrategy: DummyVaultPathStrategy(),
          repository: FakeSessionVaultRepository(),
          frontMatterCodec: const FrontMatterCodec(),
          indexDatabaseManager: IndexDatabaseManager(DummyVaultPathStrategy()),
          editorDraftStore: EditorDraftStore(
            pathStrategy: DummyVaultPathStrategy(),
            cryptoService: LocalCryptoService(),
          ),
        ),
        driveBackupService: _UnusedDriveBackupService(),
        externalDirectoryStore: ExternalDirectoryStore(
          DummyVaultPathStrategy(),
        ),
        pathStrategy: DummyVaultPathStrategy(),
      );

  final List<DriveBackupFile> driveBackups;
  int deleteAppLocalBackupCalls = 0;
  int deleteDriveBackupCalls = 0;

  @override
  Future<List<DriveBackupFile>> listDriveBackups() async => driveBackups;

  @override
  Future<void> deleteAppLocalBackup(LocalBackupFile backup) async {
    deleteAppLocalBackupCalls++;
  }

  @override
  Future<void> deleteDriveBackup(DriveBackupFile backup) async {
    deleteDriveBackupCalls++;
  }
}

class _FlowRestoreService extends VaultRestoreService {
  _FlowRestoreService({this.downloadedFile, this.precheckError})
    : super(
        archiveIo: VaultArchiveIo(
          pathStrategy: DummyVaultPathStrategy(),
          repository: FakeSessionVaultRepository(),
          frontMatterCodec: const FrontMatterCodec(),
          indexDatabaseManager: IndexDatabaseManager(DummyVaultPathStrategy()),
          editorDraftStore: EditorDraftStore(
            pathStrategy: DummyVaultPathStrategy(),
            cryptoService: LocalCryptoService(),
          ),
        ),
        vaultRepository: FakeSessionVaultRepository(),
        backupService: _FlowBackupService(),
        pathStrategy: DummyVaultPathStrategy(),
      );

  final File? downloadedFile;
  final Object? precheckError;

  @override
  Future<File> downloadDriveBackupToTempFile(
    DriveBackupFile backup, {
    BackupTaskProgressListener? onProgress,
  }) async {
    if (downloadedFile == null) {
      throw UnimplementedError('downloadedFile not configured');
    }
    return downloadedFile!;
  }

  @override
  Future<RestorePrecheck> precheckRestore(File backupFile) async {
    if (precheckError != null) {
      throw precheckError!;
    }
    throw UnimplementedError('precheckRestore should be configured per test');
  }
}

class _UnusedDriveBackupService implements DriveBackupService {
  @override
  Future<DriveConnectionState> connect() => throw UnimplementedError();

  @override
  Future<void> deleteBackup(String fileId) => throw UnimplementedError();

  @override
  Future<File> downloadBackupById({
    required String fileId,
    required String fileName,
    required Directory destinationDirectory,
    int? totalBytes,
    BackupTaskProgressListener? onProgress,
  }) => throw UnimplementedError();

  @override
  Future<void> disconnect() => throw UnimplementedError();

  @override
  Future<DriveConnectionState> getConnectionState() =>
      throw UnimplementedError();

  @override
  Future<List<DriveBackupFile>> listBackups() => throw UnimplementedError();

  @override
  Future<List<DriveBackupFile>> pruneBackups({required int retainCount}) =>
      throw UnimplementedError();

  @override
  Future<DriveConnectionState> switchAccount() => throw UnimplementedError();

  @override
  Future<String> uploadBackup(
    File backupFile, {
    BackupTaskProgressListener? onProgress,
  }) => throw UnimplementedError();
}

class _FlowPortableTransferService extends PortableTransferService {
  _FlowPortableTransferService({this.importResult, this.exportPath})
    : super(
        archiveIo: VaultArchiveIo(
          pathStrategy: DummyVaultPathStrategy(),
          repository: FakeSessionVaultRepository(),
          frontMatterCodec: const FrontMatterCodec(),
          indexDatabaseManager: IndexDatabaseManager(DummyVaultPathStrategy()),
          editorDraftStore: EditorDraftStore(
            pathStrategy: DummyVaultPathStrategy(),
            cryptoService: LocalCryptoService(),
          ),
        ),
        externalDirectoryStore: ExternalDirectoryStore(
          DummyVaultPathStrategy(),
        ),
      );

  final PortableImportResult? importResult;
  final String? exportPath;

  @override
  Future<PortableImportResult?> importDocumentsWithPicker(
    UnlockedVaultSession session, {
    required AppLocalizations l10n,
  }) async {
    return importResult;
  }

  @override
  Future<String?> exportMarkdownToDirectory(
    UnlockedVaultSession session,
    AppLocalizations l10n,
  ) async {
    return exportPath;
  }
}

class _FlowRepairService extends VaultRepairService {
  _FlowRepairService(this.report) : super(FakeSessionVaultRepository());

  final VaultRepairReport report;

  @override
  Future<VaultRepairReport> repairVaultWithReport(
    UnlockedVaultSession session,
  ) async {
    return report;
  }
}

class _RecoverySessionVaultRepository extends FakeSessionVaultRepository {
  _RecoverySessionVaultRepository({
    this.setupRecoveryKeyResult,
    this.rotateRecoveryKeyResult,
    this.ensureKeystoreResult,
  });

  final RecoverySetupResult? setupRecoveryKeyResult;
  final RecoverySetupResult? rotateRecoveryKeyResult;
  final Object? ensureKeystoreResult;

  @override
  Future<RecoverySetupResult> setupRecoveryKey() async {
    final RecoverySetupResult? result = setupRecoveryKeyResult;
    if (result == null) {
      throw StateError('setupRecoveryKeyResult not configured');
    }
    return result;
  }

  @override
  Future<RecoverySetupResult> rotateRecoveryKey(
    UnlockedVaultSession session,
  ) async {
    final RecoverySetupResult? result = rotateRecoveryKeyResult;
    if (result == null) {
      throw StateError('rotateRecoveryKeyResult not configured');
    }
    return result;
  }

  @override
  Future<UnlockedVaultSession> ensureKeystoreMatchesUnlockMode(
    UnlockedVaultSession session, {
    AppUnlockMode? targetMode,
  }) async {
    final Object? result = ensureKeystoreResult;
    if (result == null) {
      return session;
    }
    if (result is UnlockedVaultSession) {
      return result;
    }
    throw result;
  }
}

const UnlockedVaultSession _kUnlockedSession = UnlockedVaultSession(
  vaultId: 'vault_test',
  trustedDevice: false,
  recoveryWrapKey: <int>[1, 2, 3],
);

const UnlockedVaultSession _kSyncedUnlockedSession = UnlockedVaultSession(
  vaultId: 'vault_synced_test',
  trustedDevice: true,
  recoveryWrapKey: <int>[4, 5, 6],
);

class _FixedPersonalizationPreferencesController
    extends PersonalizationPreferencesController {
  @override
  Future<PersonalizationPreferences> build() async {
    return const PersonalizationPreferences(
      imageCompressPreset: ImageCompressPreset.standard,
      typography: EditorTypographyPreferences.defaults,
      themeMode: AppThemeModePreference.system,
      sessionTimeoutMinutes: SessionBackgroundTimeoutMinutes.three,
      locale: AppLanguage.zh,
    );
  }
}

class _LockedAppSessionController extends AppSessionController {
  @override
  AppSessionState build() =>
      const AppSessionState(status: AppLockStatus.locked);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsFlowController', () {
    final AppLocalizations l10n = lookupAppLocalizations(
      const Locale('zh', 'TW'),
    );

    test('prepareDriveRestore 在 precheck 失敗時會清理暫存檔', () async {
      final Directory tempDir = Directory.systemTemp.createTempSync(
        'settings_flow_controller_test',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      final File tempBackup = File('${tempDir.path}/drive-backup.zip')
        ..writeAsStringSync('backup');
      final _FlowBackupService backupService = _FlowBackupService(
        driveBackups: const <DriveBackupFile>[
          DriveBackupFile(
            id: 'drive_1',
            name: 'drive-backup.zip',
            createdAt: null,
          ),
        ],
      );
      final _FlowRestoreService restoreService = _FlowRestoreService(
        downloadedFile: tempBackup,
        precheckError: StateError('precheck failed'),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          vaultBackupServiceProvider.overrideWithValue(backupService),
          vaultRestoreServiceProvider.overrideWithValue(restoreService),
        ],
      );
      addTearDown(container.dispose);
      final SettingsFlowController controller = container.read(
        settingsFlowControllerProvider,
      );

      await expectLater(
        () => controller.prepareDriveRestore(
          pickBackup: (List<DriveBackupFile> backups) async => backups.first,
        ),
        throwsA(isA<StateError>()),
      );

      expect(tempBackup.existsSync(), isFalse);
    });

    test('delete backup 會轉呼叫 backup service', () async {
      final _FlowBackupService backupService = _FlowBackupService();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          vaultBackupServiceProvider.overrideWithValue(backupService),
        ],
      );
      addTearDown(container.dispose);
      final SettingsFlowController controller = container.read(
        settingsFlowControllerProvider,
      );

      await controller.deleteAppLocalBackup(
        LocalBackupFile(
          name: 'local.zip',
          path: 'C:/backup/local.zip',
          createdAt: DateTime(2026, 1, 1),
          sizeBytes: 10,
        ),
      );
      await controller.deleteDriveBackup(
        const DriveBackupFile(
          id: 'drive_1',
          name: 'drive.zip',
          createdAt: null,
        ),
      );

      expect(backupService.deleteAppLocalBackupCalls, 1);
      expect(backupService.deleteDriveBackupCalls, 1);
    });

    test('recordBackupPersistResult 會寫入 backup status store 並回傳成功訊息', () async {
      final Directory tempDir = Directory.systemTemp.createTempSync(
        'settings_flow_status_test',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      final BackupStatusStore statusStore = BackupStatusStore(
        storageFile: File('${tempDir.path}/backup_status.json'),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          backupStatusStoreProvider.overrideWithValue(statusStore),
          backupStatusProvider.overrideWith((Ref ref) => statusStore.read()),
        ],
      );
      addTearDown(container.dispose);
      final SettingsFlowController controller = container.read(
        settingsFlowControllerProvider,
      );

      final SettingsFlowFeedback? feedback = await controller
          .recordBackupPersistResult(
            l10n: lookupAppLocalizations(const Locale('zh', 'TW')),
            result: const BackupPersistResult(
              status: BackupPersistStatus.success,
              savedPath: 'C:/backup/local.zip',
            ),
            action: BackupStatusAction.localBackup,
            onSuccess: (String path) => '已儲存到 $path',
          );

      final BackupStatusSnapshot snapshot = await container.read(
        backupStatusProvider.future,
      );
      expect(feedback?.message, contains('local.zip'));
      expect(snapshot.lastLocalBackupAt, isNotNull);
    });

    test('recordBackupPersistResult inspect failed 會寫入 failure 紀錄', () async {
      final Directory tempDir = Directory.systemTemp.createTempSync(
        'settings_flow_failure_test',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      final BackupStatusStore statusStore = BackupStatusStore(
        storageFile: File('${tempDir.path}/backup_status.json'),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          backupStatusStoreProvider.overrideWithValue(statusStore),
          backupStatusProvider.overrideWith((Ref ref) => statusStore.read()),
        ],
      );
      addTearDown(container.dispose);
      final SettingsFlowController controller = container.read(
        settingsFlowControllerProvider,
      );

      final SettingsFlowFeedback? feedback = await controller
          .recordBackupPersistResult(
            l10n: lookupAppLocalizations(const Locale('zh', 'TW')),
            result: const BackupPersistResult(
              status: BackupPersistStatus.inspectFailed,
              message: 'zip corrupt',
            ),
            action: BackupStatusAction.driveUpload,
            onSuccess: (String path) => path,
            inspectFailedMessage: (String message) => '檢查失敗: $message',
          );

      final BackupStatusSnapshot snapshot = await container.read(
        backupStatusProvider.future,
      );
      expect(feedback?.tone, SettingsFlowFeedbackTone.error);
      expect(snapshot.lastFailure?.action, BackupStatusAction.driveUpload);
      expect(snapshot.lastFailure?.message, 'zip corrupt');
    });

    test('importDocuments 匯入成功回傳 success', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          portableTransferServiceProvider.overrideWithValue(
            _FlowPortableTransferService(
              importResult: const PortableImportResult(
                importedEntries: 2,
                skippedFiles: 0,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(appSessionProvider.notifier)
          .activateSession(_kUnlockedSession);
      final SettingsFlowController controller = container.read(
        settingsFlowControllerProvider,
      );

      final SettingsFlowFeedback? feedback = await controller.importDocuments(
        l10n,
      );

      expect(feedback?.tone, SettingsFlowFeedbackTone.success);
    });

    test('importDocuments 0 筆匯入維持 info', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          portableTransferServiceProvider.overrideWithValue(
            _FlowPortableTransferService(
              importResult: const PortableImportResult(
                importedEntries: 0,
                skippedFiles: 0,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(appSessionProvider.notifier)
          .activateSession(_kUnlockedSession);
      final SettingsFlowController controller = container.read(
        settingsFlowControllerProvider,
      );

      final SettingsFlowFeedback? feedback = await controller.importDocuments(
        l10n,
      );

      expect(feedback?.tone, SettingsFlowFeedbackTone.info);
    });

    test('exportMarkdown 成功回傳 success', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          portableTransferServiceProvider.overrideWithValue(
            _FlowPortableTransferService(exportPath: 'C:/exports/notes.zip'),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(appSessionProvider.notifier)
          .activateSession(_kUnlockedSession);
      final SettingsFlowController controller = container.read(
        settingsFlowControllerProvider,
      );

      final SettingsFlowFeedback? feedback = await controller.exportMarkdown(
        l10n,
      );

      expect(feedback?.tone, SettingsFlowFeedbackTone.success);
    });

    test('createRecoveryKey 成功回傳 recovery key 與 success feedback', () async {
      final _RecoverySessionVaultRepository repository =
          _RecoverySessionVaultRepository(
            setupRecoveryKeyResult: const RecoverySetupResult(
              recoveryKey: 'setup-key',
              session: _kSyncedUnlockedSession,
            ),
          );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          vaultRepositoryProvider.overrideWithValue(repository),
          personalizationPreferencesProvider.overrideWith(
            _FixedPersonalizationPreferencesController.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(personalizationPreferencesProvider.future);
      final SettingsFlowController controller = container.read(
        settingsFlowControllerProvider,
      );

      final SettingsRecoveryKeyResult result = await controller
          .createRecoveryKey(l10n);

      expect(result.recoveryKey, 'setup-key');
      expect(result.feedback.tone, SettingsFlowFeedbackTone.success);
      expect(result.feedback.message, l10n.sessionRecoverySetupSuccessMessage);
      expect(
        container.read(appSessionProvider).session,
        same(_kSyncedUnlockedSession),
      );
    });

    test('repairVault 成功回傳 success', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          vaultRepairServiceProvider.overrideWithValue(
            _FlowRepairService(
              VaultRepairReport(
                entryCount: 9,
                relocatedEntries: 0,
                removedDuplicateEntries: 0,
                removedOrphanAssets: 0,
                skippedCorruptEntries: 0,
                tagsAdded: 0,
                relocatedAssets: 0,
                warnings: const <String>[],
                duration: const Duration(seconds: 2),
                finishedAt: DateTime(2026, 7, 10),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(appSessionProvider.notifier)
          .activateSession(_kUnlockedSession);
      final SettingsFlowController controller = container.read(
        settingsFlowControllerProvider,
      );

      final SettingsRepairVaultResult result = await controller.repairVault(
        l10n,
      );

      expect(result.feedback.tone, SettingsFlowFeedbackTone.success);
    });

    test('rotateRecoveryKey 成功回傳 recovery key 與 success feedback', () async {
      final _RecoverySessionVaultRepository repository =
          _RecoverySessionVaultRepository(
            rotateRecoveryKeyResult: const RecoverySetupResult(
              recoveryKey: 'rotated-key',
              session: _kSyncedUnlockedSession,
            ),
          );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          vaultRepositoryProvider.overrideWithValue(repository),
          personalizationPreferencesProvider.overrideWith(
            _FixedPersonalizationPreferencesController.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(personalizationPreferencesProvider.future);
      container
          .read(appSessionProvider.notifier)
          .activateSession(_kUnlockedSession);
      final SettingsFlowController controller = container.read(
        settingsFlowControllerProvider,
      );

      final SettingsRecoveryKeyResult result = await controller
          .rotateRecoveryKey(l10n);

      expect(result.recoveryKey, 'rotated-key');
      expect(result.feedback.tone, SettingsFlowFeedbackTone.success);
      expect(result.feedback.message, l10n.sessionRecoveryKeyRotatedMessage);
      expect(
        container.read(appSessionProvider).session,
        same(_kSyncedUnlockedSession),
      );
    });

    test('unlockWithRecovery 成功後回傳 success feedback', () async {
      final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
        unlockWithRecoveryKeyResult: _kUnlockedSession,
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          vaultRepositoryProvider.overrideWithValue(repository),
          personalizationPreferencesProvider.overrideWith(
            _FixedPersonalizationPreferencesController.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(personalizationPreferencesProvider.future);
      final SettingsFlowController controller = container.read(
        settingsFlowControllerProvider,
      );

      final SettingsFlowFeedback? feedback = await controller
          .unlockWithRecovery(l10n, 'recovery-key');
      final AppSessionState sessionState = container.read(appSessionProvider);

      expect(feedback?.tone, SettingsFlowFeedbackTone.success);
      expect(feedback?.message, l10n.sessionRecoveryUnlockSuccessMessage);
      expect(sessionState.status, AppLockStatus.unlocked);
      expect(sessionState.message, l10n.sessionRecoveryUnlockSuccessMessage);
    });

    test('applyUnlockMode 缺少已解鎖 session 回傳 warning', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appSessionProvider.overrideWith(_LockedAppSessionController.new),
          effectiveAppSessionProvider.overrideWith(
            (Ref ref) async => ref.watch(appSessionProvider),
          ),
        ],
      );
      addTearDown(container.dispose);
      final SettingsFlowController controller = container.read(
        settingsFlowControllerProvider,
      );

      final SettingsFlowFeedback? feedback = await controller.applyUnlockMode(
        l10n,
        AppUnlockMode.deviceLock,
      );

      expect(feedback?.tone, SettingsFlowFeedbackTone.warning);
      expect(feedback?.message, l10n.sessionUnlockModeChangeNeedsUnlockMessage);
    });

    test('applyUnlockMode 缺少裝置鎖回傳 warning', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appLockServiceProvider.overrideWithValue(
            FakeAppLockService(canUseDeviceCredentialResult: false),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(appSessionProvider.notifier)
          .activateSession(_kUnlockedSession);
      final SettingsFlowController controller = container.read(
        settingsFlowControllerProvider,
      );

      final SettingsFlowFeedback? feedback = await controller.applyUnlockMode(
        l10n,
        AppUnlockMode.deviceLock,
      );

      expect(feedback?.tone, SettingsFlowFeedbackTone.warning);
      expect(feedback?.message, l10n.sessionUnlockModeNeedsDeviceLockMessage);
    });

    test('applyUnlockMode 缺少生物辨識回傳 warning', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appLockServiceProvider.overrideWithValue(
            FakeAppLockService(canUseBiometricResult: false),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(appSessionProvider.notifier)
          .activateSession(_kUnlockedSession);
      final SettingsFlowController controller = container.read(
        settingsFlowControllerProvider,
      );

      final SettingsFlowFeedback? feedback = await controller.applyUnlockMode(
        l10n,
        AppUnlockMode.biometric,
      );

      expect(feedback?.tone, SettingsFlowFeedbackTone.warning);
      expect(
        feedback?.message,
        l10n.sessionBiometricNotEnrolledSwitchModeMessage,
      );
    });

    test('applyUnlockMode 驗證取消回傳 info', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appLockServiceProvider.overrideWithValue(
            FakeAppLockService(unlockMode: AppUnlockMode.none),
          ),
          vaultRepositoryProvider.overrideWithValue(
            _RecoverySessionVaultRepository(
              ensureKeystoreResult: const DeviceKeyUserCancelledException(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(appSessionProvider.notifier)
          .activateSession(_kUnlockedSession);
      final SettingsFlowController controller = container.read(
        settingsFlowControllerProvider,
      );

      final SettingsFlowFeedback? feedback = await controller.applyUnlockMode(
        l10n,
        AppUnlockMode.deviceLock,
      );

      expect(feedback?.tone, SettingsFlowFeedbackTone.info);
      expect(feedback?.message, l10n.settingsUnlockModeChangeCancelled);
    });

    test('applyUnlockMode 驗證失敗回傳 error', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appLockServiceProvider.overrideWithValue(
            FakeAppLockService(unlockMode: AppUnlockMode.none),
          ),
          vaultRepositoryProvider.overrideWithValue(
            _RecoverySessionVaultRepository(
              ensureKeystoreResult: DeviceKeyAuthFailedException('failed'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(appSessionProvider.notifier)
          .activateSession(_kUnlockedSession);
      final SettingsFlowController controller = container.read(
        settingsFlowControllerProvider,
      );

      final SettingsFlowFeedback? feedback = await controller.applyUnlockMode(
        l10n,
        AppUnlockMode.deviceLock,
      );

      expect(feedback?.tone, SettingsFlowFeedbackTone.error);
      expect(feedback?.message, l10n.settingsUnlockModeChangeAuthFailed);
    });
  });
}
