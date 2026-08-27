import '../../../domain/diary/diary_entry.dart';
import '../../../domain/shared/value_objects.dart';
import 'portable_io_types.dart';

/// 匯入預覽清單中的單篇摘要（選取用暫時索引，不是 vault entry.id）。
class PortableImportPreviewEntry {
  const PortableImportPreviewEntry({
    required this.previewIndex,
    required this.date,
    required this.title,
    required this.displayTitle,
    required this.likelyDuplicate,
    required this.attachmentCount,
    required this.skippedAttachments,
  });

  final int previewIndex;
  final DateOnly date;
  final String? title;
  final String displayTitle;
  final bool likelyDuplicate;
  final int attachmentCount;
  final int skippedAttachments;
}

/// 解析完成、尚未寫入時的匯入預覽。
class PortableImportPreview {
  const PortableImportPreview({
    required this.entries,
    required this.skippedFiles,
    required this.skippedAttachments,
  });

  final List<PortableImportPreviewEntry> entries;
  final int skippedFiles;
  final int skippedAttachments;

  int get entryCount => entries.length;

  int get likelyDuplicateCount => entries
      .where((PortableImportPreviewEntry e) => e.likelyDuplicate)
      .length;

  PortableImportPreview forSelected(Set<int> selectedPreviewIndices) {
    return PortableImportPreview(
      entries: entries
          .where(
            (PortableImportPreviewEntry e) =>
                selectedPreviewIndices.contains(e.previewIndex),
          )
          .toList(growable: false),
      skippedFiles: skippedFiles,
      skippedAttachments: skippedAttachments,
    );
  }
}

/// 使用者對匯入預覽的確認結果。
class PortableImportConfirmResult {
  const PortableImportConfirmResult({
    required this.confirmed,
    required this.selectedPreviewIndices,
  });

  final bool confirmed;
  final Set<int> selectedPreviewIndices;
}

/// 解析階段結果（含可寫入的 entries 與預覽摘要）。
class AnalyzedPortableImport {
  AnalyzedPortableImport({
    required this.parsedEntries,
    required this.preview,
    this.failureCode,
  });

  final List<ParsedImportEntry> parsedEntries;
  final PortableImportPreview preview;
  final String? failureCode;

  bool get hasImportableEntries => parsedEntries.isNotEmpty;
}

/// 空標題時用正文前綴作為顯示／重複比對鍵。
String portableImportDisplayTitle(DiaryEntry entry, {int maxChars = 40}) {
  final String? title = entry.normalizedTitle;
  if (title != null) {
    return title;
  }
  final String body = entry.markdownBody.trim();
  if (body.isEmpty) {
    return '';
  }
  final String firstLine = body.split(RegExp(r'\r?\n')).first.trim();
  if (firstLine.length <= maxChars) {
    return firstLine;
  }
  return '${firstLine.substring(0, maxChars)}…';
}

String portableImportDuplicateKey(DiaryEntry entry) {
  return '${entry.date.value}\u0000${portableImportDisplayTitle(entry)}';
}
