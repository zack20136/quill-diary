import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// 解壓前拒絕 zip-slip 等不安全路徑。
void ensureSafeArchivePath(String relativePath) {
  final String normalizedSeparators = relativePath.replaceAll('\\', '/');
  final String normalized = p.posix.normalize(normalizedSeparators);
  final List<String> segments = p.posix.split(normalized);
  if (normalized.isEmpty ||
      normalized == '.' ||
      p.posix.isAbsolute(normalized) ||
      p.isAbsolute(normalizedSeparators) ||
      segments.contains('..')) {
    throw const FormatException('匯入壓縮檔包含不安全路徑。');
  }
}

String safeArchiveRelativePath(String relativePath) {
  ensureSafeArchivePath(relativePath);
  return p.posix.normalize(relativePath.replaceAll('\\', '/'));
}

/// 驗證每個路徑後，將 [archive] 解壓至 [targetDirectory]。
Future<void> extractArchiveToDirectory({
  required Archive archive,
  required Directory targetDirectory,
}) async {
  for (final ArchiveFile archiveFile in archive.files) {
    final String safeRelativePath = safeArchiveRelativePath(archiveFile.name);
    final String outputPath = p.join(targetDirectory.path, safeRelativePath);
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
