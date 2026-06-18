import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/recovery/recovery_metadata.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import '../../domain/shared/vault_backup_policy.dart';
import '../../l10n/l10n.dart';
import '../drive/drive_backup_service.dart';
import 'backup_task_progress.dart';
import 'external_directory_store.dart';
import 'restore_precheck.dart';
import 'shared/archive_extract.dart';
import 'shared/external_directory_picker.dart';
import 'shared/external_file_delivery.dart';
import 'vault_archive_io.dart';
import 'vault_path_strategy.dart';
import 'vault_repository.dart';

enum BackupPersistStatus { success, inspectFailed, cancelled }

final class BackupPersistResult {
  const BackupPersistResult({
    required this.status,
    this.savedPath,
    this.message = '',
  });

  final BackupPersistStatus status;
  final String? savedPath;
  final String message;
}

final class PickedBackupFile {
  const PickedBackupFile({
    required this.file,
    required this.shouldDeleteAfterUse,
  });

  final File file;
  final bool shouldDeleteAfterUse;
}

final class LocalBackupFile {
  const LocalBackupFile({
    required this.name,
    required this.path,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String name;
  final String path;
  final DateTime createdAt;
  final int sizeBytes;
}

class VaultTransferService {
  VaultTransferService({
    required VaultArchiveIo archiveIo,
    required DriveBackupService driveBackupService,
    required VaultRepository vaultRepository,
    required ExternalDirectoryStore externalDirectoryStore,
    required VaultPathStrategy pathStrategy,
  }) : _archiveIo = archiveIo,
       _driveBackupService = driveBackupService,
       _vaultRepository = vaultRepository,
       _externalDirectoryStore = externalDirectoryStore,
       _pathStrategy = pathStrategy;

  final VaultArchiveIo _archiveIo;
  final DriveBackupService _driveBackupService;
  final VaultRepository _vaultRepository;
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

  Future<BackupInspectResult> inspectBackup(File backupFile) {
    return _archiveIo.inspectBackup(backupFile);
  }

  Future<String?> exportMarkdownToDirectory(
    UnlockedVaultSession session,
    AppLocalizations l10n,
  ) async {
    final String fileName = VaultBackupPolicy.markdownPortableFileName(
      DateTime.now(),
    );
    return _writeTempAndDeliver(
      dialogTitle: l10n.vaultTransferPickMarkdownDirectoryTitle,
      fileName: fileName,
      l10n: l10n,
      writeTarget: (File target) {
        return _archiveIo.writeMarkdownZip(session: session, target: target);
      },
    );
  }

  Future<HtmlExportEstimate> estimateSelectedHtmlExport(Set<EntryId> entryIds) {
    return _archiveIo.estimateSelectedHtmlExport(entryIds: entryIds);
  }

  Future<String?> exportHtmlToDirectory(
    UnlockedVaultSession session,
    Set<EntryId> entryIds,
    AppLocalizations l10n,
  ) async {
    final String fileName = VaultBackupPolicy.htmlPortableFileName(
      DateTime.now(),
    );
    return _writeTempAndDeliver(
      dialogTitle: l10n.vaultTransferPickHtmlDirectoryTitle,
      fileName: fileName,
      l10n: l10n,
      writeTarget: (File target) {
        return _archiveIo.writeSelectedHtmlExport(
          session: session,
          entryIds: entryIds,
          target: target,
        );
      },
    );
  }

  Future<PortableImportResult?> importDocumentsWithPicker(
    UnlockedVaultSession session, {
    required AppLocalizations l10n,
  }) async {
    final PortableImportResult? pickedResult = await _tryImportFromPickedFiles(
      session,
      l10n: l10n,
    );
    if (pickedResult != null) {
      return pickedResult;
    }

    final String? sourceDirectory =
        await ExternalDirectoryPicker.pickExternalDirectory(
          prompt: l10n.vaultTransferImportDocumentsDirectoryPrompt,
          initialDirectory: await _externalDirectoryStore
              .resolveInitialDirectory(),
        );
    if (sourceDirectory == null) {
      return null;
    }

    await _externalDirectoryStore.rememberDirectory(sourceDirectory);

    return _archiveIo.importDocuments(
      session: session,
      rootDirectory: Directory(sourceDirectory),
    );
  }

  Future<PickedBackupFile?> pickLocalBackupFile(AppLocalizations l10n) async {
    final PlatformFile? picked = await FilePicker.pickFile(
      dialogTitle: l10n.vaultTransferPickBackupFileTitle,
      type: FileType.custom,
      allowedExtensions: const <String>[VaultBackupPolicy.fileExtension],
    );
    if (picked == null) {
      return null;
    }
    return _resolvePickedBackupFile(picked);
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
      destinationDirectory: await getTemporaryDirectory(),
      totalBytes: backup.sizeBytes,
      onProgress: onProgress,
    );
  }

  Future<void> restoreFromDownloadedBackupFile(File backupFile) async {
    await restoreFromBackupFile(backupFile);
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

  Future<PickedBackupFile?> _resolvePickedBackupFile(PlatformFile file) async {
    final String? path = file.path;
    if (path != null && path.isNotEmpty) {
      try {
        if (File(path).existsSync()) {
          return PickedBackupFile(
            file: File(path),
            shouldDeleteAfterUse: false,
          );
        }
      } on Object {
        // Ignore unsupported URI-style paths and try the bytes fallback.
      }
    }

    final Uint8List? bytes = await _readPlatformFileBytes(file);
    if (bytes == null) {
      return null;
    }

    final String baseName = file.name.isNotEmpty
        ? file.name
        : 'restore.${VaultBackupPolicy.fileExtension}';
    final File tempBackup = await _createTempFile(baseName);
    await tempBackup.writeAsBytes(bytes, flush: true);
    return PickedBackupFile(file: tempBackup, shouldDeleteAfterUse: true);
  }

  Future<void> _ensureFileInsideLocalBackupsDirectory(
    File file, {
    AppLocalizations? l10n,
  }) async {
    final Directory backupsDirectory = await _pathStrategy
        .localBackupsDirectory();
    final String root = p.normalize(backupsDirectory.absolute.path);
    final String target = p.normalize(file.absolute.path);
    if (target == root || !p.isWithin(root, target)) {
      throw StateError(
        l10n?.vaultTransferBackupOutsideExpectedDirectory ??
            'Backup file is outside the expected directory.',
      );
    }
  }

  Future<PortableImportResult?> _tryImportFromPickedFiles(
    UnlockedVaultSession session, {
    required AppLocalizations l10n,
  }) async {
    final FilePickerResult? picked = await FilePicker.pickFiles(
      dialogTitle: l10n.vaultTransferImportDocumentsFileTitle,
      type: FileType.custom,
      allowedExtensions: const <String>['zip', 'md', 'html', 'htm'],
    );
    if (picked == null || picked.files.isEmpty) {
      return null;
    }

    final List<PlatformFile> zipFiles = picked.files
        .where((PlatformFile file) => _extensionOf(file) == '.zip')
        .toList(growable: false);
    if (zipFiles.isNotEmpty) {
      return _importZipFile(session, zipFiles.first);
    }

    final List<PlatformFile> documentFiles = picked.files
        .where(
          (PlatformFile file) =>
              _isPortableDocumentExtension(_extensionOf(file)),
        )
        .toList(growable: false);
    if (documentFiles.isEmpty) {
      return null;
    }

    return _importPickedDocumentFiles(session, documentFiles);
  }

  Future<PortableImportResult?> _importZipFile(
    UnlockedVaultSession session,
    PlatformFile zipFile,
  ) async {
    final String? path = zipFile.path;
    if (path != null && path.isNotEmpty) {
      try {
        if (File(path).existsSync()) {
          return _archiveIo.importDocumentsFromZip(
            session: session,
            zipFile: File(path),
          );
        }
      } on Object {
        // Ignore unsupported URI-style paths and try the bytes fallback.
      }
    }

    final Uint8List? bytes = await _readPlatformFileBytes(zipFile);
    if (bytes == null) {
      return null;
    }

    final File tempZip = await _createTempFile(
      zipFile.name.isNotEmpty ? zipFile.name : 'portable_import.zip',
    );
    try {
      await tempZip.writeAsBytes(bytes, flush: true);
      return await _archiveIo.importDocumentsFromZip(
        session: session,
        zipFile: tempZip,
      );
    } finally {
      await _deleteIfExists(tempZip);
    }
  }

  Future<PortableImportResult?> _importPickedDocumentFiles(
    UnlockedVaultSession session,
    List<PlatformFile> documentFiles,
  ) async {
    final Directory tempRoot = await _createTempDirectory('import_picked');
    try {
      var copiedFiles = 0;
      for (final PlatformFile file in documentFiles) {
        final String extension = _extensionOf(file);
        if (!_isPortableDocumentExtension(extension)) {
          continue;
        }

        final String fileName = uniqueImportedDocumentFileName(
          sourceName: file.name,
          extension: extension,
          index: copiedFiles,
        );
        final File destination = File(p.join(tempRoot.path, fileName));

        final String? path = file.path;
        if (path != null && path.isNotEmpty) {
          try {
            if (File(path).existsSync()) {
              await File(path).copy(destination.path);
              copiedFiles++;
              continue;
            }
          } on Object {
            // Ignore unsupported URI-style paths and try the bytes fallback.
          }
        }

        final Uint8List? bytes = await _readPlatformFileBytes(file);
        if (bytes == null) {
          continue;
        }
        await destination.writeAsBytes(bytes, flush: true);
        copiedFiles++;
      }

      if (copiedFiles == 0) {
        return null;
      }

      return _archiveIo.importDocuments(
        session: session,
        rootDirectory: tempRoot,
      );
    } finally {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    }
  }

  Future<Uint8List?> _readPlatformFileBytes(PlatformFile file) async {
    try {
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }
      return bytes;
    } on Object {
      return null;
    }
  }

  String _extensionOf(PlatformFile file) {
    final String fromName = p.extension(file.name).toLowerCase();
    if (fromName.isNotEmpty) {
      return fromName;
    }
    final String? path = file.path;
    if (path == null || path.isEmpty) {
      return '';
    }
    return p.extension(path).toLowerCase();
  }

  bool _isPortableDocumentExtension(String extension) {
    return extension == '.md' || extension == '.html' || extension == '.htm';
  }

  @visibleForTesting
  static String uniqueImportedDocumentFileName({
    required String sourceName,
    required String extension,
    required int index,
  }) {
    final String normalizedExtension = extension.isNotEmpty
        ? extension
        : p.extension(sourceName).toLowerCase();
    final String fallbackName = normalizedExtension.isNotEmpty
        ? 'imported_entry$index$normalizedExtension'
        : 'imported_entry$index';
    final String baseName = sourceName.trim().isNotEmpty
        ? p.basename(sourceName.trim())
        : fallbackName;
    return '${(index + 1).toString().padLeft(4, '0')}_$baseName';
  }

  Future<Directory> _createTempDirectory(String prefix) async {
    final Directory tempDirectory = await getTemporaryDirectory();
    final Directory directory = Directory(
      p.join(
        tempDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}_$prefix',
      ),
    );
    await directory.create(recursive: true);
    return directory;
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

  @visibleForTesting
  Future<BackupPersistResult> runInspectedBackupPipelineForTesting({
    required Future<String?> Function(
      File stagingZip,
      String fileName,
      BackupTaskProgressListener? deliverProgress,
    )
    deliver,
    BackupTaskProgressListener? onProgress,
  }) {
    return _runInspectedBackupPipeline(
      deliver: deliver,
      onProgress: onProgress,
    );
  }

  Future<String?> _writeTempAndDeliver({
    required String dialogTitle,
    required String fileName,
    required AppLocalizations l10n,
    required Future<void> Function(File target) writeTarget,
  }) async {
    final File tempFile = await _createTempFile(fileName);
    try {
      await writeTarget(tempFile);
      return await deliverToExternalDirectory(
        dialogTitle: dialogTitle,
        fileName: fileName,
        sourceFile: tempFile,
        l10n: l10n,
        resolveInitialDirectory:
            _externalDirectoryStore.resolveInitialDirectory,
        rememberDirectory: _externalDirectoryStore.rememberDirectory,
      );
    } finally {
      await _deleteIfExists(tempFile);
    }
  }

  Future<void> _deleteIfExists(File file) async {
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
