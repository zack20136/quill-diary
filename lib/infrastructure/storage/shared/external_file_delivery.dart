import 'dart:io';

import 'package:path/path.dart' as p;

import 'android_saf_file_copy.dart';
import 'archive_extract.dart';
import 'external_directory_picker.dart';

/// 將暫存檔交付至使用者選擇的外部資料夾。
Future<String?> deliverToExternalDirectory({
  required String dialogTitle,
  required String fileName,
  required File sourceFile,
  required Future<String?> Function() resolveInitialDirectory,
  required Future<void> Function(String directoryOrTreeUri) rememberDirectory,
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
  if (Platform.isAndroid && trimmed.startsWith('content://')) {
    final String savedUri = await AndroidSafFileCopy.copyFileToTree(
      treeUri: trimmed,
      sourceFile: sourceFile,
      fileName: fileName,
      mimeType: mimeTypeForExportFileName(fileName),
    );
    await rememberDirectory(trimmed);
    return savedUri;
  }

  if (Platform.isAndroid) {
    throw StateError('無法寫入選擇的資料夾，請重新選擇並允許存取。');
  }
  final String destinationPath = p.join(trimmed, fileName);
  await copyFileToPath(sourceFile, destinationPath);
  await rememberDirectory(trimmed);
  return destinationPath;
}
