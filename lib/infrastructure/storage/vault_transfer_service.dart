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
      final File tempBackup = await _createTempBackupFile(fileName);
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
    final String? targetDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: '選擇 Markdown 匯出位置',
      initialDirectory: await _downloadsInitialDirectory(),
    );
    if (targetDirectory == null) {
      return null;
    }
    final Directory output = await _archiveIo.exportMarkdown(
      session: session,
      parentDirectory: Directory(targetDirectory),
    );
    return output.path;
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
    final String baseName =
        file.name.isNotEmpty ? file.name : 'restore.jbackup';
    final File tempBackup = await _createTempBackupFile(baseName);
    try {
      await tempBackup.writeAsBytes(bytes, flush: true);
      await _archiveIo.restoreBackupZip(tempBackup);
    } finally {
      await _deleteIfExists(tempBackup);
    }
    return true;
  }

  Future<String> uploadBackupToDrive() async {
    // 先完成登入／同意，再壓縮；上傳時重用同一 Drive client，勿在長時間 zip 後再觸發第二輪授權。
    final api = await _driveBackupService.createAuthorizedDriveApi();
    final File tempBackup = await _createTempBackupFile(
      '${generateBackupId()}.jbackup',
    );
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

  Future<File> _createTempBackupFile(String fileName) async {
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
