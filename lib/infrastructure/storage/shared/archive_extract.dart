import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/shared/zip_structure.dart';

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
    this.maxMetadataBytes = 64 * 1024 * 1024,
  });

  static const ArchiveExtractionBudget standard = ArchiveExtractionBudget();

  final int maxEntries;
  final int maxEntryBytes;
  final int maxTotalBytes;
  final int maxCompressionRatio;
  final int maxMetadataBytes;
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
    try {
      await archive.clear();
    } finally {
      await _input.close();
    }
  }
}

Future<OpenedZipArchive> openZipArchive(
  File file, {
  ArchiveExtractionBudget budget = ArchiveExtractionBudget.standard,
}) async {
  try {
    validateZipStructure(
      file,
      maxEntries: budget.maxEntries,
      maxEntryBytes: budget.maxEntryBytes,
      maxTotalBytes: budget.maxTotalBytes,
      maxCompressionRatio: budget.maxCompressionRatio,
      maxMetadataBytes: budget.maxMetadataBytes,
    );
  } on ZipStructureLimitException catch (error) {
    throw ArchiveExtractionLimitException(
      ArchiveExtractionLimit.values.byName(error.limit),
    );
  }
  final InputFileStream input = InputFileStream(file.path);
  try {
    final Archive archive = ZipDecoder().decodeStream(
      input,
      verify: true,
      throwOnError: true,
    );
    return OpenedZipArchive._(input, archive);
  } on Object {
    await input.close();
    rethrow;
  }
}

Uint8List? readZipEntry(Archive archive, {required String relativePath}) {
  for (final ArchiveFile file in archive.files) {
    if (!file.isFile || safeArchiveRelativePath(file.name) != relativePath) {
      continue;
    }
    return _readEntryBytes(
      file,
      maxBytes: relativePath == 'recovery.json'
          ? 65536
          : ArchiveExtractionBudget.standard.maxEntryBytes,
    );
  }
  return null;
}

Uint8List _readEntryBytes(ArchiveFile file, {required int maxBytes}) {
  if (file.size > maxBytes) {
    throw const ArchiveExtractionLimitException(
      ArchiveExtractionLimit.entryTooLarge,
    );
  }
  final memory = OutputMemoryStream();
  final output = _BudgetedArchiveOutput(
    memory,
    file,
    ArchiveExtractionBudget(maxEntryBytes: maxBytes),
    (_) {},
  );
  file.writeContent(output);
  if (output.length != file.size) {
    throw const FormatException('ZIP 實際輸出大小不符');
  }
  return memory.getBytes();
}

/// 讀取 manifest.json.enc，否則取第一篇 .md.enc 作為加密樣本。
Uint8List? readEncryptedSampleBytes(Archive archive) {
  final Uint8List? manifest = readZipEntry(
    archive,
    relativePath: 'manifest.json.enc',
  );
  if (manifest != null) {
    return manifest;
  }
  for (final ArchiveFile file in archive.files) {
    if (!file.isFile) {
      continue;
    }
    final String path = safeArchiveRelativePath(file.name);
    if (path.startsWith('entries/') && path.endsWith('.md.enc')) {
      return _readEntryBytes(
        file,
        maxBytes: ArchiveExtractionBudget.standard.maxEntryBytes,
      );
    }
  }
  return null;
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
  var writtenTotal = 0;
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
      final output = _BudgetedArchiveOutput(
        OutputFileStream(outputPath),
        archiveFile,
        budget,
        (count) {
          writtenTotal += count;
          if (writtenTotal > budget.maxTotalBytes) {
            throw const ArchiveExtractionLimitException(
              ArchiveExtractionLimit.totalTooLarge,
            );
          }
        },
      );
      try {
        archiveFile.writeContent(output);
        if (output.length != archiveFile.size) {
          throw const FormatException('ZIP 實際輸出大小不符');
        }
      } on Object {
        try {
          await output.close();
        } on Object {
          // 保留首次解壓或寫入錯誤。
        }
        rethrow;
      }
      await output.close();
    } else {
      await Directory(outputPath).create(recursive: true);
    }
  }
}

final class _BudgetedArchiveOutput extends OutputStream {
  _BudgetedArchiveOutput(this.output, this.entry, this.budget, this.onWrite)
    : compressedBytes = entry.isCompressed
          ? (entry.rawContent?.length ?? 0)
          : entry.size,
      super(byteOrder: output.byteOrder);
  final OutputStream output;
  final ArchiveFile entry;
  final ArchiveExtractionBudget budget;
  final void Function(int) onWrite;
  final int compressedBytes;
  var count = 0;

  void _count(int size) {
    count += size;
    if (size < 0 || count > entry.size || count > budget.maxEntryBytes) {
      throw const ArchiveExtractionLimitException(
        ArchiveExtractionLimit.entryTooLarge,
      );
    }
    if (count > 0 &&
        (compressedBytes <= 0 ||
            count > compressedBytes * budget.maxCompressionRatio)) {
      throw const ArchiveExtractionLimitException(
        ArchiveExtractionLimit.suspiciousRatio,
      );
    }
    onWrite(size);
  }

  @override
  int get length => output.length;
  @override
  bool get isOpen => output.isOpen;
  @override
  void writeByte(int value) {
    _count(1);
    output.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _count(length ?? bytes.length);
    output.writeBytes(bytes, length: length);
  }

  @override
  void writeRange(Uint8List bytes, int start, int end) {
    _count(end - start);
    output.writeRange(bytes, start, end);
  }

  @override
  void writeStream(InputStream stream) {
    final position = stream.position;
    final buffer = Uint8List(65536);
    try {
      while (!stream.isEOS) {
        final read = stream.readInto(buffer, 0, buffer.length);
        if (read == 0) break;
        writeRange(buffer, 0, read);
      }
    } finally {
      stream.position = position;
    }
  }

  @override
  void flush() => output.flush();
  @override
  Future<void> close() => output.close();
  @override
  void clear() => throw UnsupportedError('解壓輸出不可回復');
  @override
  Uint8List subset(int start, [int? end]) => throw UnsupportedError('解壓輸出不可回讀');
}
