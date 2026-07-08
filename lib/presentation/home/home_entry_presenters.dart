import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';

String entryListHeadline(EntryIndexRecord entry) {
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

String entryListTimeLabel(DateTime at) => DisplayFormat.formatTime24h(at);
