import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/recovery/recovery_key_identity.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/domain/shared/vault_backup_policy.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/external_directory_store.dart';
import 'package:quill_diary/infrastructure/storage/portable/vault_backup_io.dart';
import 'package:quill_diary/infrastructure/storage/shared/external_file_delivery.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_models.dart';
import 'package:quill_diary/l10n/l10n.dart';

class VaultBackupService {
  VaultBackupService({
    required this._backupIo,
    required this._driveBackupService,
    required this._externalDirectoryStore,
    required this._pathStrategy,
  });

  final VaultBackupIo _backupIo;
  final DriveBackupService _driveBackupService;
  final ExternalDirectoryStore _externalDirectoryStore;
  final VaultPathStrategy _pathStrategy;

  Future<DriveConnectionState> getGoogleDriveConnectionState() {
    return _driveBackupService.getConnectionState();
  }

  Future<DriveConnectionState> linkGoogleDrive() {
    return _driveBackupService.connect();
  }

  Future<DriveConnectionState> switchGoogleDrive() {
    return _driveBackupService.switchAccount();
  }

  Future<void> disconnectGoogleDrive() {
    return _driveBackupService.disconnect();
  }

  Future<BackupPersistResult> saveBackupToAppLocal({
    BackupTaskProgressListener? onProgress,
    String? fileName,
    VaultBackupPurpose purpose = VaultBackupPurpose.normal,
  }) {
    return _runInspectedBackupPipeline(
      purpose: purpose,
      fileName: fileName,
      onProgress: onProgress,
      deliver:
          (
            File stagingZip,
            String deliveredFileName,
            BackupTaskProgressListener? deliverProgress,
          ) async {
            final Directory backupsDirectory = await _pathStrategy
                .localBackupsDirectory();
            await backupsDirectory.create(recursive: true);
            var destination = File(
              p.join(backupsDirectory.path, deliveredFileName),
            );
            await _ensureFileInsideLocalBackupsDirectory(destination);
            final partial = File('${stagingZip.path}.partial');
            await partial.create(exclusive: true);
            try {
              await copyFileToPath(
                stagingZip,
                partial.path,
                onProgress: deliverProgress,
              );
              if (destination.existsSync()) {
                final stem = p.basenameWithoutExtension(deliveredFileName);
                destination = File(
                  p.join(
                    backupsDirectory.path,
                    '${stem}_${generateBackupId()}.${VaultBackupPolicy.fileExtension}',
                  ),
                );
              }
              partial.renameSync(destination.path);
            } finally {
              await deleteFileIfExists(partial.path);
            }
            final List<LocalBackupFile> backups = await _loadAppLocalBackups();
            await _pruneExcessAppLocalBackupsFromSorted(backups);
            return destination.path;
          },
    );
  }

  Future<BackupPersistResult> saveBackupBeforeRepair({
    BackupTaskProgressListener? onProgress,
  }) {
    return saveBackupToAppLocal(
      purpose: VaultBackupPurpose.preservation,
      onProgress: onProgress,
      fileName: VaultBackupPolicy.backupBeforeRepairFileName(DateTime.now()),
    );
  }

  Future<BackupPersistResult> saveBackupToExternalDirectory({
    required AppLocalizations l10n,
    BackupTaskProgressListener? onProgress,
  }) {
    return _runInspectedBackupPipeline(
      onProgress: onProgress,
      deliver:
          (
            File stagingZip,
            String fileName,
            BackupTaskProgressListener? deliverProgress,
          ) {
            return deliverToExternalDirectory(
              dialogTitle: l10n.vaultTransferPickBackupDirectoryTitle,
              fileName: fileName,
              sourceFile: stagingZip,
              resolveInitialDirectory:
                  _externalDirectoryStore.resolveInitialDirectory,
              rememberDirectory: _externalDirectoryStore.rememberDirectory,
              onProgress: deliverProgress,
            );
          },
    );
  }

  /// 建立並檢查備份 zip，寫入持久 staging；不刪除檔案，供背景上傳接手。
  Future<BackupPersistResult> prepareDriveUploadStaging({
    required Future<String> Function(String fileName) resolveStagingPath,
    BackupTaskProgressListener? onProgress,
  }) async {
    final String fileName = VaultBackupPolicy.backupFileName(DateTime.now());
    final String stagingPath = await resolveStagingPath(fileName);
    final File staging = File(stagingPath);
    final File partial = File('$stagingPath.partial');
    await partial.create(recursive: true, exclusive: true);
    try {
      await _backupIo.writeBackupZip(
        partial,
        onProgress: remapBackupTaskProgress(
          onProgress,
          start: 0,
          end: backupPipelineZipEndFraction,
        ),
      );
      final BackupInspectResult inspect = await inspectBackup(partial);
      if (!inspect.ok) {
        return BackupPersistResult(
          status: BackupPersistStatus.inspectFailed,
          message: inspect.issue.name,
        );
      }
      final RecoveryMetadata? metadata = inspect.metadata;
      final identity = metadata == null
          ? null
          : await RecoveryKeyIdentity.fromMetadata(metadata);
      if (staging.existsSync()) {
        throw FileSystemException('Drive 上傳暫存路徑已被使用。', staging.path);
      }
      partial.renameSync(staging.path);
      return BackupPersistResult(
        status: BackupPersistStatus.success,
        savedPath: staging.path,
        identity: identity,
        purpose: VaultBackupPurpose.normal,
        message: fileName,
      );
    } finally {
      await deleteFileIfExists(partial.path);
    }
  }

  Future<void> pruneDriveBackups({
    required int retainCount,
    String? keepFileId,
    bool interactive = true,
  }) {
    return _driveBackupService.pruneBackups(
      retainCount: retainCount,
      keepFileId: keepFileId,
      interactive: interactive,
    );
  }

  Future<List<LocalBackupFile>> listAppLocalBackups() async {
    final List<LocalBackupFile> backups = await _loadAppLocalBackups();
    await _pruneExcessAppLocalBackupsFromSorted(backups);
    return backups;
  }

  Future<void> deleteAppLocalBackup(LocalBackupFile backup) async {
    final File file = File(backup.path);
    await _ensureFileInsideLocalBackupsDirectory(file);
    await _deleteIfExists(file);
  }

  Future<List<DriveBackupFile>> listDriveBackups() async {
    return _driveBackupService.listBackups();
  }

  Future<void> deleteDriveBackup(DriveBackupFile backup) async {
    await _driveBackupService.deleteBackup(backup.id);
  }

  Future<File> downloadDriveBackupToTempFile(
    DriveBackupFile backup, {
    BackupTaskProgressListener? onProgress,
  }) async {
    return _driveBackupService.downloadBackupById(
      fileId: backup.id,
      fileName: backup.name,
      destinationDirectory: await _pathStrategy.transferWorkDirectory(),
      totalBytes: backup.sizeBytes,
      onProgress: onProgress,
    );
  }

  Future<BackupInspectResult> inspectBackup(File backupFile) {
    return _backupIo.inspectBackup(backupFile);
  }

  Future<List<LocalBackupFile>> _loadAppLocalBackups() async {
    final Directory backupsDirectory = await _pathStrategy
        .localBackupsDirectory();
    if (!backupsDirectory.existsSync()) {
      return <LocalBackupFile>[];
    }

    final List<LocalBackupFile> backups = <LocalBackupFile>[];
    await for (final FileSystemEntity entity in backupsDirectory.list(
      followLinks: false,
    )) {
      if (entity is! File ||
          !VaultBackupPolicy.hasVaultBackupExtension(entity.path)) {
        continue;
      }
      backups.add(
        LocalBackupFile(
          name: p.basename(entity.path),
          path: entity.path,
          createdAt: await entity.lastModified(),
          sizeBytes: await entity.length(),
        ),
      );
    }

    backups.sort(_compareLocalBackupsNewestFirst);
    return backups;
  }

  int _compareLocalBackupsNewestFirst(LocalBackupFile a, LocalBackupFile b) {
    final int createdOrder = b.createdAt.compareTo(a.createdAt);
    if (createdOrder != 0) {
      return createdOrder;
    }
    return b.name.compareTo(a.name);
  }

  Future<void> _pruneExcessAppLocalBackupsFromSorted(
    List<LocalBackupFile> sortedNewestFirst,
  ) async {
    if (sortedNewestFirst.length <= VaultBackupPolicy.retainCount) {
      return;
    }
    final List<LocalBackupFile> stale = sortedNewestFirst.sublist(
      VaultBackupPolicy.retainCount,
    );
    for (final LocalBackupFile backup in stale) {
      await deleteAppLocalBackup(backup);
    }
    sortedNewestFirst.removeRange(
      VaultBackupPolicy.retainCount,
      sortedNewestFirst.length,
    );
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

  Future<BackupPersistResult> _runInspectedBackupPipeline({
    required Future<String?> Function(
      File stagingZip,
      String fileName,
      BackupTaskProgressListener? deliverProgress,
    )
    deliver,
    BackupTaskProgressListener? onProgress,
    String? fileName,
    VaultBackupPurpose purpose = VaultBackupPurpose.normal,
  }) async {
    final String resolvedFileName =
        fileName ?? VaultBackupPolicy.backupFileName(DateTime.now());
    final File staging = await _createBackupStagingFile();
    try {
      await _backupIo.writeBackupZip(
        staging,
        purpose: purpose,
        onProgress: remapBackupTaskProgress(
          onProgress,
          start: 0,
          end: backupPipelineZipEndFraction,
        ),
      );
      final BackupInspectResult inspect = await inspectBackup(staging);
      if (!inspect.ok) {
        return BackupPersistResult(
          status: BackupPersistStatus.inspectFailed,
          message: inspect.issue.name,
        );
      }
      final String? saved = await deliver(
        staging,
        resolvedFileName,
        remapBackupTaskProgress(
          onProgress,
          start: backupPipelineZipEndFraction,
          end: 1,
        ),
      );
      if (saved == null) {
        return const BackupPersistResult(status: BackupPersistStatus.cancelled);
      }
      return BackupPersistResult(
        status: BackupPersistStatus.success,
        savedPath: saved,
        identity: inspect.metadata == null
            ? null
            : await RecoveryKeyIdentity.fromMetadata(inspect.metadata!),
        purpose: purpose,
        message: '',
      );
    } finally {
      await deleteFileIfExists(staging.path);
    }
  }

  Future<File> _createBackupStagingFile() async {
    final Directory tempDirectory = await _pathStrategy.transferWorkDirectory();
    return File(
      p.join(
        tempDirectory.path,
        '${generateBackupId()}.${VaultBackupPolicy.fileExtension}',
      ),
    ).create(recursive: true, exclusive: true);
  }

  Future<void> _deleteIfExists(File file) async {
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
