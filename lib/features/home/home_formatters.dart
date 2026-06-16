import '../../l10n/l10n.dart';
import '../../shared/presentation/display_format.dart';

bool _isEnglish(AppLocalizations l10n) => l10n.localeName.startsWith('en');

String homeTagRowEntryCount(AppLocalizations l10n, int count) {
  return l10n.homeTagRowEntryCount(
    DisplayFormat.formatCountUnit(count, _isEnglish(l10n) ? 'entries' : '篇'),
  );
}

String homeTagRemovedFromEntries(
  AppLocalizations l10n,
  int entryCount,
  String label,
) {
  return l10n.homeTagRemovedFromEntries(
    DisplayFormat.formatCountUnit(
      entryCount,
      _isEnglish(l10n) ? 'entries' : '篇',
    ),
    label,
  );
}

String homeHtmlExportSelectionSummary(
  AppLocalizations l10n,
  int entryCount,
  int imageCount,
) {
  return l10n.homeHtmlExportSelectionSummary(
    DisplayFormat.formatCountUnit(
      entryCount,
      _isEnglish(l10n) ? 'entries' : '篇',
    ),
    DisplayFormat.formatCountUnit(
      imageCount,
      _isEnglish(l10n) ? 'images' : '張',
    ),
  );
}

String homeOverviewAttachmentCount(AppLocalizations l10n, int count) {
  return l10n.homeOverviewAttachmentCount(
    DisplayFormat.formatCountUnit(
      count,
      _isEnglish(l10n) ? 'attachments' : '個附件',
    ),
  );
}

String homeOverviewLongestStreak(AppLocalizations l10n, int days) {
  return l10n.homeOverviewLongestStreak(
    DisplayFormat.formatCountUnit(days, _isEnglish(l10n) ? 'days' : '天'),
  );
}

String homeOverviewWritingDaysRatio(
  AppLocalizations l10n,
  int activeDays,
  int totalDays,
) {
  return DisplayFormat.formatRatio(
    activeDays,
    totalDays,
    _isEnglish(l10n) ? 'days' : '天',
  );
}

String homeOverviewEntryStats(
  AppLocalizations l10n,
  int entries,
  int characters,
) {
  return l10n.homeOverviewEntryStats(
    DisplayFormat.formatCountUnit(entries, _isEnglish(l10n) ? 'entries' : '篇'),
    DisplayFormat.formatCountUnit(
      characters,
      _isEnglish(l10n) ? 'chars' : '字',
    ),
  );
}

String homeOverviewMostEntriesInSingleDay(AppLocalizations l10n, int count) {
  return l10n.homeOverviewMostEntriesInSingleDay(
    DisplayFormat.formatCountUnit(count, _isEnglish(l10n) ? 'entries' : '篇'),
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
