// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Quill Diary';

  @override
  String get languageNameZhTw => '繁體中文';

  @override
  String get languageNameEn => 'English';

  @override
  String get commonActionCancel => '取消';

  @override
  String get commonActionDelete => '刪除';

  @override
  String get commonActionApply => '套用';

  @override
  String get commonActionClose => '關閉';

  @override
  String get commonReadFailureTitle => '讀取失敗';

  @override
  String get commonConfirmDeleteTitle => '確認刪除';

  @override
  String get commonNoTagSearchResults => '沒有符合的標籤';

  @override
  String get commonCloseTooltip => '關閉';

  @override
  String get commonClearSearchTooltip => '清除搜尋';

  @override
  String commonConfirmDeleteEntries(int count) {
    return '確定要刪除 $count 篇日記嗎？刪除後無法復原。';
  }

  @override
  String get tagAddTitle => '新增標籤';

  @override
  String get tagEditTitle => '編輯標籤';

  @override
  String get tagSaveButton => '儲存';

  @override
  String get tagNameHint => '標籤名稱';

  @override
  String get tagNameRequiredMessage => '請輸入標籤名稱';

  @override
  String get tagDeleteLabel => '刪除標籤';

  @override
  String get tagUnnamedPreview => '未命名標籤';

  @override
  String get tagDefaultColorLabel => '預設色';

  @override
  String get tagHueLabel => '色相';

  @override
  String get tagPreviewLabel => '預覽';

  @override
  String tagSaveFailure(String message) {
    return '儲存標籤失敗：$message';
  }

  @override
  String tagDeleteFailure(String message) {
    return '刪除標籤失敗：$message';
  }

  @override
  String get personalizationNavButtonLabel => '個人化';

  @override
  String get personalizationPageTitle => '個人化';

  @override
  String get personalizationLoadErrorMessage => '無法載入個人化設定。';

  @override
  String get personalizationTypographyResetButton => '還原預設';

  @override
  String get personalizationTypographyResetConfirmTitle => '還原日記排版預設？';

  @override
  String get personalizationTypographyResetConfirmBody =>
      '這會把目前的標題、內文字體大小、行距與段落間距都還原成預設值。';

  @override
  String get personalizationTypographyResetConfirmAction => '還原預設';

  @override
  String get personalizationTypographyResetSuccess => '已還原日記排版預設。';

  @override
  String get personalizationLanguageSectionTitle => '語言';

  @override
  String get personalizationLanguageSectionDescription => '選擇介面顯示語言。';

  @override
  String get personalizationLanguageComingSoonHint => '部分英文翻譯仍在補完中。';

  @override
  String get personalizationSessionTimeoutSectionTitle => '自動鎖定';

  @override
  String get personalizationSessionTimeoutSectionDescription =>
      'App 切到背景一段時間後，會自動要求重新驗證。';

  @override
  String get personalizationSessionTimeoutUnitLabel => '分鐘';

  @override
  String get personalizationImageCompressSectionTitle => '圖片品質';

  @override
  String get personalizationImageCompressSectionDescription =>
      '調整編輯器插入圖片時的壓縮預設。';

  @override
  String get personalizationImageCompressOriginalLabel => '原圖';

  @override
  String get personalizationImageCompressStandardLabel => '標準';

  @override
  String get personalizationImageCompressHighLabel => '高畫質';

  @override
  String get personalizationAppearanceSectionTitle => '主題顏色';

  @override
  String get personalizationAppearanceSectionDescription =>
      '選擇 App 使用的淺色、深色或跟隨系統外觀。';

  @override
  String get personalizationAppearanceSystemLabel => '跟隨系統';

  @override
  String get personalizationAppearanceLightLabel => '淺色';

  @override
  String get personalizationAppearanceDarkLabel => '深色';

  @override
  String get personalizationTypographySectionTitle => '日記排版';

  @override
  String get personalizationTypographySectionDescription =>
      '調整日記編輯與預覽時的字體大小、行距與段落間距。';

  @override
  String get personalizationTitleFontSizeLabel => '標題字體大小';

  @override
  String get personalizationTitleLineHeightLabel => '標題行距';

  @override
  String get personalizationBodyFontSizeLabel => '內文字體大小';

  @override
  String get personalizationBodyLineHeightLabel => '內文行距';

  @override
  String get personalizationBodyParagraphSpacingLabel => '內文段落間距';

  @override
  String get settingsPageTitle => '設定';

  @override
  String get settingsProgressDefault => '正在處理，請稍候…';

  @override
  String get personalizationImageCompressOriginalDescription =>
      '不壓縮，保留原始解析度與檔案大小。適合需要最高畫質、可接受較大日記庫時使用。';

  @override
  String get personalizationImageCompressStandardDescription =>
      '長邊縮至 1280 px、JPEG 品質 70。在清晰度與儲存空間之間取得平衡（預設）。';

  @override
  String get personalizationImageCompressHighDescription =>
      '長邊縮至 1920 px、JPEG 品質 85。檔案較大，但細節保留較多。';

  @override
  String personalizationFontSizeValue(String size) {
    return '$size 點';
  }

  @override
  String personalizationLineHeightValue(String height) {
    return '$height 倍';
  }

  @override
  String personalizationParagraphSpacingValue(String spacing) {
    return '$spacing 像素';
  }

  @override
  String get personalizationTypographyPreviewTitleParagraph1 =>
      '今日的小確幸，陽光剛好落在書桌上。值得記住的一刻，先寫下來再說。';

  @override
  String get personalizationTypographyPreviewBodyParagraph1 =>
      '記錄下此刻的心情，讓文字替記憶保溫。記錄下此刻的心情，讓文字替記憶保溫。';

  @override
  String get personalizationTypographyPreviewBodyParagraph2 =>
      '段落之間的間距，也會反映在預覽裡。段落之間的間距，也會反映在預覽裡。';

  @override
  String get sessionBlockedLockedTitle => '日記庫已鎖定';

  @override
  String get sessionBlockedRecoveryRequiredTitle => '需要復原金鑰';

  @override
  String get sessionBlockedFatalErrorTitle => '無法啟動';

  @override
  String get sessionBlockedDefaultTitle => '請稍候';

  @override
  String get sessionBlockedLockedSubtitle => '請完成驗證以繼續';

  @override
  String get sessionBlockedRecoveryRequiredSubtitle => '請輸入復原金鑰解鎖';

  @override
  String get sessionBlockedFatalErrorSubtitle => '請檢查設定或重新啟動應用程式';

  @override
  String get editorPageTitle => '編輯日記';

  @override
  String get editorTitleHint => '輸入標題';

  @override
  String get editorTitleRequiredError => '請輸入標題';

  @override
  String get editorBodyHint => '在這裡輸入內容…';

  @override
  String get editorBodyEmptyPreview => '尚未輸入內容';

  @override
  String get editorNeedsRecoveryKeyMessage => '請先建立復原金鑰，才能開始建立或編輯日記。';

  @override
  String get editorSessionLockedFallback => '請先重新解鎖日記庫後再繼續。';

  @override
  String get editorSaveNeedsTitleMessage => '請輸入標題才能儲存';

  @override
  String get editorUnsavedDraftLabel => '未儲存';

  @override
  String get editorConfirmDeleteTitle => '確認刪除';

  @override
  String get editorConfirmDeleteBody => '確定要刪除這篇日記嗎？刪除後無法復原。';

  @override
  String get editorTagsStudioTitle => '標籤';

  @override
  String get editorTagsStudioGuide => '右上角可建立新標籤；下方為文庫標籤，輕觸加入。';

  @override
  String get editorTagsStudioEmptyChosen => '尚未套用任何標籤';

  @override
  String get editorTagsStudioAddButton => '加入';

  @override
  String get editorPreviewUnavailable => '無法預覽';

  @override
  String get editorTagSearchHint => '搜尋標籤…';

  @override
  String get editorTagLibraryHint => '文庫裡的標籤 · 輕觸加入';

  @override
  String get editorTagPoolEmpty => '文庫裡暫時沒有其他可用標籤，或已全部加入目前清單';

  @override
  String get editorTagAddTooltip => '新增標籤';

  @override
  String get editorTooltipCancel => '取消';

  @override
  String get editorTooltipSave => '儲存';

  @override
  String get editorTooltipSaveNeedsTitle => '請先輸入標題';

  @override
  String get editorTooltipDate => '日期';

  @override
  String get editorTooltipTime => '時間';

  @override
  String get editorTooltipEditTags => '編輯標籤';

  @override
  String get editorTooltipUploadImages => '上傳圖片（可一次選多張）';

  @override
  String get editorTooltipAddAttachment => '新增附件';

  @override
  String get editorTooltipDelete => '刪除';

  @override
  String get editorTooltipEdit => '編輯';

  @override
  String get editorRestoreDraftTitle => '發現未完成的草稿';

  @override
  String get editorRestoreDraftDecline => '不使用';

  @override
  String get editorRestoreDraftAccept => '還原草稿';

  @override
  String get editorUntitledDraft => '無標題';

  @override
  String editorRestoreDraftOverwrite(String title, String savedAt) {
    return '草稿：$title\n最後儲存：$savedAt\n\n還原後會覆蓋目前檢視中的內容。';
  }

  @override
  String editorRestoreDraftPrompt(String title, String savedAt) {
    return '草稿：$title\n最後儲存：$savedAt\n\n是否要還原這份草稿？';
  }

  @override
  String get editorDiscardDraftTitle => '捨棄草稿？';

  @override
  String get editorDiscardDraftBody => '目前的修改尚未儲存為日記，確定要捨棄草稿並離開嗎？';

  @override
  String get editorDiscardDraftConfirm => '捨棄';

  @override
  String get editorGalleryDownloadTooltip => '下載';

  @override
  String get editorGalleryDownloadFailed => '無法下載圖片';

  @override
  String editorGalleryDownloadSuccess(String path) {
    return '已儲存至 $path';
  }

  @override
  String get homeUnlockingTitle => '正在解鎖';

  @override
  String get homeRetryVerification => '重新驗證';

  @override
  String get homeGoToSettings => '前往設定';

  @override
  String get homeNavHome => '首頁';

  @override
  String get homeNavCalendar => '日曆';

  @override
  String get homeNavTags => '標籤';

  @override
  String get homeNavOverview => '總覽';

  @override
  String get homeTooltipNewEntry => '新增日記';

  @override
  String get homeTooltipSettings => '設定與備份';

  @override
  String get homeTooltipExportHtml => '匯出 HTML';

  @override
  String get homeTooltipDelete => '刪除';

  @override
  String get homeTooltipAddTag => '新增標籤';

  @override
  String get homeTooltipEditTag => '編輯標籤';

  @override
  String get homeTooltipDeleteTag => '刪除標籤';

  @override
  String get homeTooltipDeselectTag => '取消選取';

  @override
  String get homeSelectionSelectAll => '全選';

  @override
  String get homeSelectionDeselectAll => '取消全選';

  @override
  String get homeSelectionSelectDiary => '選取日記';

  @override
  String homeSelectionSelectedCount(int count) {
    return '已選 $count 項';
  }

  @override
  String get homeSearchHint => '搜尋標題、內文或標籤';

  @override
  String get homeEmptyDiaryTitle => '目前沒有日記';

  @override
  String get homeEmptyDiaryMessage => '建立第一篇日記後，就會在這裡看到你的首頁列表。';

  @override
  String get homeNoAnalysisTitle => '尚無可分析內容';

  @override
  String get homeNoAnalysisMessage => '寫下一篇後，就可以在這裡看到統計、標籤與範圍內的日記。';

  @override
  String get homeExportRecapLabel => '匯出回顧';

  @override
  String get homeExportRecapAll => '匯出總回顧';

  @override
  String get homeExportRecapYear => '匯出年度回顧';

  @override
  String get homeExportRecapMonth => '匯出月份回顧';

  @override
  String get homePopularTagsTitle => '熱門標籤';

  @override
  String get homeScopeTitle => '範圍';

  @override
  String get homeScopeAllLabel => '全部';

  @override
  String get homeScopeYearLabel => '年';

  @override
  String get homeScopeMonthLabel => '月';

  @override
  String get homeScopeEmptyDiary => '此範圍內沒有符合的日記。';

  @override
  String homeScopeEmptyDiaryForTag(String tag) {
    return '此範圍內沒有套用「$tag」的日記。';
  }

  @override
  String get homeScopeEmptyTags => '此範圍內沒有標籤。';

  @override
  String get homeUnsavedDraftLabel => '未儲存';

  @override
  String get homeHtmlExportLargeTitle => 'HTML 檔案可能很大';

  @override
  String get homeHtmlExportEmbeddedHint => '圖片會內嵌在單一 HTML 內，檔案可能較慢開啟或不易分享。';

  @override
  String get homeHtmlExportProceed => '仍要匯出';

  @override
  String homeHtmlExportSelectionSummary(
    String entrySummary,
    String imageSummary,
  ) {
    return '選取 $entrySummary日記，包含 $imageSummary圖片。';
  }

  @override
  String homeHtmlExportImageSize(String size) {
    return '圖片原始大小：約 $size';
  }

  @override
  String homeHtmlExportEstimatedSize(String size) {
    return 'HTML 估算大小：約 $size';
  }

  @override
  String homeHtmlExportSuccess(String fileName) {
    return '已匯出 HTML：$fileName';
  }

  @override
  String get homeDeleteTagTitle => '刪除標籤';

  @override
  String homeDeleteTagConfirm(String label) {
    return '確定要從所有日記移除「$label」嗎？';
  }

  @override
  String get homeTagSearchHint => '搜尋標籤…';

  @override
  String get homeNoTagsTitle => '尚未有標籤';

  @override
  String get homeNoTagsMessage => '可先建立標籤或使用預設標籤；即使尚未套用到日記也會保留在清單中。';

  @override
  String get homeTagListGuide => '請從標籤清單中點選一列：此區會依索引篩選出套用該標籤的日記摘要（再點同一列可取消選取）。';

  @override
  String get homeTagPreviewTitle => '選取標籤以預覽日記';

  @override
  String homeTagDeleted(String label) {
    return '「$label」已刪除';
  }

  @override
  String homeTagRemovedFromEntries(String entrySummary, String label) {
    return '已從 $entrySummary日記移除「$label」';
  }

  @override
  String homeTagIndexEmptyForTag(String tag) {
    return '目前索引中找不到套用「$tag」的項目。';
  }

  @override
  String homeTagRowEntryCount(String entrySummary) {
    return '$entrySummary日記';
  }

  @override
  String get homeTagRowTapHint => '輕觸列預覽';

  @override
  String homeDiarySectionTitleForDate(String dateLabel) {
    return '日記 · $dateLabel';
  }

  @override
  String homeEmptyDayMessage(String dateLabel) {
    return '「$dateLabel」這一天目前沒有日記。';
  }

  @override
  String get homeOverviewDataTitle => '資料概覽';

  @override
  String get homeOverviewScopeAll => '目前範圍 · 全部日記';

  @override
  String homeOverviewScopeYear(int year) {
    return '目前範圍 · $year年';
  }

  @override
  String homeOverviewScopeMonth(int year, int month) {
    return '目前範圍 · $year年$month月';
  }

  @override
  String get homeOverviewWritingDaysLabel => '撰寫天數';

  @override
  String get homeOverviewAvgLengthLabel => '平均篇幅';

  @override
  String get homeOverviewAttachmentsLabel => '附件總數';

  @override
  String homeOverviewAttachmentCount(String attachmentSummary) {
    return '$attachmentSummary';
  }

  @override
  String homeOverviewLongestStreak(String daySummary) {
    return '連續最長 $daySummary';
  }

  @override
  String homeOverviewEntryStats(String entrySummary, String characterSummary) {
    return '共 $entrySummary\n累計 $characterSummary';
  }

  @override
  String homeDiarySectionTag(String tag) {
    return '日記 · $tag';
  }

  @override
  String get homeDiarySectionAll => '日記 · 全部';

  @override
  String get homeDiarySectionByYear => '日記 · 依年';

  @override
  String get homeDiarySectionByMonth => '日記 · 依月';

  @override
  String homeDiarySectionWithTag(String baseTitle, String tag) {
    return '$baseTitle · $tag';
  }

  @override
  String get homeCalendarMonthFormatLabel => '月';

  @override
  String homeOverviewAvgLengthValue(int charactersPerEntry) {
    return '$charactersPerEntry 字 / 篇';
  }

  @override
  String homeOverviewAttachmentDetail(int photos, int files) {
    return '照片 $photos · 檔案 $files';
  }

  @override
  String homeOverviewMostEntriesInSingleDay(String entrySummary) {
    return '單天最多 $entrySummary';
  }

  @override
  String get vaultTransferNeedsUnlockForBackup => '請先解鎖日記庫，才能備份或匯出。';

  @override
  String get vaultTransferNeedsRecoveryKeyForBackup => '請先建立復原金鑰，才能備份或匯出。';

  @override
  String get vaultTransferNeedsUnlockForRestore => '請先解鎖日記庫，才能還原備份。';

  @override
  String get vaultTransferLocalSectionDescriptionBackupLocked =>
      '建立本機備份與匯出需先解鎖日記庫並建立復原金鑰；尚未建立復原金鑰或忘記金鑰時，可直接匯入外部備份還原。';

  @override
  String get vaultTransferDriveSectionDescriptionBackupLocked =>
      '備份到 Google Drive 需先解鎖日記庫並建立復原金鑰；尚未建立復原金鑰或忘記金鑰時，可直接從 Google Drive 還原。';

  @override
  String get vaultTransferDriveBackupActionsLockedHint =>
      '請先解鎖日記庫並建立復原金鑰，才能備份到 Google Drive。';

  @override
  String get vaultTransferRestoreUnlockFailed =>
      '備份已還原，但復原金鑰解鎖失敗。請在安全總覽重新輸入復原金鑰。';

  @override
  String get androidSafWriteFailed => '無法將檔案寫入選擇的資料夾。';

  @override
  String androidSafWriteFailedWithCode(String code) {
    return '無法將檔案寫入選擇的資料夾（$code）。';
  }

  @override
  String get defaultTagDaily => '日常';

  @override
  String get defaultTagMood => '心情';

  @override
  String get defaultTagReflection => '反思';

  @override
  String get defaultTagPlanning => '計畫';

  @override
  String get defaultTagWork => '工作';

  @override
  String get defaultTagStudy => '學習';

  @override
  String get defaultTagFamily => '家庭';

  @override
  String get defaultTagFriends => '朋友';

  @override
  String get defaultTagTravel => '旅遊';

  @override
  String get defaultTagFood => '美食';

  @override
  String get defaultTagEntertainment => '娛樂';

  @override
  String get defaultTagExercise => '運動';

  @override
  String get defaultTagHealth => '健康';

  @override
  String get defaultTagShopping => '購物';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => 'Quill Diary';

  @override
  String get languageNameZhTw => '繁體中文';

  @override
  String get languageNameEn => 'English';

  @override
  String get commonActionCancel => '取消';

  @override
  String get commonActionDelete => '刪除';

  @override
  String get commonActionApply => '套用';

  @override
  String get commonActionClose => '關閉';

  @override
  String get commonReadFailureTitle => '讀取失敗';

  @override
  String get commonConfirmDeleteTitle => '確認刪除';

  @override
  String get commonNoTagSearchResults => '沒有符合的標籤';

  @override
  String get commonCloseTooltip => '關閉';

  @override
  String get commonClearSearchTooltip => '清除搜尋';

  @override
  String commonConfirmDeleteEntries(int count) {
    return '確定要刪除 $count 篇日記嗎？刪除後無法復原。';
  }

  @override
  String get tagAddTitle => '新增標籤';

  @override
  String get tagEditTitle => '編輯標籤';

  @override
  String get tagSaveButton => '儲存';

  @override
  String get tagNameHint => '標籤名稱';

  @override
  String get tagNameRequiredMessage => '請輸入標籤名稱';

  @override
  String get tagDeleteLabel => '刪除標籤';

  @override
  String get tagUnnamedPreview => '未命名標籤';

  @override
  String get tagDefaultColorLabel => '預設色';

  @override
  String get tagHueLabel => '色相';

  @override
  String get tagPreviewLabel => '預覽';

  @override
  String tagSaveFailure(String message) {
    return '儲存標籤失敗：$message';
  }

  @override
  String tagDeleteFailure(String message) {
    return '刪除標籤失敗：$message';
  }

  @override
  String get personalizationNavButtonLabel => '個人化';

  @override
  String get personalizationPageTitle => '個人化';

  @override
  String get personalizationLoadErrorMessage => '無法載入個人化設定。';

  @override
  String get personalizationTypographyResetButton => '還原預設';

  @override
  String get personalizationTypographyResetConfirmTitle => '還原日記排版預設？';

  @override
  String get personalizationTypographyResetConfirmBody =>
      '這會把目前的標題、內文字體大小、行距與段落間距都還原成預設值。';

  @override
  String get personalizationTypographyResetConfirmAction => '還原預設';

  @override
  String get personalizationTypographyResetSuccess => '已還原日記排版預設。';

  @override
  String get personalizationLanguageSectionTitle => '語言';

  @override
  String get personalizationLanguageSectionDescription => '選擇介面顯示語言。';

  @override
  String get personalizationLanguageComingSoonHint => '部分英文翻譯仍在補完中。';

  @override
  String get personalizationSessionTimeoutSectionTitle => '自動鎖定';

  @override
  String get personalizationSessionTimeoutSectionDescription =>
      'App 切到背景一段時間後，會自動要求重新驗證。';

  @override
  String get personalizationSessionTimeoutUnitLabel => '分鐘';

  @override
  String get personalizationImageCompressSectionTitle => '圖片品質';

  @override
  String get personalizationImageCompressSectionDescription =>
      '調整編輯器插入圖片時的壓縮預設。';

  @override
  String get personalizationImageCompressOriginalLabel => '原圖';

  @override
  String get personalizationImageCompressStandardLabel => '標準';

  @override
  String get personalizationImageCompressHighLabel => '高畫質';

  @override
  String get personalizationAppearanceSectionTitle => '主題顏色';

  @override
  String get personalizationAppearanceSectionDescription =>
      '選擇 App 使用的淺色、深色或跟隨系統外觀。';

  @override
  String get personalizationAppearanceSystemLabel => '跟隨系統';

  @override
  String get personalizationAppearanceLightLabel => '淺色';

  @override
  String get personalizationAppearanceDarkLabel => '深色';

  @override
  String get personalizationTypographySectionTitle => '日記排版';

  @override
  String get personalizationTypographySectionDescription =>
      '調整日記編輯與預覽時的字體大小、行距與段落間距。';

  @override
  String get personalizationTitleFontSizeLabel => '標題字體大小';

  @override
  String get personalizationTitleLineHeightLabel => '標題行距';

  @override
  String get personalizationBodyFontSizeLabel => '內文字體大小';

  @override
  String get personalizationBodyLineHeightLabel => '內文行距';

  @override
  String get personalizationBodyParagraphSpacingLabel => '內文段落間距';

  @override
  String get settingsPageTitle => '設定';

  @override
  String get settingsProgressDefault => '正在處理，請稍候…';

  @override
  String get personalizationImageCompressOriginalDescription =>
      '不壓縮，保留原始解析度與檔案大小。適合需要最高畫質、可接受較大日記庫時使用。';

  @override
  String get personalizationImageCompressStandardDescription =>
      '長邊縮至 1280 px、JPEG 品質 70。在清晰度與儲存空間之間取得平衡（預設）。';

  @override
  String get personalizationImageCompressHighDescription =>
      '長邊縮至 1920 px、JPEG 品質 85。檔案較大，但細節保留較多。';

  @override
  String personalizationFontSizeValue(String size) {
    return '$size 點';
  }

  @override
  String personalizationLineHeightValue(String height) {
    return '$height 倍';
  }

  @override
  String personalizationParagraphSpacingValue(String spacing) {
    return '$spacing 像素';
  }

  @override
  String get personalizationTypographyPreviewTitleParagraph1 =>
      '今日的小確幸，陽光剛好落在書桌上。值得記住的一刻，先寫下來再說。';

  @override
  String get personalizationTypographyPreviewBodyParagraph1 =>
      '記錄下此刻的心情，讓文字替記憶保溫。記錄下此刻的心情，讓文字替記憶保溫。';

  @override
  String get personalizationTypographyPreviewBodyParagraph2 =>
      '段落之間的間距，也會反映在預覽裡。段落之間的間距，也會反映在預覽裡。';

  @override
  String get sessionBlockedLockedTitle => '日記庫已鎖定';

  @override
  String get sessionBlockedRecoveryRequiredTitle => '需要復原金鑰';

  @override
  String get sessionBlockedFatalErrorTitle => '無法啟動';

  @override
  String get sessionBlockedDefaultTitle => '請稍候';

  @override
  String get sessionBlockedLockedSubtitle => '請完成驗證以繼續';

  @override
  String get sessionBlockedRecoveryRequiredSubtitle => '請輸入復原金鑰解鎖';

  @override
  String get sessionBlockedFatalErrorSubtitle => '請檢查設定或重新啟動應用程式';

  @override
  String get editorPageTitle => '編輯日記';

  @override
  String get editorTitleHint => '輸入標題';

  @override
  String get editorTitleRequiredError => '請輸入標題';

  @override
  String get editorBodyHint => '在這裡輸入內容…';

  @override
  String get editorBodyEmptyPreview => '尚未輸入內容';

  @override
  String get editorNeedsRecoveryKeyMessage => '請先建立復原金鑰，才能開始建立或編輯日記。';

  @override
  String get editorSessionLockedFallback => '請先重新解鎖日記庫後再繼續。';

  @override
  String get editorSaveNeedsTitleMessage => '請輸入標題才能儲存';

  @override
  String get editorUnsavedDraftLabel => '未儲存';

  @override
  String get editorConfirmDeleteTitle => '確認刪除';

  @override
  String get editorConfirmDeleteBody => '確定要刪除這篇日記嗎？刪除後無法復原。';

  @override
  String get editorTagsStudioTitle => '標籤';

  @override
  String get editorTagsStudioGuide => '右上角可建立新標籤；下方為文庫標籤，輕觸加入。';

  @override
  String get editorTagsStudioEmptyChosen => '尚未套用任何標籤';

  @override
  String get editorTagsStudioAddButton => '加入';

  @override
  String get editorPreviewUnavailable => '無法預覽';

  @override
  String get editorTagSearchHint => '搜尋標籤…';

  @override
  String get editorTagLibraryHint => '文庫裡的標籤 · 輕觸加入';

  @override
  String get editorTagPoolEmpty => '文庫裡暫時沒有其他可用標籤，或已全部加入目前清單';

  @override
  String get editorTagAddTooltip => '新增標籤';

  @override
  String get editorTooltipCancel => '取消';

  @override
  String get editorTooltipSave => '儲存';

  @override
  String get editorTooltipSaveNeedsTitle => '請先輸入標題';

  @override
  String get editorTooltipDate => '日期';

  @override
  String get editorTooltipTime => '時間';

  @override
  String get editorTooltipEditTags => '編輯標籤';

  @override
  String get editorTooltipUploadImages => '上傳圖片（可一次選多張）';

  @override
  String get editorTooltipAddAttachment => '新增附件';

  @override
  String get editorTooltipDelete => '刪除';

  @override
  String get editorTooltipEdit => '編輯';

  @override
  String get editorRestoreDraftTitle => '發現未完成的草稿';

  @override
  String get editorRestoreDraftDecline => '不使用';

  @override
  String get editorRestoreDraftAccept => '還原草稿';

  @override
  String get editorUntitledDraft => '無標題';

  @override
  String editorRestoreDraftOverwrite(String title, String savedAt) {
    return '草稿：$title\n最後儲存：$savedAt\n\n還原後會覆蓋目前檢視中的內容。';
  }

  @override
  String editorRestoreDraftPrompt(String title, String savedAt) {
    return '草稿：$title\n最後儲存：$savedAt\n\n是否要還原這份草稿？';
  }

  @override
  String get editorDiscardDraftTitle => '捨棄草稿？';

  @override
  String get editorDiscardDraftBody => '目前的修改尚未儲存為日記，確定要捨棄草稿並離開嗎？';

  @override
  String get editorDiscardDraftConfirm => '捨棄';

  @override
  String get editorGalleryDownloadTooltip => '下載';

  @override
  String get editorGalleryDownloadFailed => '無法下載圖片';

  @override
  String editorGalleryDownloadSuccess(String path) {
    return '已儲存至 $path';
  }

  @override
  String get homeUnlockingTitle => '正在解鎖';

  @override
  String get homeRetryVerification => '重新驗證';

  @override
  String get homeGoToSettings => '前往設定';

  @override
  String get homeNavHome => '首頁';

  @override
  String get homeNavCalendar => '日曆';

  @override
  String get homeNavTags => '標籤';

  @override
  String get homeNavOverview => '總覽';

  @override
  String get homeTooltipNewEntry => '新增日記';

  @override
  String get homeTooltipSettings => '設定與備份';

  @override
  String get homeTooltipExportHtml => '匯出 HTML';

  @override
  String get homeTooltipDelete => '刪除';

  @override
  String get homeTooltipAddTag => '新增標籤';

  @override
  String get homeTooltipEditTag => '編輯標籤';

  @override
  String get homeTooltipDeleteTag => '刪除標籤';

  @override
  String get homeTooltipDeselectTag => '取消選取';

  @override
  String get homeSelectionSelectAll => '全選';

  @override
  String get homeSelectionDeselectAll => '取消全選';

  @override
  String get homeSelectionSelectDiary => '選取日記';

  @override
  String homeSelectionSelectedCount(int count) {
    return '已選 $count 項';
  }

  @override
  String get homeSearchHint => '搜尋標題、內文或標籤';

  @override
  String get homeEmptyDiaryTitle => '目前沒有日記';

  @override
  String get homeEmptyDiaryMessage => '建立第一篇日記後，就會在這裡看到你的首頁列表。';

  @override
  String get homeNoAnalysisTitle => '尚無可分析內容';

  @override
  String get homeNoAnalysisMessage => '寫下一篇後，就可以在這裡看到統計、標籤與範圍內的日記。';

  @override
  String get homeExportRecapLabel => '匯出回顧';

  @override
  String get homeExportRecapAll => '匯出總回顧';

  @override
  String get homeExportRecapYear => '匯出年度回顧';

  @override
  String get homeExportRecapMonth => '匯出月份回顧';

  @override
  String get homePopularTagsTitle => '熱門標籤';

  @override
  String get homeScopeTitle => '範圍';

  @override
  String get homeScopeAllLabel => '全部';

  @override
  String get homeScopeYearLabel => '年';

  @override
  String get homeScopeMonthLabel => '月';

  @override
  String get homeScopeEmptyDiary => '此範圍內沒有符合的日記。';

  @override
  String homeScopeEmptyDiaryForTag(String tag) {
    return '此範圍內沒有套用「$tag」的日記。';
  }

  @override
  String get homeScopeEmptyTags => '此範圍內沒有標籤。';

  @override
  String get homeUnsavedDraftLabel => '未儲存';

  @override
  String get homeHtmlExportLargeTitle => 'HTML 檔案可能很大';

  @override
  String get homeHtmlExportEmbeddedHint => '圖片會內嵌在單一 HTML 內，檔案可能較慢開啟或不易分享。';

  @override
  String get homeHtmlExportProceed => '仍要匯出';

  @override
  String homeHtmlExportSelectionSummary(
    String entrySummary,
    String imageSummary,
  ) {
    return '選取 $entrySummary日記，包含 $imageSummary圖片。';
  }

  @override
  String homeHtmlExportImageSize(String size) {
    return '圖片原始大小：約 $size';
  }

  @override
  String homeHtmlExportEstimatedSize(String size) {
    return 'HTML 估算大小：約 $size';
  }

  @override
  String homeHtmlExportSuccess(String fileName) {
    return '已匯出 HTML：$fileName';
  }

  @override
  String get homeDeleteTagTitle => '刪除標籤';

  @override
  String homeDeleteTagConfirm(String label) {
    return '確定要從所有日記移除「$label」嗎？';
  }

  @override
  String get homeTagSearchHint => '搜尋標籤…';

  @override
  String get homeNoTagsTitle => '尚未有標籤';

  @override
  String get homeNoTagsMessage => '可先建立標籤或使用預設標籤；即使尚未套用到日記也會保留在清單中。';

  @override
  String get homeTagListGuide => '請從標籤清單中點選一列：此區會依索引篩選出套用該標籤的日記摘要（再點同一列可取消選取）。';

  @override
  String get homeTagPreviewTitle => '選取標籤以預覽日記';

  @override
  String homeTagDeleted(String label) {
    return '「$label」已刪除';
  }

  @override
  String homeTagRemovedFromEntries(String entrySummary, String label) {
    return '已從 $entrySummary日記移除「$label」';
  }

  @override
  String homeTagIndexEmptyForTag(String tag) {
    return '目前索引中找不到套用「$tag」的項目。';
  }

  @override
  String homeTagRowEntryCount(String entrySummary) {
    return '$entrySummary日記';
  }

  @override
  String get homeTagRowTapHint => '輕觸列預覽';

  @override
  String homeDiarySectionTitleForDate(String dateLabel) {
    return '日記 · $dateLabel';
  }

  @override
  String homeEmptyDayMessage(String dateLabel) {
    return '「$dateLabel」這一天目前沒有日記。';
  }

  @override
  String get homeOverviewDataTitle => '資料概覽';

  @override
  String get homeOverviewScopeAll => '目前範圍 · 全部日記';

  @override
  String homeOverviewScopeYear(int year) {
    return '目前範圍 · $year年';
  }

  @override
  String homeOverviewScopeMonth(int year, int month) {
    return '目前範圍 · $year年$month月';
  }

  @override
  String get homeOverviewWritingDaysLabel => '撰寫天數';

  @override
  String get homeOverviewAvgLengthLabel => '平均篇幅';

  @override
  String get homeOverviewAttachmentsLabel => '附件總數';

  @override
  String homeOverviewAttachmentCount(String attachmentSummary) {
    return '$attachmentSummary';
  }

  @override
  String homeOverviewLongestStreak(String daySummary) {
    return '連續最長 $daySummary';
  }

  @override
  String homeOverviewEntryStats(String entrySummary, String characterSummary) {
    return '共 $entrySummary\n累計 $characterSummary';
  }

  @override
  String homeDiarySectionTag(String tag) {
    return '日記 · $tag';
  }

  @override
  String get homeDiarySectionAll => '日記 · 全部';

  @override
  String get homeDiarySectionByYear => '日記 · 依年';

  @override
  String get homeDiarySectionByMonth => '日記 · 依月';

  @override
  String homeDiarySectionWithTag(String baseTitle, String tag) {
    return '$baseTitle · $tag';
  }

  @override
  String get homeCalendarMonthFormatLabel => '月';

  @override
  String homeOverviewAvgLengthValue(int charactersPerEntry) {
    return '$charactersPerEntry 字 / 篇';
  }

  @override
  String homeOverviewAttachmentDetail(int photos, int files) {
    return '照片 $photos · 檔案 $files';
  }

  @override
  String homeOverviewMostEntriesInSingleDay(String entrySummary) {
    return '單天最多 $entrySummary';
  }

  @override
  String get vaultTransferNeedsUnlockForBackup => '請先解鎖日記庫，才能備份或匯出。';

  @override
  String get vaultTransferNeedsRecoveryKeyForBackup => '請先建立復原金鑰，才能備份或匯出。';

  @override
  String get vaultTransferNeedsUnlockForRestore => '請先解鎖日記庫，才能還原備份。';

  @override
  String get vaultTransferLocalSectionDescriptionBackupLocked =>
      '建立本機備份與匯出需先解鎖日記庫並建立復原金鑰；尚未建立復原金鑰或忘記金鑰時，可直接匯入外部備份還原。';

  @override
  String get vaultTransferDriveSectionDescriptionBackupLocked =>
      '備份到 Google Drive 需先解鎖日記庫並建立復原金鑰；尚未建立復原金鑰或忘記金鑰時，可直接從 Google Drive 還原。';

  @override
  String get vaultTransferDriveBackupActionsLockedHint =>
      '請先解鎖日記庫並建立復原金鑰，才能備份到 Google Drive。';

  @override
  String get vaultTransferRestoreUnlockFailed =>
      '備份已還原，但復原金鑰解鎖失敗。請在安全總覽重新輸入復原金鑰。';

  @override
  String get androidSafWriteFailed => '無法將檔案寫入選擇的資料夾。';

  @override
  String androidSafWriteFailedWithCode(String code) {
    return '無法將檔案寫入選擇的資料夾（$code）。';
  }

  @override
  String get defaultTagDaily => '日常';

  @override
  String get defaultTagMood => '心情';

  @override
  String get defaultTagReflection => '反思';

  @override
  String get defaultTagPlanning => '計畫';

  @override
  String get defaultTagWork => '工作';

  @override
  String get defaultTagStudy => '學習';

  @override
  String get defaultTagFamily => '家庭';

  @override
  String get defaultTagFriends => '朋友';

  @override
  String get defaultTagTravel => '旅遊';

  @override
  String get defaultTagFood => '美食';

  @override
  String get defaultTagEntertainment => '娛樂';

  @override
  String get defaultTagExercise => '運動';

  @override
  String get defaultTagHealth => '健康';

  @override
  String get defaultTagShopping => '購物';
}
