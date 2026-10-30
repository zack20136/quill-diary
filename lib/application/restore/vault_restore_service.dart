import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quill_diary/application/transfer/vault_backup_service.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/shared/vault_backup_policy.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/portable/vault_backup_io.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/infrastructure/storage/shared/picked_file_materializer.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_models.dart';
import 'package:quill_diary/l10n/l10n.dart';

class VaultRestoreService {
  VaultRestoreService({
    required this._backupIo,
    required this._vaultRepository,
    required this._backupService,
    ReadPlatformFileBytes? readPlatformFileBytes,
    bool allowBytesFallback = false,
    CopyAndroidUriToPath? copyAndroidUriToPath,
    PickedFileMaterializer? pickedFileMaterializer,
  }) : _pickedFileMaterializer =
           pickedFileMaterializer ??
           PickedFileMaterializer(
             copyAndroidUriToPath: copyAndroidUriToPath,
             readPlatformFileBytes: readPlatformFileBytes,
             allowBytesFallback: allowBytesFallback,
           );

  final VaultBackupIo _backupIo;
  final VaultRepository _vaultRepository;
  final VaultBackupService _backupService;
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
    final BackupRecoveryPreview preview = await _backupIo.prepareRestorePreview(
      backupFile,
    );
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
    await _backupIo.verifyBackupRecoveryKey(backupFile, recoveryKey);
  }

  Future<void> restoreFromBackupFile(
    File backupFile, {
    bool preserveTrustedDeviceAccess = false,
    BackupTaskProgressListener? onProgress,
  }) async {
    await _backupIo.restoreBackupZip(
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
    } on PickedFileMaterializationException {
      throw StateError(l10n.vaultTransferPickedFileUnreadable);
    }
  }
}
