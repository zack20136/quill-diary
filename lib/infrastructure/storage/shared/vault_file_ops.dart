import 'dart:io';

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
