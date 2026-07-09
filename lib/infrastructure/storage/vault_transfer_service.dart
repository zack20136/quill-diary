import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import '../../l10n/l10n.dart';
import '../drive/drive_backup_service.dart';
import 'backup_task_progress.dart';
import 'external_directory_store.dart';
import 'portable_transfer_service.dart';
import 'restore_precheck.dart';
import 'shared/picked_file_materializer.dart';
import 'vault_archive_io.dart';
import 'vault_backup_service.dart';
import 'vault_path_strategy.dart';
import 'vault_repository.dart';
import 'vault_restore_service.dart';
import 'vault_transfer_models.dart';

export 'vault_transfer_models.dart';

class VaultTransferService {
  VaultTransferService({
    required VaultArchiveIo archiveIo,
    required DriveBackupService driveBackupService,
    required VaultRepository vaultRepository,
    required ExternalDirectoryStore externalDirectoryStore,
    required VaultPathStrategy pathStrategy,
    PickPortableFiles? pickPortableFiles,
    ReadPlatformFileBytes? readPlatformFileBytes,
    @visibleForTesting bool allowBytesFallback = false,
    @visibleForTesting CopyAndroidUriToPath? copyAndroidUriToPath,
    @visibleForTesting PickedFileMaterializer? pickedFileMaterializer,
  }) : this.fromServices(
         backupService: VaultBackupService(
           archiveIo: archiveIo,
           driveBackupService: driveBackupService,
           externalDirectoryStore: externalDirectoryStore,
           pathStrategy: pathStrategy,
         ),
         restoreService: VaultRestoreService(
           archiveIo: archiveIo,
           vaultRepository: vaultRepository,
           backupService: VaultBackupService(
             archiveIo: archiveIo,
             driveBackupService: driveBackupService,
             externalDirectoryStore: externalDirectoryStore,
             pathStrategy: pathStrategy,
           ),
           pathStrategy: pathStrategy,
           readPlatformFileBytes: readPlatformFileBytes,
           allowBytesFallback: allowBytesFallback,
           copyAndroidUriToPath: copyAndroidUriToPath,
           pickedFileMaterializer: pickedFileMaterializer,
         ),
         portableTransferService: PortableTransferService(
           archiveIo: archiveIo,
           externalDirectoryStore: externalDirectoryStore,
           pickPortableFiles: pickPortableFiles,
           readPlatformFileBytes: readPlatformFileBytes,
           allowBytesFallback: allowBytesFallback,
           copyAndroidUriToPath: copyAndroidUriToPath,
           pickedFileMaterializer: pickedFileMaterializer,
         ),
       );

  VaultTransferService.fromServices({
    required VaultBackupService backupService,
    required VaultRestoreService restoreService,
    required PortableTransferService portableTransferService,
  }) : _backupService = backupService,
       _restoreService = restoreService,
       _portableTransferService = portableTransferService;

  final VaultBackupService _backupService;
  final VaultRestoreService _restoreService;
  final PortableTransferService _portableTransferService;

  Future<DriveConnectionState> getGoogleDriveConnectionState() {
    return _backupService.getGoogleDriveConnectionState();
  }

  Future<DriveConnectionState> linkGoogleDrive() {
    return _backupService.linkGoogleDrive();
  }

  Future<DriveConnectionState> switchGoogleDrive() {
    return _backupService.switchGoogleDrive();
  }

  Future<void> disconnectGoogleDrive() {
    return _backupService.disconnectGoogleDrive();
  }

  Future<BackupPersistResult> saveBackupToAppLocal({
    BackupTaskProgressListener? onProgress,
  }) {
    return _backupService.saveBackupToAppLocal(onProgress: onProgress);
  }

  Future<BackupPersistResult> saveBackupToExternalDirectory({
    required AppLocalizations l10n,
    BackupTaskProgressListener? onProgress,
  }) {
    return _backupService.saveBackupToExternalDirectory(
      l10n: l10n,
      onProgress: onProgress,
    );
  }

  Future<BackupPersistResult> uploadBackupToDrive({
    BackupTaskProgressListener? onProgress,
  }) {
    return _backupService.uploadBackupToDrive(onProgress: onProgress);
  }

  Future<List<LocalBackupFile>> listAppLocalBackups() {
    return _backupService.listAppLocalBackups();
  }

  Future<void> deleteAppLocalBackup(LocalBackupFile backup) {
    return _backupService.deleteAppLocalBackup(backup);
  }

  Future<void> restoreFromAppLocalBackup(
    LocalBackupFile backup, {
    bool preserveTrustedDeviceAccess = false,
  }) {
    return _restoreService.restoreFromAppLocalBackup(
      backup,
      preserveTrustedDeviceAccess: preserveTrustedDeviceAccess,
    );
  }

  Future<BackupInspectResult> inspectBackup(File backupFile) {
    return _backupService.inspectBackup(backupFile);
  }

  Future<String?> exportMarkdownToDirectory(
    UnlockedVaultSession session,
    AppLocalizations l10n,
  ) {
    return _portableTransferService.exportMarkdownToDirectory(session, l10n);
  }

  Future<HtmlExportEstimate> estimateSelectedHtmlExport(Set<EntryId> entryIds) {
    return _portableTransferService.estimateSelectedHtmlExport(entryIds);
  }

  Future<String?> exportHtmlToDirectory(
    UnlockedVaultSession session,
    Set<EntryId> entryIds,
    AppLocalizations l10n,
  ) {
    return _portableTransferService.exportHtmlToDirectory(
      session,
      entryIds,
      l10n,
    );
  }

  Future<PortableImportResult?> importDocumentsWithPicker(
    UnlockedVaultSession session, {
    required AppLocalizations l10n,
  }) {
    return _portableTransferService.importDocumentsWithPicker(
      session,
      l10n: l10n,
    );
  }

  Future<PickedBackupFile?> pickLocalBackupFile(AppLocalizations l10n) {
    return _restoreService.pickLocalBackupFile(l10n);
  }

  Future<RestorePrecheck> precheckRestore(File backupFile) {
    return _restoreService.precheckRestore(backupFile);
  }

  Future<void> verifyBackupRecoveryKey(File backupFile, String recoveryKey) {
    return _restoreService.verifyBackupRecoveryKey(backupFile, recoveryKey);
  }

  Future<void> restoreFromBackupFile(
    File backupFile, {
    bool preserveTrustedDeviceAccess = false,
    BackupTaskProgressListener? onProgress,
  }) {
    return _restoreService.restoreFromBackupFile(
      backupFile,
      preserveTrustedDeviceAccess: preserveTrustedDeviceAccess,
      onProgress: onProgress,
    );
  }

  Future<List<DriveBackupFile>> listDriveBackups() {
    return _backupService.listDriveBackups();
  }

  Future<void> deleteDriveBackup(DriveBackupFile backup) {
    return _backupService.deleteDriveBackup(backup);
  }

  Future<File> downloadDriveBackupToTempFile(
    DriveBackupFile backup, {
    BackupTaskProgressListener? onProgress,
  }) {
    return _restoreService.downloadDriveBackupToTempFile(
      backup,
      onProgress: onProgress,
    );
  }

  Future<void> restoreFromDownloadedBackupFile(File backupFile) {
    return _restoreService.restoreFromDownloadedBackupFile(backupFile);
  }
}
