import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/settings/application/settings_flow_controller.dart';
import 'package:quill_diary/features/settings/providers/settings_providers.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

import '../../helpers/fake_vault_transfer_service.dart';
import '../../helpers/test_l10n.dart';

void main() {
  ProviderContainer buildContainer(FakeVaultTransferService transferService) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        vaultTransferServiceProvider.overrideWithValue(transferService),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('disconnectGoogleDrive 會刷新連線狀態並回傳成功訊息', () async {
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

  test('prepareDriveRestore 會建立帶檔名的 restore request 並可清掉暫存檔', () async {
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
}
