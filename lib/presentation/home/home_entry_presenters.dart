import 'package:quill_diary/domain/diary/diary_entry_summary.dart';

String entryListHeadline(DiaryEntrySummary entry) {
  final String trimmedTitle = entry.title?.trim() ?? '';
  return trimmedTitle.isNotEmpty ? trimmedTitle : entry.previewText;
}

String firstNonemptyTag(List<String> tags) {
  for (final String tag in tags) {
    final String trimmedTag = tag.trim();
    if (trimmedTag.isNotEmpty) {
      return trimmedTag;
    }
  }
  return '';
}
