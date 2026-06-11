import '../../infrastructure/database/index_database.dart';
import '../../shared/presentation/display_format.dart';

/// 日記列表標題：優先標題，否則預覽內文。
String entryListHeadline(EntryIndexRecord entry) {
  final String trimmed = entry.title?.trim() ?? '';
  return trimmed.isNotEmpty ? trimmed : entry.previewText;
}

/// 回傳第一個非空標籤字串。
String firstNonemptyTag(List<String> tags) {
  for (final String tag in tags) {
    final String trimmed = tag.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return '';
}

String entryListTimeLabel(DateTime at) => DisplayFormat.formatTime24h(at);
