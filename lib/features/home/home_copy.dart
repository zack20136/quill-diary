import '../../shared/presentation/display_format.dart';

/// 首頁與概覽相關的繁體中文 UI 文案。
abstract final class HomeCopy {
  static const String unlockingTitle = '正在解鎖';
  static const String retryVerification = '重新驗證';
  static const String goToSettings = '前往設定';

  static const String navHome = '首頁';
  static const String navCalendar = '日曆';
  static const String navTags = '標籤';
  static const String navOverview = '總覽';

  static const String tooltipNewEntry = '新增日記';
  static const String tooltipSettings = '設定與備份';
  static const String tooltipExportHtml = '匯出 HTML';
  static const String tooltipDelete = '刪除';
  static const String tooltipAddTag = '新增標籤';
  static const String tooltipEditTag = '編輯標籤';
  static const String tooltipDeleteTag = '刪除標籤';
  static const String tooltipDeselectTag = '取消選取';

  static const String selectionSelectAll = '全選';
  static const String selectionDeselectAll = '取消全選';
  static const String selectionSelectDiary = '選取日記';

  static String selectionSelectedCount(int count) => '已選 $count 項';

  static const String searchHint = '搜尋標題、內文或標籤';
  static const String emptyDiaryTitle = '目前沒有日記';
  static const String emptyDiaryMessage = '建立第一篇日記後，就會在這裡看到你的首頁列表。';
  static const String noAnalysisTitle = '尚無可分析內容';
  static const String noAnalysisMessage =
      '寫下一篇後，就可以在這裡看到統計、標籤與範圍內的日記。';
  static const String exportRecapLabel = '匯出回顧';
  static const String exportRecapAll = '匯出總回顧';
  static const String exportRecapYear = '匯出年度回顧';
  static const String exportRecapMonth = '匯出月份回顧';
  static const String popularTagsTitle = '熱門標籤';
  static const String scopeTitle = '範圍';
  static const String scopeAllLabel = '全部';
  static const String scopeYearLabel = '年';
  static const String scopeMonthLabel = '月';

  static const String scopeEmptyDiary = '此範圍內沒有符合的日記。';
  static String scopeEmptyDiaryForTag(String tag) => '此範圍內沒有套用「$tag」的日記。';
  static const String scopeEmptyTags = '此範圍內沒有標籤。';
  static const String unsavedDraftLabel = '未儲存';

  static const String htmlExportLargeTitle = 'HTML 檔案可能很大';
  static const String htmlExportEmbeddedHint =
      '圖片會內嵌在單一 HTML 內，檔案可能較慢開啟或不易分享。';
  static const String htmlExportProceed = '仍要匯出';

  static String htmlExportSelectionSummary(int entryCount, int imageCount) =>
      '選取 ${DisplayFormat.formatCountUnit(entryCount, '篇')}日記，'
      '包含 ${DisplayFormat.formatCountUnit(imageCount, '張')}圖片。';

  static String htmlExportImageSize(String size) => '圖片原始大小：約 $size';
  static String htmlExportEstimatedSize(String size) => 'HTML 估算大小：約 $size';

  static String htmlExportSuccess(String fileName) => '已匯出 HTML：$fileName';

  static const String deleteTagTitle = '刪除標籤';
  static String deleteTagConfirm(String label) => '確定要從所有日記移除「$label」嗎？';

  static const String tagSearchHint = '搜尋標籤…';
  static const String noTagsTitle = '尚未有標籤';
  static const String noTagsMessage =
      '可先建立標籤或使用預設標籤；即使尚未套用到日記也會保留在清單中。';
  static const String tagListGuide =
      '請從標籤清單中點選一列：此區會依索引篩選出套用該標籤的日記摘要（再點同一列可取消選取）。';
  static const String tagPreviewTitle = '選取標籤以預覽日記';
  static String tagDeleted(String label) => '「$label」已刪除';
  static String tagRemovedFromEntries(int entryCount, String label) =>
      '已從 ${DisplayFormat.formatCountUnit(entryCount, '篇')}日記移除「$label」';
  static String tagIndexEmptyForTag(String tag) => '目前索引中找不到套用「$tag」的項目。';

  static String tagFilteredDiaryTitle(String tagLabel, int count) =>
      '日記 · 「$tagLabel」 · ${DisplayFormat.formatCountUnit(count, '篇')}';

  static String tagRowSummary(int count, bool hasCustomAccent) =>
      '${DisplayFormat.formatCountUnit(count, '篇')}日記 · '
      '${hasCustomAccent ? '已設定顯示色' : '預設底色'} · 輕觸列預覽';

  static String diarySectionTitleForDate(String dateLabel) => '日記 · $dateLabel';
  static String emptyDayMessage(String dateLabel) => '「$dateLabel」這一天目前沒有日記。';

  static const String overviewDataTitle = '資料概覽';
  static const String overviewScopeAll = '目前範圍 · 全部日記';
  static String overviewScopeYear(int year) => '目前範圍 · $year年';
  static String overviewScopeMonth(int year, int month) =>
      '目前範圍 · $year年$month月';

  static const String overviewWritingDaysLabel = '撰寫天數';
  static const String overviewAvgLengthLabel = '平均篇幅';
  static const String overviewAttachmentsLabel = '附件總數';
  static String overviewAttachmentCount(int count) =>
      DisplayFormat.formatCountUnit(count, '個附件');
  static String overviewLongestStreak(int days) =>
      '連續最長 ${DisplayFormat.formatCountUnit(days, '天')}';
  static String overviewEntryStats(int entries, int characters) =>
      '共 ${DisplayFormat.formatCountUnit(entries, '篇')} · '
      '累計 ${DisplayFormat.formatCountUnit(characters, '字')}';

  static String diarySectionTag(String tag) => '日記 · $tag';
  static const String diarySectionAll = '日記 · 全部';
  static const String diarySectionByYear = '日記 · 依年';
  static const String diarySectionByMonth = '日記 · 依月';
}
