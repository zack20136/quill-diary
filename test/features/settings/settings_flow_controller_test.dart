import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/settings/application/settings_flow_controller.dart';
import 'package:quill_diary/features/settings/providers/settings_providers.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_service.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

import '../../helpers/fake_session_vault_repository.dart';
import '../../helpers/fake_vault_transfer_service.dart';
import '../../helpers/test_l10n.dart';

void main() {
  ProviderContainer buildContainer(
    FakeVaultTransferService transferService, {
    FakeSessionVaultRepository? repository,
  }) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        vaultTransferServiceProvider.overrideWithValue(transferService),
        if (repository != null)
          vaultRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('disconnectGoogleDrive 會更新連線狀態與回饋訊息', () async {
    final FakeVaultTransferService transferService = FakeVaultTransferService(
      connectionState: const DriveConnectionState(
        isConnected: true,
        email: 'writer@example.com',
        displayName: 'Writer',
      ),
    );
    final ProviderContainer container = buildContainer(transferService);

    final SettingsFlowController controller = container.read(
      settingsFlowControllerProvider,
    );
    final SettingsFlowFeedback feedback = await controller.disconnectGoogleDrive(
      testL10n,
    );
    final DriveConnectionState state = await container.read(
      settingsDriveConnectionProvider.future,
    );

    expect(transferService.disconnectCalls, 1);
    expect(state.isConnected, isFalse);
    expect(feedback.message, testL10n.settingsDriveBackupDisconnectSuccess);
    expect(feedback.tone, SettingsFlowFeedbackTone.success);
  });

  test('prepareDriveRestore 會把下載的暫存備份掛到 restore request', () async {
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'settings_flow_drive_restore',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final FakeVaultTransferService transferService = FakeVaultTransferService(
      driveBackups: const <DriveBackupFile>[
        DriveBackupFile(
          id: 'drive_1',
          name: 'vault-backup.zip',
          createdAt: null,
        ),
      ],
      downloadToTemp: (DriveBackupFile backup) {
        final File file = File('${tempDir.path}/${backup.name}');
        file.writeAsStringSync('backup bytes');
        return file;
      },
    );
    final ProviderContainer container = buildContainer(transferService);
    final SettingsFlowController controller = container.read(
      settingsFlowControllerProvider,
    );

    final PreparedRestoreRequest? request = await controller.prepareDriveRestore(
      pickBackup: (List<DriveBackupFile> backups) async => backups.first,
    );

    expect(request, isNotNull);
    expect(request!.driveBackupName, 'vault-backup.zip');
    expect(request.tempFileToDelete, isNotNull);
    expect(request.tempFileToDelete!.existsSync(), isTrue);

    await request.dispose();

    expect(request.tempFileToDelete!.existsSync(), isFalse);
    expect(transferService.listDriveBackupsCalls, 1);
    expect(transferService.downloadDriveBackupToTempFileCalls, 1);
    expect(transferService.precheckRestoreCalls, 1);
  });

  test('prepareDriveRestore precheck 失敗時會刪除暫存檔', () async {
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'settings_flow_drive_restore_error',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    File? downloadedFile;
    final FakeVaultTransferService transferService = FakeVaultTransferService(
      driveBackups: const <DriveBackupFile>[
        DriveBackupFile(
          id: 'drive_1',
          name: 'vault-backup.zip',
          createdAt: null,
        ),
      ],
      downloadToTemp: (DriveBackupFile backup) {
        downloadedFile = File('${tempDir.path}/${backup.name}');
        downloadedFile!.writeAsStringSync('backup bytes');
        return downloadedFile!;
      },
      precheckRestoreError: StateError('precheck failed'),
    );
    final ProviderContainer container = buildContainer(transferService);
    final SettingsFlowController controller = container.read(
      settingsFlowControllerProvider,
    );

    await expectLater(
      () => controller.prepareDriveRestore(
        pickBackup: (List<DriveBackupFile> backups) async => backups.first,
      ),
      throwsA(isA<StateError>()),
    );

    expect(downloadedFile, isNotNull);
    expect(downloadedFile!.existsSync(), isFalse);
  });

  test('prepareExternalRestore 會保留 bytes-only 選檔的清理責任', () async {
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'settings_flow_external_restore',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final File tempBackup = File('${tempDir.path}/picked-backup.zip')
      ..writeAsStringSync('backup bytes');
    final FakeVaultTransferService transferService = FakeVaultTransferService(
      pickedBackupFile: PickedBackupFile(
        file: tempBackup,
        shouldDeleteAfterUse: true,
      ),
    );
    final ProviderContainer container = buildContainer(transferService);
    final SettingsFlowController controller = container.read(
      settingsFlowControllerProvider,
    );

    final PreparedRestoreRequest? request = await controller
        .prepareExternalRestore(testL10n);

    expect(request, isNotNull);
    expect(request!.backupFile.path, tempBackup.path);
    expect(request.tempFileToDelete?.path, tempBackup.path);

    await request.dispose();

    expect(tempBackup.existsSync(), isFalse);
    expect(transferService.pickLocalBackupFileCalls, 1);
  });

  test('trustedDeviceAccessProvider 會快取查詢結果直到手動 invalidate', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      hasTrustedDevice: true,
    );
    final ProviderContainer container = buildContainer(
      FakeVaultTransferService(),
      repository: repository,
    );

    expect(
      await container.read(trustedDeviceAccessProvider.future),
      isTrue,
    );
    expect(
      await container.read(trustedDeviceAccessProvider.future),
      isTrue,
    );
    expect(repository.hasTrustedDeviceAccessCalls, 1);

    container.invalidate(trustedDeviceAccessProvider);
    expect(
      await container.read(trustedDeviceAccessProvider.future),
      isTrue,
    );
    expect(repository.hasTrustedDeviceAccessCalls, 2);
  });
}
