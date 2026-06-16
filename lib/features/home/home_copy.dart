import '../../shared/presentation/display_format.dart';
import '../../l10n/l10n.dart';

/// 首頁與概覽相關的繁體中文 UI 文案。
abstract final class HomeCopy {
  static AppLocalizations _l10n(BuildContext context) => context.l10n;

  static String unlockingTitle(BuildContext context) => _l10n(context).homeUnlockingTitle;
  static String retryVerification(BuildContext context) => _l10n(context).homeRetryVerification;
  static String goToSettings(BuildContext context) => _l10n(context).homeGoToSettings;

  static String navHome(BuildContext context) => _l10n(context).homeNavHome;
  static String navCalendar(BuildContext context) => _l10n(context).homeNavCalendar;
  static String navTags(BuildContext context) => _l10n(context).homeNavTags;
  static String navOverview(BuildContext context) => _l10n(context).homeNavOverview;

  static String tooltipNewEntry(BuildContext context) => _l10n(context).homeTooltipNewEntry;
  static String tooltipSettings(BuildContext context) => _l10n(context).homeTooltipSettings;
  static String tooltipExportHtml(BuildContext context) => _l10n(context).homeTooltipExportHtml;
  static String tooltipDelete(BuildContext context) => _l10n(context).homeTooltipDelete;
  static String tooltipAddTag(BuildContext context) => _l10n(context).homeTooltipAddTag;
  static String tooltipEditTag(BuildContext context) => _l10n(context).homeTooltipEditTag;
  static String tooltipDeleteTag(BuildContext context) => _l10n(context).homeTooltipDeleteTag;
  static String tooltipDeselectTag(BuildContext context) => _l10n(context).homeTooltipDeselectTag;

  static String selectionSelectAll(BuildContext context) => _l10n(context).homeSelectionSelectAll;
  static String selectionDeselectAll(BuildContext context) => _l10n(context).homeSelectionDeselectAll;
  static String selectionSelectDiary(BuildContext context) => _l10n(context).homeSelectionSelectDiary;

  static String selectionSelectedCount(BuildContext context, int count) =>
      _l10n(context).homeSelectionSelectedCount(count);

  static String searchHint(BuildContext context) => _l10n(context).homeSearchHint;
  static String emptyDiaryTitle(BuildContext context) => _l10n(context).homeEmptyDiaryTitle;
  static String emptyDiaryMessage(BuildContext context) => _l10n(context).homeEmptyDiaryMessage;
  static String noAnalysisTitle(BuildContext context) => _l10n(context).homeNoAnalysisTitle;
  static String noAnalysisMessage(BuildContext context) => _l10n(context).homeNoAnalysisMessage;
  static String exportRecapLabel(BuildContext context) => _l10n(context).homeExportRecapLabel;
  static String exportRecapAll(BuildContext context) => _l10n(context).homeExportRecapAll;
  static String exportRecapYear(BuildContext context) => _l10n(context).homeExportRecapYear;
  static String exportRecapMonth(BuildContext context) => _l10n(context).homeExportRecapMonth;
  static String popularTagsTitle(BuildContext context) => _l10n(context).homePopularTagsTitle;
  static String scopeTitle(BuildContext context) => _l10n(context).homeScopeTitle;
  static String scopeAllLabel(BuildContext context) => _l10n(context).homeScopeAllLabel;
  static String scopeYearLabel(BuildContext context) => _l10n(context).homeScopeYearLabel;
  static String scopeMonthLabel(BuildContext context) => _l10n(context).homeScopeMonthLabel;

  static String scopeEmptyDiary(BuildContext context) => _l10n(context).homeScopeEmptyDiary;
  static String scopeEmptyDiaryForTag(BuildContext context, String tag) =>
      _l10n(context).homeScopeEmptyDiaryForTag(tag);
  static String scopeEmptyTags(BuildContext context) => _l10n(context).homeScopeEmptyTags;
  static String unsavedDraftLabel(BuildContext context) => _l10n(context).homeUnsavedDraftLabel;

  static String htmlExportLargeTitle(BuildContext context) => _l10n(context).homeHtmlExportLargeTitle;
  static String htmlExportEmbeddedHint(BuildContext context) => _l10n(context).homeHtmlExportEmbeddedHint;
  static String htmlExportProceed(BuildContext context) => _l10n(context).homeHtmlExportProceed;

  static String htmlExportSelectionSummary(BuildContext context, int entryCount, int imageCount) {
    final AppLocalizations l10n = _l10n(context);
    return l10n.homeHtmlExportSelectionSummary(
      DisplayFormat.formatCountUnit(entryCount, l10n.localeName.startsWith('en') ? 'entries' : '篇'),
      DisplayFormat.formatCountUnit(imageCount, l10n.localeName.startsWith('en') ? 'images' : '張'),
    );
  }

  static String htmlExportImageSize(BuildContext context, String size) =>
      _l10n(context).homeHtmlExportImageSize(size);

  static String htmlExportEstimatedSize(BuildContext context, String size) =>
      _l10n(context).homeHtmlExportEstimatedSize(size);

  static String htmlExportSuccess(BuildContext context, String fileName) =>
      _l10n(context).homeHtmlExportSuccess(fileName);

  static String deleteTagTitle(BuildContext context) => _l10n(context).homeDeleteTagTitle;
  static String deleteTagConfirm(BuildContext context, String label) =>
      _l10n(context).homeDeleteTagConfirm(label);

  static String tagSearchHint(BuildContext context) => _l10n(context).homeTagSearchHint;
  static String noTagsTitle(BuildContext context) => _l10n(context).homeNoTagsTitle;
  static String noTagsMessage(BuildContext context) => _l10n(context).homeNoTagsMessage;
  static String tagListGuide(BuildContext context) => _l10n(context).homeTagListGuide;
  static String tagPreviewTitle(BuildContext context) => _l10n(context).homeTagPreviewTitle;
  static String tagDeleted(BuildContext context, String label) => _l10n(context).homeTagDeleted(label);
  static String tagRemovedFromEntries(BuildContext context, int entryCount, String label) {
    final AppLocalizations l10n = _l10n(context);
    return l10n.homeTagRemovedFromEntries(
      DisplayFormat.formatCountUnit(entryCount, l10n.localeName.startsWith('en') ? 'entries' : '篇'),
      label,
    );
  }

  static String tagIndexEmptyForTag(BuildContext context, String tag) =>
      _l10n(context).homeTagIndexEmptyForTag(tag);

  static String tagFilteredDiaryTitle(BuildContext context, String tagLabel) =>
      diarySectionTag(context, tagLabel);

  static String tagRowEntryCount(BuildContext context, int count) {
    final AppLocalizations l10n = _l10n(context);
    return l10n.homeTagRowEntryCount(
      DisplayFormat.formatCountUnit(count, l10n.localeName.startsWith('en') ? 'entries' : '篇'),
    );
  }

  static String tagRowTapHint(BuildContext context) => _l10n(context).homeTagRowTapHint;

  static String diarySectionTitleForDate(BuildContext context, String dateLabel) =>
      _l10n(context).homeDiarySectionTitleForDate(dateLabel);
  static String emptyDayMessage(BuildContext context, String dateLabel) =>
      _l10n(context).homeEmptyDayMessage(dateLabel);

  static String overviewDataTitle(BuildContext context) => _l10n(context).homeOverviewDataTitle;
  static String overviewScopeAll(BuildContext context) => _l10n(context).homeOverviewScopeAll;
  static String overviewScopeYear(BuildContext context, int year) =>
      _l10n(context).homeOverviewScopeYear(year);
  static String overviewScopeMonth(BuildContext context, int year, int month) =>
      _l10n(context).homeOverviewScopeMonth(year, month);

  static String overviewWritingDaysLabel(BuildContext context) =>
      _l10n(context).homeOverviewWritingDaysLabel;
  static String overviewAvgLengthLabel(BuildContext context) =>
      _l10n(context).homeOverviewAvgLengthLabel;
  static String overviewAttachmentsLabel(BuildContext context) =>
      _l10n(context).homeOverviewAttachmentsLabel;
  static String overviewAttachmentCount(BuildContext context, int count) {
    final AppLocalizations l10n = _l10n(context);
    return l10n.homeOverviewAttachmentCount(
      DisplayFormat.formatCountUnit(count, l10n.localeName.startsWith('en') ? 'attachments' : '個附件'),
    );
  }

  static String overviewLongestStreak(BuildContext context, int days) {
    final AppLocalizations l10n = _l10n(context);
    return l10n.homeOverviewLongestStreak(
      DisplayFormat.formatCountUnit(days, l10n.localeName.startsWith('en') ? 'days' : '天'),
    );
  }

  static String overviewEntryStats(BuildContext context, int entries, int characters) {
    final AppLocalizations l10n = _l10n(context);
    return l10n.homeOverviewEntryStats(
      DisplayFormat.formatCountUnit(entries, l10n.localeName.startsWith('en') ? 'entries' : '篇'),
      DisplayFormat.formatCountUnit(
        characters,
        l10n.localeName.startsWith('en') ? 'characters' : '字',
      ),
    );
  }

  static String diarySectionTag(BuildContext context, String tag) =>
      _l10n(context).homeDiarySectionTag(tag);
  static String diarySectionAll(BuildContext context) => _l10n(context).homeDiarySectionAll;
  static String diarySectionByYear(BuildContext context) => _l10n(context).homeDiarySectionByYear;
  static String diarySectionByMonth(BuildContext context) => _l10n(context).homeDiarySectionByMonth;
  static String diarySectionWithTag(BuildContext context, String baseTitle, String tag) =>
      _l10n(context).homeDiarySectionWithTag(baseTitle, tag);

  static const List<String> calendarWeekdayLabels = <String>[
    '日',
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
  ];
  static String calendarMonthFormatLabel(BuildContext context) =>
      _l10n(context).homeCalendarMonthFormatLabel;

  static String overviewAvgLengthValue(BuildContext context, int charactersPerEntry) =>
      _l10n(context).homeOverviewAvgLengthValue(charactersPerEntry);

  static String overviewAttachmentDetail(BuildContext context, int photos, int files) =>
      _l10n(context).homeOverviewAttachmentDetail(photos, files);

  static String overviewMostEntriesInSingleDay(BuildContext context, int count) {
    final AppLocalizations l10n = _l10n(context);
    return l10n.homeOverviewMostEntriesInSingleDay(
      DisplayFormat.formatCountUnit(count, l10n.localeName.startsWith('en') ? 'entries' : '篇'),
    );
  }
}
