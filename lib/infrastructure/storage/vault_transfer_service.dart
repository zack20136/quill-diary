import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import '../drive/drive_backup_service.dart';
import 'vault_archive_io.dart';

class VaultTransferService {
  VaultTransferService({
    required VaultArchiveIo archiveIo,
    required DriveBackupService driveBackupService,
  })  : _archiveIo = archiveIo,
        _driveBackupService = driveBackupService;

  final VaultArchiveIo _archiveIo;
  final DriveBackupService _driveBackupService;

  Future<void> resetGoogleDriveSignInForConsentRetry() {
    return _driveBackupService.resetSignInSessionForConsentRetry();
  }

  Future<String?> createBackupWithPicker() async {
    final String fileName = '${generateBackupId()}.jbackup';
    final String? initialDirectory = await _downloadsInitialDirectory();

    if (Platform.isAndroid || Platform.isIOS) {
      final File tempBackup = await _createTempFile(fileName);
      try {
        await _archiveIo.writeBackupZip(tempBackup);
        return await FilePicker.saveFile(
          dialogTitle: '儲存本機備份',
          fileName: fileName,
          initialDirectory: initialDirectory,
          type: FileType.custom,
          allowedExtensions: const <String>['jbackup'],
          bytes: await tempBackup.readAsBytes(),
        );
      } finally {
        await _deleteIfExists(tempBackup);
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
    await _archiveIo.writeBackupZip(File(targetPath));
    return targetPath;
  }

  Future<String?> exportMarkdownWithPicker(UnlockedVaultSession session) async {
    final String fileName = 'markdown_export_${DateTime.now().millisecondsSinceEpoch}.zip';
    final String? initialDirectory = await _downloadsInitialDirectory();

    if (Platform.isAndroid || Platform.isIOS) {
      final File tempZip = await _createTempFile(fileName);
      try {
        await _archiveIo.writePortableExportZip(
          session: session,
          target: tempZip,
        );
        return await FilePicker.saveFile(
          dialogTitle: '儲存 Markdown 匯出 zip',
          fileName: fileName,
          initialDirectory: initialDirectory,
          type: FileType.custom,
          allowedExtensions: const <String>['zip'],
          bytes: await tempZip.readAsBytes(),
        );
      } finally {
        await _deleteIfExists(tempZip);
      }
    }

    final String? targetPath = await FilePicker.saveFile(
      dialogTitle: '儲存 Markdown 匯出 zip',
      fileName: fileName,
      initialDirectory: initialDirectory,
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
    );
    if (targetPath == null) {
      return null;
    }
    await _archiveIo.writePortableExportZip(
      session: session,
      target: File(targetPath),
    );
    return targetPath;
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
      initialDirectory: await _downloadsInitialDirectory(),
    );
    if (sourceDirectory == null) {
      return null;
    }

    return _archiveIo.importDocuments(
      session: session,
      rootDirectory: Directory(sourceDirectory),
    );
  }

  Future<bool> restoreBackupFromPicker() async {
    final FilePickerResult? picked = await FilePicker.pickFiles(
      dialogTitle: '選擇本機備份檔',
      type: FileType.custom,
      allowedExtensions: const <String>['jbackup'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return false;
    }
    final PlatformFile file = picked.files.single;
    final String? path = file.path;
    if (path != null && path.isNotEmpty) {
      try {
        if (File(path).existsSync()) {
          await _archiveIo.restoreBackupZip(File(path));
          return true;
        }
      } on Object {
        // 某些平台會回傳 content URI，無法直接用 dart:io 開啟。
      }
    }
    final Uint8List? bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      return false;
    }
    final String baseName = file.name.isNotEmpty ? file.name : 'restore.jbackup';
    final File tempBackup = await _createTempFile(baseName);
    try {
      await tempBackup.writeAsBytes(bytes, flush: true);
      await _archiveIo.restoreBackupZip(tempBackup);
    } finally {
      await _deleteIfExists(tempBackup);
    }
    return true;
  }

  Future<String> uploadBackupToDrive() async {
    final api = await _driveBackupService.createAuthorizedDriveApi();
    final File tempBackup = await _createTempFile('${generateBackupId()}.jbackup');
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

  Future<void> restoreDriveBackup(DriveBackupFile backup) async {
    final api = await _driveBackupService.createAuthorizedDriveApi();
    final File tempBackup = await _driveBackupService.downloadBackupById(
      fileId: backup.id,
      fileName: backup.name,
      destinationDirectory: await getTemporaryDirectory(),
      reuseApi: api,
    );
    try {
      await _archiveIo.restoreBackupZip(tempBackup);
    } finally {
      await _deleteIfExists(tempBackup);
    }
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

  Future<String?> _downloadsInitialDirectory() async {
    return (await getDownloadsDirectory())?.path;
  }

  Future<void> _deleteIfExists(File file) async {
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
