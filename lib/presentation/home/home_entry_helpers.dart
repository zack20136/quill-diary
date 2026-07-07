import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';

String entryListHeadline(EntryIndexRecord entry) {
  final String trimmed = entry.title?.trim() ?? '';
  return trimmed.isNotEmpty ? trimmed : entry.previewText;
}

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
