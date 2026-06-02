import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// 拒絕 zip slip 等不安全路徑。
void ensureSafeArchivePath(String relativePath) {
  if (relativePath.contains('..') || p.isAbsolute(relativePath)) {
    throw const FormatException('匯入封存包含不安全的路徑。');
  }
}

/// 將 [archive] 解壓至 [targetDirectory]。
Future<void> extractArchiveToDirectory({
  required Archive archive,
  required Directory targetDirectory,
}) async {
  for (final ArchiveFile archiveFile in archive.files) {
    ensureSafeArchivePath(archiveFile.name);
    final String outputPath = p.join(targetDirectory.path, archiveFile.name);
    if (archiveFile.isFile) {
      final File file = File(outputPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        archiveFile.content as List<int>,
        flush: true,
      );
    } else {
      await Directory(outputPath).create(recursive: true);
    }
  }
}

Future<Archive> decodeBackupArchive(File backupFile) async {
  return ZipDecoder().decodeBytes(
    await backupFile.readAsBytes(),
    verify: true,
  );
}
