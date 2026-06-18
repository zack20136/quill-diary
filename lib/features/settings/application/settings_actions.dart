import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/security/unlocked_vault_session.dart';
import '../../../infrastructure/drive/drive_backup_service.dart';
import '../../../infrastructure/storage/backup_task_progress.dart';
import '../../../infrastructure/storage/restore_precheck.dart';
import '../../../infrastructure/storage/vault_repository.dart';
import '../../../infrastructure/storage/vault_transfer_service.dart';
import '../../../infrastructure/storage/shared/portable_import_result.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/providers/core_providers.dart';
import '../../session/providers/session_providers.dart';
import '../../settings/providers/settings_providers.dart';

final settingsActionsProvider = Provider<SettingsActions>((Ref ref) {
  return SettingsActions(ref);
});

class SettingsActions {
  const SettingsActions(this._ref);

  final Ref _ref;

  Future<PortableImportResult?> importDocuments(AppLocalizations l10n) {
    return _ref.read(appSessionProvider.notifier).runSensitiveTask((
      UnlockedVaultSession session,
    ) {
      return _ref
          .read(vaultTransferServiceProvider)
          .importDocumentsWithPicker(session, l10n: l10n);
    });
  }

  Future<String?> exportMarkdown(AppLocalizations l10n) {
    return _ref.read(appSessionProvider.notifier).runSensitiveTask((
      UnlockedVaultSession session,
    ) {
      return _ref
          .read(vaultTransferServiceProvider)
          .exportMarkdownToDirectory(session, l10n);
    });
  }

  Future<void> deleteAppLocalBackup(LocalBackupFile backup) {
    return _ref.read(vaultTransferServiceProvider).deleteAppLocalBackup(backup);
  }

  Future<void> deleteDriveBackup(DriveBackupFile backup) {
    return _ref.read(vaultTransferServiceProvider).deleteDriveBackup(backup);
  }

  Future<RecoverySetupResult> setupRecoveryKey() {
    return _ref.read(vaultRepositoryProvider).setupRecoveryKey();
  }

  Future<BackupPersistResult> saveBackupToAppLocal({
    BackupTaskProgressListener? onProgress,
  }) {
    return _ref.read(vaultTransferServiceProvider).saveBackupToAppLocal(
      onProgress: onProgress,
    );
  }

  Future<BackupPersistResult> saveBackupToExternalDirectory({
    required AppLocalizations l10n,
    BackupTaskProgressListener? onProgress,
  }) {
    return _ref.read(vaultTransferServiceProvider).saveBackupToExternalDirectory(
      l10n: l10n,
      onProgress: onProgress,
    );
  }

  Future<BackupPersistResult> uploadBackupToDrive({
    BackupTaskProgressListener? onProgress,
  }) {
    return _ref
        .read(vaultTransferServiceProvider)
        .uploadBackupToDrive(onProgress: onProgress);
  }

  Future<List<LocalBackupFile>> listAppLocalBackups() {
    return _ref.read(vaultTransferServiceProvider).listAppLocalBackups();
  }

  Future<IndexRebuildReport> rebuildIndex() {
    return _ref.read(appSessionProvider.notifier).runSensitiveTask((
      UnlockedVaultSession session,
    ) {
      return _ref.read(vaultRepositoryProvider).rebuildIndexWithReport(session);
    });
  }

  Future<PickedBackupFile?> pickLocalBackupFile(AppLocalizations l10n) {
    return _ref.read(vaultTransferServiceProvider).pickLocalBackupFile(l10n);
  }

  Future<List<DriveBackupFile>> listDriveBackups() {
    return _ref.read(vaultTransferServiceProvider).listDriveBackups();
  }

  Future<File> downloadDriveBackupToTempFile(
    DriveBackupFile backup, {
    BackupTaskProgressListener? onProgress,
  }) {
    return _ref
        .read(vaultTransferServiceProvider)
        .downloadDriveBackupToTempFile(backup, onProgress: onProgress);
  }

  Future<DriveConnectionState> linkGoogleDrive() {
    return _ref.read(vaultTransferServiceProvider).linkGoogleDrive();
  }

  Future<DriveConnectionState> switchGoogleDrive() {
    return _ref.read(vaultTransferServiceProvider).switchGoogleDrive();
  }

  Future<void> disconnectGoogleDrive() {
    return _ref.read(vaultTransferServiceProvider).disconnectGoogleDrive();
  }

  Future<RestorePrecheck> precheckRestore(File backupFile) {
    return _ref.read(vaultTransferServiceProvider).precheckRestore(backupFile);
  }

  Future<RecoverySetupResult> rotateRecoveryKey(UnlockedVaultSession session) {
    return _ref.read(vaultRepositoryProvider).rotateRecoveryKey(session);
  }

  void invalidateDriveConnection() {
    _ref.invalidate(settingsDriveConnectionProvider);
  }

  Future<void> warmDriveConnection() async {
    await _ref.read(settingsDriveConnectionProvider.future);
  }
}
