import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/shared/vault_backup_policy.dart';
import '../../l10n/l10n.dart';
import '../drive/drive_backup_service.dart';
import 'backup_task_progress.dart';
import 'external_directory_store.dart';
import 'shared/archive_extract.dart';
import 'shared/external_file_delivery.dart';
import 'vault_archive_io.dart';
import 'vault_path_strategy.dart';
import 'vault_transfer_models.dart';

class VaultBackupService {
  VaultBackupService({
    required VaultArchiveIo archiveIo,
    required DriveBackupService driveBackupService,
    required ExternalDirectoryStore externalDirectoryStore,
    required VaultPathStrategy pathStrategy,
  }) : _archiveIo = archiveIo,
       _driveBackupService = driveBackupService,
       _externalDirectoryStore = externalDirectoryStore,
       _pathStrategy = pathStrategy;

  final VaultArchiveIo _archiveIo;
  final DriveBackupService _driveBackupService;
  final ExternalDirectoryStore _externalDirectoryStore;
  final VaultPathStrategy _pathStrategy;

  static const int backupRetainCount = VaultBackupPolicy.retainCount;

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
  }) {
    return _runInspectedBackupPipeline(
      onProgress: onProgress,
      deliver:
          (
            File stagingZip,
            String fileName,
            BackupTaskProgressListener? deliverProgress,
          ) async {
            final Directory backupsDirectory = await _pathStrategy
                .localBackupsDirectory();
            await backupsDirectory.create(recursive: true);
            final String destinationPath = p.join(
              backupsDirectory.path,
              fileName,
            );
            await copyFileToPath(
              stagingZip,
              destinationPath,
              onProgress: deliverProgress,
            );
            final List<LocalBackupFile> backups = await _loadAppLocalBackups();
            await _pruneExcessAppLocalBackupsFromSorted(backups);
            return destinationPath;
          },
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
              l10n: l10n,
              resolveInitialDirectory:
                  _externalDirectoryStore.resolveInitialDirectory,
              rememberDirectory: _externalDirectoryStore.rememberDirectory,
              onProgress: deliverProgress,
            );
          },
    );
  }

  Future<BackupPersistResult> uploadBackupToDrive({
    BackupTaskProgressListener? onProgress,
  }) {
    return _runInspectedBackupPipeline(
      onProgress: onProgress,
      deliver:
          (
            File stagingZip,
            String fileName,
            BackupTaskProgressListener? deliverProgress,
          ) async {
            await _driveBackupService.uploadBackup(
              stagingZip,
              onProgress: deliverProgress,
            );
            await _driveBackupService.pruneBackups(
              retainCount: backupRetainCount,
            );
            return fileName;
          },
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
    required Directory destinationDirectory,
    BackupTaskProgressListener? onProgress,
  }) {
    return _driveBackupService.downloadBackupById(
      fileId: backup.id,
      fileName: backup.name,
      destinationDirectory: destinationDirectory,
      totalBytes: backup.sizeBytes,
      onProgress: onProgress,
    );
  }

  Future<BackupInspectResult> inspectBackup(File backupFile) {
    return _archiveIo.inspectBackup(backupFile);
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
    if (sortedNewestFirst.length <= backupRetainCount) {
      return;
    }
    final List<LocalBackupFile> stale = sortedNewestFirst.sublist(
      backupRetainCount,
    );
    for (final LocalBackupFile backup in stale) {
      await deleteAppLocalBackup(backup);
    }
    sortedNewestFirst.removeRange(backupRetainCount, sortedNewestFirst.length);
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
  }) async {
    final String fileName = VaultBackupPolicy.backupFileName(DateTime.now());
    final File staging = await _createTempFile(fileName);
    try {
      await _archiveIo.writeBackupZip(
        staging,
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
          message: inspect.message,
        );
      }
      final String? saved = await deliver(
        staging,
        fileName,
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
        message: inspect.message,
      );
    } finally {
      await _deleteIfExists(staging);
    }
  }

  Future<File> _createTempFile(String fileName) async {
    final Directory tempDirectory = await getTemporaryDirectory();
    return File(
      p.join(
        tempDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}_$fileName',
      ),
    );
  }

  Future<void> _deleteIfExists(File file) async {
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
