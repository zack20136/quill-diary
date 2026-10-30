import 'package:quill_diary/domain/diary/diary_entry_summary.dart';

int compareEntriesNewestFirst(DiaryEntrySummary a, DiaryEntrySummary b) {
  final int byDate = b.date.value.compareTo(a.date.value);
  if (byDate != 0) return byDate;
  final int byCreated = b.createdAt.compareTo(a.createdAt);
  if (byCreated != 0) return byCreated;
  return b.updatedAt.compareTo(a.updatedAt);
}
