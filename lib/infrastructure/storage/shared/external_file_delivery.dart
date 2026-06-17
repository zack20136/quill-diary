import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../l10n/l10n.dart';
import '../backup_task_progress.dart';
import '../media_store_export.dart';
import 'android_saf_file_copy.dart';
import 'archive_extract.dart';
import 'external_directory_picker.dart';

/// 將暫存檔交付至使用者選擇的外部資料夾。
Future<String?> deliverToExternalDirectory({
  required String dialogTitle,
  required String fileName,
  required File sourceFile,
  required AppLocalizations l10n,
  required Future<String?> Function() resolveInitialDirectory,
  required Future<void> Function(String directoryOrTreeUri) rememberDirectory,
  BackupTaskProgressListener? onProgress,
}) async {
  if (Platform.isAndroid) {
    await MediaStoreExport.ensureDownloadsSubfolder();
  }

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
    onProgress?.call(
      const BackupTaskProgress(phase: BackupTaskPhase.copyingBackup),
    );
    final String savedUri = await AndroidSafFileCopy.copyFileToTree(
      treeUri: trimmed,
      sourceFile: sourceFile,
      fileName: fileName,
      mimeType: mimeTypeForExportFileName(fileName),
      l10n: l10n,
    );
    await rememberDirectory(trimmed);
    return savedUri;
  }

  if (Platform.isAndroid) {
    throw StateError('無法寫入選擇的資料夾，請重新選擇並允許存取。');
  }
  final String destinationPath = p.join(trimmed, fileName);
  await copyFileToPath(sourceFile, destinationPath, onProgress: onProgress);
  await rememberDirectory(trimmed);
  return destinationPath;
}
