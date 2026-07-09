import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/settings/settings_flow_controller.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/external_directory_store.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_backup_service.dart';
import 'package:quill_diary/infrastructure/storage/vault_restore_service.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_models.dart';
import 'package:quill_diary/l10n/l10n.dart';

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

void main() {
  group('SettingsFlowController', () {
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
  });
}
