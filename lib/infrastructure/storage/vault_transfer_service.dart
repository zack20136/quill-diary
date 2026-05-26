import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/recovery/recovery_metadata.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import '../drive/drive_backup_service.dart';
import 'export_save_location_store.dart';
import 'restore_precheck.dart';
import 'vault_archive_io.dart';
import 'vault_repository.dart';

class BackupCreationResult {
  const BackupCreationResult({
    required this.path,
    required this.healthReport,
  });

  final String path;
  final BackupHealthReport healthReport;
}

class VaultTransferService {
  VaultTransferService({
    required VaultArchiveIo archiveIo,
    required DriveBackupService driveBackupService,
    required VaultRepository vaultRepository,
    required ExportSaveLocationStore exportSaveLocationStore,
  })  : _archiveIo = archiveIo,
        _driveBackupService = driveBackupService,
        _vaultRepository = vaultRepository,
        _exportSaveLocationStore = exportSaveLocationStore;

  final VaultArchiveIo _archiveIo;
  final DriveBackupService _driveBackupService;
  final VaultRepository _vaultRepository;
  final ExportSaveLocationStore _exportSaveLocationStore;

  Future<void> resetGoogleDriveSignInForConsentRetry() {
    return _driveBackupService.resetSignInSessionForConsentRetry();
  }

  Future<BackupCreationResult?> createBackupWithPicker() async {
    final String fileName = '${_backupTimestamp(DateTime.now())}.jbackup';
    return _saveBackupWithPicker(fileName: fileName);
  }

  Future<BackupHealthReport> checkBackupHealth(File backupFile) {
    return _archiveIo.checkBackupHealth(backupFile);
  }

  Future<String?> exportMarkdownWithPicker(UnlockedVaultSession session) async {
    final String fileName = 'markdown_export_${DateTime.now().millisecondsSinceEpoch}.zip';
    return _saveGeneratedFileWithPicker(
      dialogTitle: '儲存 Markdown 匯出 zip',
      fileName: fileName,
      allowedExtensions: const <String>['zip'],
      writeTarget: (File target) => _archiveIo.writePortableExportZip(
        session: session,
        target: target,
      ),
    );
  }

  Future<HtmlExportEstimate> estimateSelectedHtmlExport(Set<EntryId> entryIds) {
    return _archiveIo.estimateSelectedHtmlExport(entryIds: entryIds);
  }

  Future<String?> exportSelectedHtmlWithPicker(
    UnlockedVaultSession session,
    Set<EntryId> entryIds,
  ) async {
    final String fileName = 'diary_export_${DateTime.now().millisecondsSinceEpoch}.html';
    return _saveGeneratedFileWithPicker(
      dialogTitle: '儲存 HTML 匯出',
      fileName: fileName,
      allowedExtensions: const <String>['html'],
      writeTarget: (File target) => _archiveIo.writeSelectedHtmlExport(
        session: session,
        entryIds: entryIds,
        target: target,
      ),
    );
  }

  Future<PortableImportResult?> importDocumentsWithPicker(
    UnlockedVaultSession session,
  ) async {
    final PortableImportResult? pickedResult = await _tryImportFromPickedFiles(session);
    if (pickedResult != null) {
      return pickedResult;
    }

    final String? sourceDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: '選擇要匯入的資料夾（含附件的 Markdown / HTML）',
      initialDirectory: await _exportSaveLocationStore.resolveInitialDirectory(),
    );
    if (sourceDirectory == null) {
      return null;
    }

    await _exportSaveLocationStore.rememberDirectory(sourceDirectory);

    return _archiveIo.importDocuments(
      session: session,
      rootDirectory: Directory(sourceDirectory),
    );
  }

  /// Lets the user pick a `.jbackup` file and resolves it to a readable [File].
  Future<File?> pickLocalBackupFile() async {
    final FilePickerResult? picked = await FilePicker.pickFiles(
      dialogTitle: '選擇本機備份檔',
      type: FileType.custom,
      allowedExtensions: const <String>['jbackup'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return null;
    }
    return _resolvePickedBackupFile(picked.files.single);
  }

  Future<RestorePrecheck> precheckRestore(File backupFile) async {
    final BackupRecoveryPreview preview = await _archiveIo.peekBackupRecovery(backupFile);
    final RecoveryMetadata? localMetadata = await _vaultRepository.readRecoveryMetadata();
    final bool localHasTrusted = localMetadata != null &&
        await _vaultRepository.hasTrustedDeviceAccess();
    return RestorePrecheck(
      preview: preview,
      localVaultId: localMetadata?.vaultId,
      localRecoverySaltBase64: localMetadata?.kdf.saltBase64,
      localHasTrustedDevice: localHasTrusted,
      willOverwriteLocalVault: await _vaultRepository.hasVault(),
    );
  }

  Future<void> verifyBackupRecoveryKey(File backupFile, String recoveryKey) async {
    await _archiveIo.verifyBackupRecoveryKey(backupFile, recoveryKey);
  }

  Future<void> restoreFromBackupFile(
    File backupFile, {
    bool preserveTrustedDeviceAccess = false,
  }) async {
    await _archiveIo.restoreBackupZip(
      backupFile,
      preserveTrustedDeviceAccess: preserveTrustedDeviceAccess,
    );
  }

  Future<File?> _resolvePickedBackupFile(PlatformFile file) async {
    final String? path = file.path;
    if (path != null && path.isNotEmpty) {
      try {
        if (File(path).existsSync()) {
          return File(path);
        }
      } on Object {
        // 某些平台會回傳 content URI，無法直接用 dart:io 開啟。
      }
    }
    final Uint8List? bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    final String baseName = file.name.isNotEmpty ? file.name : 'restore.jbackup';
    final File tempBackup = await _createTempFile(baseName);
    await tempBackup.writeAsBytes(bytes, flush: true);
    return tempBackup;
  }

  Future<String> uploadBackupToDrive() async {
    final api = await _driveBackupService.createAuthorizedDriveApi();
    final File tempBackup = await _createTempFile('${_backupTimestamp(DateTime.now())}.jbackup');
    try {
      await _archiveIo.writeBackupZip(tempBackup);
      return await _driveBackupService.uploadBackup(tempBackup, reuseApi: api);
    } finally {
      await _deleteIfExists(tempBackup);
    }
  }

  Future<List<DriveBackupFile>> listDriveBackups() async {
    return _driveBackupService.listBackups();
  }

  Future<File> downloadDriveBackupToTempFile(DriveBackupFile backup) async {
    final api = await _driveBackupService.createAuthorizedDriveApi();
    return _driveBackupService.downloadBackupById(
      fileId: backup.id,
      fileName: backup.name,
      destinationDirectory: await getTemporaryDirectory(),
      reuseApi: api,
    );
  }

  Future<void> restoreFromDownloadedBackupFile(File backupFile) async {
    await restoreFromBackupFile(backupFile);
  }

  Future<PortableImportResult?> _tryImportFromPickedFiles(
    UnlockedVaultSession session,
  ) async {
    final FilePickerResult? picked = await FilePicker.pickFiles(
      dialogTitle: '選擇 zip、Markdown 或 HTML，或取消後改選資料夾',
      type: FileType.custom,
      allowedExtensions: const <String>['zip', 'md', 'html', 'htm'],
      withData: true,
      allowMultiple: true,
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
        .where((PlatformFile file) => _isPortableDocumentExtension(_extensionOf(file)))
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
          return await _archiveIo.importDocumentsFromZip(
            session: session,
            zipFile: File(path),
          );
        }
      } on Object {
        // 某些平台會回傳 content URI，改走暫存檔。
      }
    }

    final Uint8List? bytes = zipFile.bytes;
    if (bytes == null || bytes.isEmpty) {
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

        final String fileName = file.name.trim().isNotEmpty
            ? p.basename(file.name)
            : 'imported_entry$copiedFiles$extension';
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
            // 某些平台會回傳 content URI，改走 bytes。
          }
        }

        final Uint8List? bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) {
          continue;
        }
        await destination.writeAsBytes(bytes, flush: true);
        copiedFiles++;
      }

      if (copiedFiles == 0) {
        return null;
      }

      return await _archiveIo.importDocuments(
        session: session,
        rootDirectory: tempRoot,
      );
    } finally {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
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

  String _backupTimestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return 'backup_${value.year}-${two(value.month)}-${two(value.day)}_'
        '${two(value.hour)}-${two(value.minute)}-${two(value.second)}';
  }

  Future<BackupCreationResult?> _saveBackupWithPicker({
    required String fileName,
  }) async {
    final String? initialDirectory =
        await _exportSaveLocationStore.resolveInitialDirectory();

    if (Platform.isAndroid || Platform.isIOS) {
      final File tempFile = await _createTempFile(fileName);
      try {
        await _archiveIo.writeBackupZip(tempFile);
        final BackupHealthReport report = await checkBackupHealth(tempFile);
        final String? path = await FilePicker.saveFile(
          dialogTitle: '儲存本機備份',
          fileName: fileName,
          initialDirectory: initialDirectory,
          type: FileType.custom,
          allowedExtensions: const <String>['jbackup'],
          bytes: await tempFile.readAsBytes(),
        );
        if (path == null) {
          return null;
        }
        await _exportSaveLocationStore.rememberSavedFilePath(path);
        return BackupCreationResult(path: path, healthReport: report);
      } finally {
        await _deleteIfExists(tempFile);
      }
    }

    final String? targetPath = await FilePicker.saveFile(
      dialogTitle: '儲存本機備份',
      fileName: fileName,
      initialDirectory: initialDirectory,
      type: FileType.custom,
      allowedExtensions: const <String>['jbackup'],
    );
    if (targetPath == null) {
      return null;
    }
    final File target = File(targetPath);
    await _archiveIo.writeBackupZip(target);
    await _exportSaveLocationStore.rememberSavedFilePath(targetPath);
    return BackupCreationResult(
      path: targetPath,
      healthReport: await checkBackupHealth(target),
    );
  }

  Future<String?> _saveGeneratedFileWithPicker({
    required String dialogTitle,
    required String fileName,
    required List<String> allowedExtensions,
    required Future<void> Function(File target) writeTarget,
  }) async {
    final String? initialDirectory =
        await _exportSaveLocationStore.resolveInitialDirectory();

    if (Platform.isAndroid || Platform.isIOS) {
      final File tempFile = await _createTempFile(fileName);
      try {
        await writeTarget(tempFile);
        final String? path = await FilePicker.saveFile(
          dialogTitle: dialogTitle,
          fileName: fileName,
          initialDirectory: initialDirectory,
          type: FileType.custom,
          allowedExtensions: allowedExtensions,
          bytes: await tempFile.readAsBytes(),
        );
        if (path == null) {
          return null;
        }
        await _exportSaveLocationStore.rememberSavedFilePath(path);
        return path;
      } finally {
        await _deleteIfExists(tempFile);
      }
    }

    final String? targetPath = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      initialDirectory: initialDirectory,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (targetPath == null) {
      return null;
    }
    await writeTarget(File(targetPath));
    await _exportSaveLocationStore.rememberSavedFilePath(targetPath);
    return targetPath;
  }

  Future<void> _deleteIfExists(File file) async {
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
