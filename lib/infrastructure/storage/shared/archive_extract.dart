import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
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

/// 以 [decodeStream] 開啟的 zip；使用完畢須呼叫 [close]。
final class OpenedZipArchive {
  OpenedZipArchive._(this._input, this.archive);

  final InputFileStream _input;
  final Archive archive;

  Future<void> close() async {
    await archive.clear();
    await _input.close();
  }
}

Future<OpenedZipArchive> openZipArchive(File file, {bool verify = true}) async {
  final InputFileStream input = InputFileStream(file.path);
  try {
    final Archive archive = ZipDecoder().decodeStream(input, verify: verify);
    return OpenedZipArchive._(input, archive);
  } on Object {
    await input.close();
    rethrow;
  }
}

ArchiveFile? findZipEntry(Archive archive, {required String pathSuffix}) {
  final String suffix = pathSuffix.toLowerCase();
  for (final ArchiveFile file in archive.files) {
    if (!file.isFile) {
      continue;
    }
    final String normalized =
        p.posix.normalize(file.name.replaceAll('\\', '/')).toLowerCase();
    if (normalized == suffix || normalized.endsWith('/$suffix')) {
      return file;
    }
  }
  return null;
}

/// 依路徑後綴選讀單一 entry（例如 recovery.json）。
Uint8List? readZipEntry(Archive archive, {required String pathSuffix}) {
  return findZipEntry(archive, pathSuffix: pathSuffix)?.readBytes();
}

/// 讀取 manifest.json.enc，否則取第一篇 .md.enc 作為加密樣本。
Uint8List? readEncryptedSampleBytes(Archive archive) {
  final Uint8List? manifest = readZipEntry(archive, pathSuffix: 'manifest.json.enc');
  if (manifest != null) {
    return manifest;
  }
  for (final ArchiveFile file in archive.files) {
    if (!file.isFile) {
      continue;
    }
    final String normalized =
        p.posix.normalize(file.name.replaceAll('\\', '/')).toLowerCase();
    if (normalized.endsWith('.md.enc')) {
      return file.readBytes();
    }
  }
  return null;
}

/// 以 OS 層複製檔案，避免 readAsBytes 整包進記憶體。
Future<void> copyFileToPath(File source, String destinationPath) async {
  await File(destinationPath).parent.create(recursive: true);
  await source.copy(destinationPath);
}

/// 驗證路徑後，將 [zip] 串流解壓至 [targetDirectory]。
Future<void> extractArchiveToDirectory({
  required OpenedZipArchive zip,
  required Directory targetDirectory,
}) async {
  for (final ArchiveFile archiveFile in zip.archive.files) {
    final String safeRelativePath = safeArchiveRelativePath(archiveFile.name);
    final String outputPath = p.join(targetDirectory.path, safeRelativePath);
    if (archiveFile.isFile) {
      await File(outputPath).parent.create(recursive: true);
      final OutputFileStream output = OutputFileStream(outputPath);
      try {
        archiveFile.writeContent(output);
        await output.close();
      } on Object {
        await output.close();
        rethrow;
      }
    } else {
      await Directory(outputPath).create(recursive: true);
    }
  }
}
