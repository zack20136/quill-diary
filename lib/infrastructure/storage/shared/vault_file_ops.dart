import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../vault_path_strategy.dart';

/// 在 app 暫存目錄建立唯一工作資料夾。
Future<Directory> createWorkingDirectory(
  VaultPathStrategy pathStrategy,
  String prefix,
) async {
  final Directory appRoot = await pathStrategy.appRootDirectory();
  final Directory tempRoot = Directory(p.join(appRoot.path, '_tmp'));
  await tempRoot.create(recursive: true);

  final Directory workingDirectory = Directory(
    p.join(tempRoot.path, '${prefix}_${DateTime.now().microsecondsSinceEpoch}'),
  );
  await workingDirectory.create(recursive: true);
  return workingDirectory;
}

/// 以暫存檔寫入後 rename，避免中斷時留下半寫入的目標檔。
Future<void> atomicWriteString(File file, String content) async {
  await file.parent.create(recursive: true);
  final File tempFile = File('${file.path}.tmp');
  await tempFile.writeAsString(content, flush: true);
  if (file.existsSync()) {
    await file.delete();
  }
  await tempFile.rename(file.path);
}

/// 以同目錄 rename 可復原地取代檔案；寫入失敗時保留最後有效版本。
Future<void> replaceFileBytesRecoverably(File file, Uint8List bytes) async {
  await file.parent.create(recursive: true);
  await recoverFileReplacement(file);
  final File tempFile = File('${file.path}.tmp');
  final File backupFile = File('${file.path}.previous');
  await tempFile.writeAsBytes(bytes, flush: true);
  var movedOriginal = false;
  try {
    if (file.existsSync()) {
      await file.rename(backupFile.path);
      movedOriginal = true;
    }
    await tempFile.rename(file.path);
    if (backupFile.existsSync()) {
      await backupFile.delete();
    }
  } on Object catch (error, stackTrace) {
    if (!file.existsSync() && movedOriginal && backupFile.existsSync()) {
      await backupFile.rename(file.path);
    }
    if (tempFile.existsSync()) {
      await tempFile.delete();
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}

/// 修復上次可復原替換在程序中止時留下的同目錄檔案。
Future<void> recoverFileReplacement(File file) async {
  final File tempFile = File('${file.path}.tmp');
  final File backupFile = File('${file.path}.previous');
  if (!file.existsSync() && backupFile.existsSync()) {
    await backupFile.rename(file.path);
  } else if (file.existsSync() && backupFile.existsSync()) {
    await backupFile.delete();
  }
  if (!file.existsSync() && tempFile.existsSync()) {
    await tempFile.rename(file.path);
  } else if (file.existsSync() && tempFile.existsSync()) {
    await tempFile.delete();
  }
}

/// 刪除檔案（存在時）；忽略刪除失敗。
Future<void> deleteFileIfExists(String path) async {
  final File file = File(path);
  if (!file.existsSync()) {
    return;
  }
  try {
    await file.delete();
  } on Object {
    // 忽略刪除失敗。
  }
}
