import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/recovery/recovery_metadata.dart';
import '../../domain/shared/vault_backup_policy.dart';
import '../../l10n/l10n.dart';
import '../drive/drive_backup_service.dart';
import 'backup_task_progress.dart';
import 'shared/picked_file_materializer.dart';
import 'restore_precheck.dart';
import 'vault_archive_io.dart';
import 'vault_backup_service.dart';
import 'vault_path_strategy.dart';
import 'vault_repository.dart';
import 'vault_transfer_models.dart';

class VaultRestoreService {
  VaultRestoreService({
    required VaultArchiveIo archiveIo,
    required VaultRepository vaultRepository,
    required VaultBackupService backupService,
    required VaultPathStrategy pathStrategy,
    ReadPlatformFileBytes? readPlatformFileBytes,
    bool allowBytesFallback = false,
    CopyAndroidUriToPath? copyAndroidUriToPath,
    PickedFileMaterializer? pickedFileMaterializer,
  }) : _archiveIo = archiveIo,
       _vaultRepository = vaultRepository,
       _backupService = backupService,
       _pathStrategy = pathStrategy,
       _pickedFileMaterializer =
           pickedFileMaterializer ??
           PickedFileMaterializer(
             copyAndroidUriToPath: copyAndroidUriToPath,
             readPlatformFileBytes: readPlatformFileBytes,
             allowBytesFallback: allowBytesFallback,
           );

  final VaultArchiveIo _archiveIo;
  final VaultRepository _vaultRepository;
  final VaultBackupService _backupService;
  final VaultPathStrategy _pathStrategy;
  final PickedFileMaterializer _pickedFileMaterializer;

  Future<PickedBackupFile?> pickLocalBackupFile(AppLocalizations l10n) async {
    final PlatformFile? picked = await FilePicker.pickFile(
      dialogTitle: l10n.vaultTransferPickBackupFileTitle,
      type: FileType.custom,
      allowedExtensions: const <String>[VaultBackupPolicy.fileExtension],
    );
    if (picked == null) {
      return null;
    }
    return _resolvePickedBackupFile(picked, l10n);
  }

  Future<RestorePrecheck> precheckRestore(File backupFile) async {
    final BackupRecoveryPreview preview = await _archiveIo
        .prepareRestorePreview(backupFile);
    final RecoveryMetadata? localMetadata = await _vaultRepository
        .readRecoveryMetadata();
    final bool localHasTrusted =
        localMetadata != null &&
        await _vaultRepository.hasTrustedDeviceAccess();
    return RestorePrecheck(
      preview: preview,
      localVaultId: localMetadata?.vaultId,
      localRecoverySaltBase64: localMetadata?.kdf.saltBase64,
      localHasTrustedDevice: localHasTrusted,
      willOverwriteLocalVault: await _vaultRepository.hasVault(),
    );
  }

  Future<void> verifyBackupRecoveryKey(
    File backupFile,
    String recoveryKey,
  ) async {
    await _archiveIo.verifyBackupRecoveryKey(backupFile, recoveryKey);
  }

  Future<void> restoreFromAppLocalBackup(
    LocalBackupFile backup, {
    bool preserveTrustedDeviceAccess = false,
  }) async {
    final File file = File(backup.path);
    await _ensureFileInsideLocalBackupsDirectory(file);
    await restoreFromBackupFile(
      file,
      preserveTrustedDeviceAccess: preserveTrustedDeviceAccess,
    );
  }

  Future<void> restoreFromBackupFile(
    File backupFile, {
    bool preserveTrustedDeviceAccess = false,
    BackupTaskProgressListener? onProgress,
  }) async {
    await _archiveIo.restoreBackupZip(
      backupFile,
      preserveTrustedDeviceAccess: preserveTrustedDeviceAccess,
      onProgress: onProgress,
    );
  }

  Future<File> downloadDriveBackupToTempFile(
    DriveBackupFile backup, {
    BackupTaskProgressListener? onProgress,
  }) async {
    return _backupService.downloadDriveBackupToTempFile(
      backup,
      destinationDirectory: await getTemporaryDirectory(),
      onProgress: onProgress,
    );
  }

  Future<void> restoreFromDownloadedBackupFile(File backupFile) async {
    await restoreFromBackupFile(backupFile);
  }

  Future<PickedBackupFile?> _resolvePickedBackupFile(
    PlatformFile file,
    AppLocalizations l10n,
  ) async {
    try {
      final MaterializedPickedFile materialized = await _pickedFileMaterializer
          .materialize(
            file,
            fallbackBaseName: file.name.isNotEmpty
                ? file.name
                : 'restore.${VaultBackupPolicy.fileExtension}',
            alwaysCopyToTemp: true,
          );
      return PickedBackupFile(
        file: materialized.file,
        shouldDeleteAfterUse: materialized.shouldDeleteAfterUse,
      );
    } on PickedFileMaterializationException catch (error) {
      throw StateError(materializationFailureMessage(error.failure, l10n));
    }
  }

  Future<void> _ensureFileInsideLocalBackupsDirectory(File file) async {
    final Directory backupsDirectory = await _pathStrategy
        .localBackupsDirectory();
    final String root = p.normalize(backupsDirectory.absolute.path);
    final String target = p.normalize(file.absolute.path);
    if (target == root || !p.isWithin(root, target)) {
      throw StateError('Backup file is outside the expected directory.');
    }
  }
}
