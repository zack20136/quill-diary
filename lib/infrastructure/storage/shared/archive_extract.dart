import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';

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

enum ArchiveExtractionLimit {
  tooManyEntries,
  entryTooLarge,
  totalTooLarge,
  suspiciousRatio,
}

class ArchiveExtractionLimitException implements Exception {
  const ArchiveExtractionLimitException(this.limit);

  final ArchiveExtractionLimit limit;
}

/// 解壓前的資源上限。加密日記與圖片幾乎無法再壓縮，過高比例視為壓縮炸彈。
class ArchiveExtractionBudget {
  const ArchiveExtractionBudget({
    this.maxEntries = 50000,
    this.maxEntryBytes = 256 * 1024 * 1024,
    this.maxTotalBytes = 16 * 1024 * 1024 * 1024,
    this.maxCompressionRatio = 1024,
  });

  static const ArchiveExtractionBudget standard = ArchiveExtractionBudget();

  final int maxEntries;
  final int maxEntryBytes;
  final int maxTotalBytes;
  final int maxCompressionRatio;
}

void ensureArchiveExtractionBudget(
  Archive archive, {
  ArchiveExtractionBudget budget = ArchiveExtractionBudget.standard,
}) {
  if (archive.files.length > budget.maxEntries) {
    throw const ArchiveExtractionLimitException(
      ArchiveExtractionLimit.tooManyEntries,
    );
  }
  var totalBytes = 0;
  for (final ArchiveFile file in archive.files) {
    if (!file.isFile) continue;
    final int uncompressed = file.size;
    if (uncompressed < 0 || uncompressed > budget.maxEntryBytes) {
      throw const ArchiveExtractionLimitException(
        ArchiveExtractionLimit.entryTooLarge,
      );
    }
    totalBytes += uncompressed;
    if (totalBytes > budget.maxTotalBytes) {
      throw const ArchiveExtractionLimitException(
        ArchiveExtractionLimit.totalTooLarge,
      );
    }
    final int compressed = file.isCompressed
        ? (file.rawContent?.length ?? 0)
        : uncompressed;
    if (uncompressed > 0 &&
        (compressed <= 0 ||
            uncompressed > compressed * budget.maxCompressionRatio)) {
      throw const ArchiveExtractionLimitException(
        ArchiveExtractionLimit.suspiciousRatio,
      );
    }
  }
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
    final String normalized = p.posix
        .normalize(file.name.replaceAll('\\', '/'))
        .toLowerCase();
    if (normalized == suffix || normalized.endsWith('/$suffix')) {
      return file;
    }
  }
  return null;
}

/// 依路徑後綴選讀單一封存項目（例如 recovery.json）。
Uint8List? readZipEntry(Archive archive, {required String pathSuffix}) {
  return findZipEntry(archive, pathSuffix: pathSuffix)?.readBytes();
}

/// 讀取 manifest.json.enc，否則取第一篇 .md.enc 作為加密樣本。
Uint8List? readEncryptedSampleBytes(Archive archive) {
  final Uint8List? manifest = readZipEntry(
    archive,
    pathSuffix: 'manifest.json.enc',
  );
  if (manifest != null) {
    return manifest;
  }
  for (final ArchiveFile file in archive.files) {
    if (!file.isFile) {
      continue;
    }
    final String normalized = p.posix
        .normalize(file.name.replaceAll('\\', '/'))
        .toLowerCase();
    if (normalized.endsWith('.md.enc')) {
      return file.readBytes();
    }
  }
  return null;
}

/// 以 OS 層複製檔案，避免 readAsBytes 整包進記憶體。
Future<void> copyFileToPath(
  File source,
  String destinationPath, {
  BackupTaskProgressListener? onProgress,
  BackupTaskPhase phase = BackupTaskPhase.copyingBackup,
}) async {
  await File(destinationPath).parent.create(recursive: true);
  if (onProgress == null) {
    await source.copy(destinationPath);
    return;
  }

  final int totalBytes = await source.length();
  onProgress(BackupTaskProgress(phase: phase));
  final IOSink sink = File(destinationPath).openWrite();
  try {
    await for (final List<int> chunk in reportByteStreamProgress(
      source.openRead(),
      totalBytes: totalBytes,
      phase: phase,
      onProgress: onProgress,
    )) {
      sink.add(chunk);
    }
    await sink.flush();
  } finally {
    await sink.close();
  }
}

/// 驗證路徑後，將 [zip] 串流解壓至 [targetDirectory]。
Future<void> extractArchiveToDirectory({
  required OpenedZipArchive zip,
  required Directory targetDirectory,
  BackupTaskProgressListener? onProgress,
  ArchiveExtractionBudget budget = ArchiveExtractionBudget.standard,
}) async {
  ensureArchiveExtractionBudget(zip.archive, budget: budget);
  final List<ArchiveFile> files = zip.archive.files;
  final int total = files.length;
  for (var index = 0; index < files.length; index++) {
    final ArchiveFile archiveFile = files[index];
    if (total > 0) {
      onProgress?.call(
        BackupTaskProgress(
          phase: BackupTaskPhase.restoringBackup,
          fraction: ((index + 1) / total).clamp(0.0, 1.0),
        ),
      );
    }
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
