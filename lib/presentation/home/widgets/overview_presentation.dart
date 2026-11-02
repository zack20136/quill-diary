import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/l10n/l10n.dart';

String overviewMetricRangeCaption(
  BuildContext context,
  OverviewScope scope,
  DateTime focusedMonth,
  int focusedYear, {
  String? selectedTag,
}) {
  final String base = switch (scope) {
    OverviewScope.all => context.l10n.homeOverviewScopeAll,
    OverviewScope.year => context.l10n.homeOverviewScopeYear(focusedYear),
    OverviewScope.month => context.l10n.homeOverviewScopeMonth(
      focusedMonth.year,
      focusedMonth.month,
    ),
  };
  if (selectedTag == null || selectedTag.isEmpty) return base;
  return context.l10n.homeDiarySectionWithTag(base, selectedTag);
}

List<DiaryEntrySummary> overviewEntriesForTag(
  Iterable<DiaryEntrySummary> entries,
  String? selectedTag,
) {
  if (selectedTag == null || selectedTag.isEmpty) {
    return entries.toList(growable: false);
  }
  final String normalizedTag = normalizeText(selectedTag);
  return entries
      .where(
        (DiaryEntrySummary entry) =>
            entry.tags.any((String tag) => normalizeText(tag) == normalizedTag),
      )
      .toList(growable: false);
}

int overviewScopeTotalDays({
  required OverviewScope scope,
  required DateTime focusedMonth,
  required int focusedYear,
  required List<DiaryEntrySummary> entries,
}) {
  switch (scope) {
    case OverviewScope.month:
      return DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    case OverviewScope.year:
      final DateTime start = DateTime(focusedYear, 1, 1);
      final DateTime end = DateTime(focusedYear + 1, 1, 1);
      return end.difference(start).inDays;
    case OverviewScope.all:
      if (entries.isEmpty) {
        return 0;
      }
      final List<DateTime> dates =
          entries
              .map((DiaryEntrySummary item) => item.date.toDateTime())
              .toList()
            ..sort();
      return dates.last.difference(dates.first).inDays + 1;
  }
}

String overviewScopedDiarySectionTitle(
  BuildContext context,
  OverviewScope scope, {
  String? selectedTag,
}) {
  final String base = switch (scope) {
    OverviewScope.all => context.l10n.homeDiarySectionAll,
    OverviewScope.year => context.l10n.homeDiarySectionByYear,
    OverviewScope.month => context.l10n.homeDiarySectionByMonth,
  };
  if (selectedTag == null || selectedTag.isEmpty) {
    return base;
  }
  return context.l10n.homeDiarySectionWithTag(base, selectedTag);
}
