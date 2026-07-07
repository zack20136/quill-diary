import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';

String homeTagsSectionTitle(AppLocalizations l10n, int count) {
  return l10n.homeTagsSectionTitle(
    DisplayFormat.formatCountUnit(count, l10n.commonUnitTags),
  );
}

String homeTagRowEntryCount(AppLocalizations l10n, int count) {
  return l10n.homeTagRowEntryCount(
    DisplayFormat.formatCountUnit(count, l10n.commonUnitEntries),
  );
}

String homeTagRemovedFromEntries(
  AppLocalizations l10n,
  int entryCount,
  String label,
) {
  return l10n.homeTagRemovedFromEntries(
    DisplayFormat.formatCountUnit(entryCount, l10n.commonUnitEntries),
    label,
  );
}

String homeHtmlExportSelectionSummary(
  AppLocalizations l10n,
  int entryCount,
  int imageCount,
) {
  return l10n.homeHtmlExportSelectionSummary(
    DisplayFormat.formatCountUnit(entryCount, l10n.commonUnitEntries),
    DisplayFormat.formatCountUnit(imageCount, l10n.commonUnitImages),
  );
}

String homeOverviewAttachmentCount(AppLocalizations l10n, int count) {
  return l10n.homeOverviewAttachmentCount(
    DisplayFormat.formatCountUnit(count, l10n.commonUnitAttachments),
  );
}

String homeOverviewLongestStreak(AppLocalizations l10n, int days) {
  return l10n.homeOverviewLongestStreak(
    DisplayFormat.formatCountUnit(days, l10n.commonUnitDays),
  );
}

String homeOverviewWritingDaysRatio(
  AppLocalizations l10n,
  int activeDays,
  int totalDays,
) {
  return DisplayFormat.formatRatio(activeDays, totalDays, l10n.commonUnitDays);
}

String homeOverviewEntryStats(
  AppLocalizations l10n,
  int entries,
  int characters,
) {
  return l10n.homeOverviewEntryStats(
    DisplayFormat.formatCountUnit(entries, l10n.commonUnitEntries),
    DisplayFormat.formatCountUnit(characters, l10n.commonUnitCharacters),
  );
}

String homeOverviewMostEntriesInSingleDay(AppLocalizations l10n, int count) {
  return l10n.homeOverviewMostEntriesInSingleDay(
    DisplayFormat.formatCountUnit(count, l10n.commonUnitEntries),
  );
}

List<String> calendarWeekdayLabels(AppLocalizations l10n) {
  return <String>[
    l10n.homeCalendarWeekdaySun,
    l10n.homeCalendarWeekdayMon,
    l10n.homeCalendarWeekdayTue,
    l10n.homeCalendarWeekdayWed,
    l10n.homeCalendarWeekdayThu,
    l10n.homeCalendarWeekdayFri,
    l10n.homeCalendarWeekdaySat,
  ];
}
