import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/shared/android_saf_file_copy.dart';
import 'package:quill_diary/infrastructure/storage/shared/external_directory_picker.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';

Future<String?> deliverToExternalDirectory({
  required String dialogTitle,
  required String fileName,
  required FileSystemEntity source,
  required Future<String?> Function() resolveInitialDirectory,
  required Future<void> Function(String directoryOrTreeUri) rememberDirectory,
  BackupTaskProgressListener? onProgress,
}) async {
  final String? picked = await ExternalDirectoryPicker.pickExternalDirectory(
    prompt: dialogTitle,
    initialDirectory: await resolveInitialDirectory(),
    writableOnAndroid: true,
  );
  if (picked == null || picked.trim().isEmpty) {
    return null;
  }

  final String trimmed = picked.trim();
  final String destinationPath;
  if (Platform.isAndroid) {
    if (!trimmed.startsWith('content://')) {
      throw const AndroidSafWriteException();
    }
    onProgress?.call(
      const BackupTaskProgress(phase: BackupTaskPhase.copyingBackup),
    );
    destinationPath = await AndroidSafFileCopy.copyToTree(
      treeUri: trimmed,
      source: source,
      fileName: fileName,
      mimeType: mimeTypeForExportFileName(fileName),
    );
  } else if (source is Directory) {
    final directory = await Directory(trimmed).createTemp('${fileName}_');
    try {
      final assets = Directory(p.join(source.path, 'assets'));
      if (await assets.exists()) {
        final destinationAssets = await Directory(
          p.join(directory.path, 'assets'),
        ).create();
        await for (final asset in assets.list(followLinks: false)) {
          if (asset is File) {
            await asset.copy(
              p.join(destinationAssets.path, p.basename(asset.path)),
            );
          }
        }
      }
      await File(p.join(source.path, 'diary.html'))
          .copy(p.join(directory.path, 'diary.html'));
      destinationPath = directory.path;
    } on Object {
      await deleteWorkingDirectory(directory);
      rethrow;
    }
  } else {
    destinationPath = p.join(trimmed, fileName);
    await copyFileToPath(
      source as File,
      destinationPath,
      onProgress: onProgress,
    );
  }
  try {
    await rememberDirectory(trimmed);
  } on Exception {
    // 上次選取的資料夾只是偏好，檔案已交付。
  }
  return destinationPath;
}
