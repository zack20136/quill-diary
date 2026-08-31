// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get commonMoreActions => '更多操作';

  @override
  String get appTitle => 'Quill Diary';

  @override
  String get languageNameZh => '繁體中文';

  @override
  String get languageNameEn => 'English';

  @override
  String get commonActionCancel => '取消';

  @override
  String get commonActionDelete => '刪除';

  @override
  String get commonActionApply => '套用';

  @override
  String get commonActionConfirm => '確定';

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
  String get commonUnitEntries => '篇';

  @override
  String get commonUnitTags => '筆';

  @override
  String get commonUnitAttachments => '個附件';

  @override
  String get commonUnitDays => '天';

  @override
  String get commonUnitCharacters => '字';

  @override
  String get commonUnitMilliseconds => '毫秒';

  @override
  String get commonUnitSeconds => '秒';

  @override
  String get commonRelativeToday => '今天';

  @override
  String get commonRelativeYesterday => '昨天';

  @override
  String commonRelativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
      one: '1 天前',
    );
    return '$_temp0';
  }

  @override
  String get userFacingErrorDefaultMessage => '操作失敗，請稍後再試。';

  @override
  String get userFacingErrorLocalPathLabel => '本機路徑';

  @override
  String commonGoogleAccountLabel(String name, String email) {
    return '$name · $email';
  }

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
  String get tagCustomColorLabel => '自訂顏色';

  @override
  String get tagCustomColorDialogTitle => '選擇自訂顏色';

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
  String get personalizationAppearanceSectionTitle => '外觀';

  @override
  String get personalizationAppearanceSectionDescription =>
      '選擇 App 使用淺色、深色或跟隨系統。';

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
  String get settingsProgressWorkingTitle => '正在處理';

  @override
  String get settingsProgressKeepAppOpenHint => '請保持 App 開啟';

  @override
  String settingsProgressPercent(int percent) {
    return '$percent%';
  }

  @override
  String settingsProgressSemanticDeterminate(
    String title,
    String stage,
    int percent,
  ) {
    return '$title。$stage。進度 $percent%';
  }

  @override
  String settingsProgressSemanticIndeterminate(String title, String stage) {
    return '$title。$stage。進度尚無法估算';
  }

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
  String get sessionUnsupportedRuntimeMessage => 'Quill Diary 目前僅支援 Android。';

  @override
  String get editorPageTitle => '編輯日記';

  @override
  String get editorTitleHint => '輸入標題';

  @override
  String get editorEntryRequiredError => '請輸入標題或內容';

  @override
  String get editorBodyHint => '在這裡輸入內容…';

  @override
  String get editorCheckboxDragTooltip => '拖移排序';

  @override
  String get editorBodyEmptyPreview => '尚未輸入內容';

  @override
  String get editorNeedsRecoveryKeyMessage => '請先建立復原金鑰，才能開始建立或編輯日記。';

  @override
  String get editorSessionLockedFallback => '請先重新解鎖日記庫後再繼續。';

  @override
  String get editorSaveNeedsEntryMessage => '請輸入標題或內容才能儲存';

  @override
  String get editorUnsavedDraftLabel => '未儲存';

  @override
  String get editorConfirmDeleteTitle => '確認刪除';

  @override
  String get editorConfirmDeleteBody => '確定要刪除這篇日記嗎？刪除後無法復原。';

  @override
  String get editorTagsStudioTitle => '標籤';

  @override
  String get editorTagsStudioGuide => '可從右上角建立新標籤，也可輕觸下方標籤庫中的標籤加入。';

  @override
  String get editorTagsStudioEmptyChosen => '尚未套用任何標籤';

  @override
  String get editorTagsStudioAddButton => '加入';

  @override
  String get editorPreviewUnavailable => '無法預覽';

  @override
  String get editorTagSearchHint => '搜尋標籤…';

  @override
  String get editorTagLibraryHint => '標籤庫 · 輕觸加入';

  @override
  String get editorTagPoolEmpty => '標籤庫中暫時沒有其他可用標籤，或已全部加入目前清單';

  @override
  String get editorTagAddTooltip => '新增標籤';

  @override
  String get editorTooltipCancel => '取消';

  @override
  String get editorTooltipSave => '儲存';

  @override
  String get editorTooltipSaveNeedsEntry => '請先輸入標題或內容';

  @override
  String get editorTooltipDate => '設定日期';

  @override
  String get editorTooltipTime => '設定時間';

  @override
  String get editorTooltipEditTags => '編輯標籤';

  @override
  String get editorTooltipUploadImages => '上傳圖片';

  @override
  String get editorTooltipAddAttachment => '新增附件';

  @override
  String get editorTooltipInsertCheckbox => '插入任務項目';

  @override
  String get editorTooltipDelete => '刪除';

  @override
  String get editorTooltipEdit => '編輯';

  @override
  String editorAttachmentImagesLabel(int count) {
    return '圖片 $count';
  }

  @override
  String editorAttachmentFilesLabel(int count) {
    return '附件 $count';
  }

  @override
  String get editorAttachmentPendingLabel => '新增';

  @override
  String get editorAttachmentDragTooltip => '長按拖曳以調整順序';

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
  String get homeNavPeople => '人物';

  @override
  String get homeNavOverview => '總覽';

  @override
  String get homePopularPeopleTitle => '提及最多的人物';

  @override
  String get peopleEmptyTitle => '尚未建立人物';

  @override
  String get peopleEmptyBody =>
      '建立人物後，可用姓名與別名分析日記提及，並在編輯器以 @ 快速插入該人物指定的名稱（預設為姓名，也可改選別名）。';

  @override
  String get peopleNotFoundTitle => '找不到這位人物';

  @override
  String get peopleNotFoundMessage => '這位人物可能已被刪除，或無法從目前資料中讀取。';

  @override
  String get peopleSearchHint => '搜尋姓名或別名';

  @override
  String get peopleSearchNoResultsTitle => '沒有符合的人物';

  @override
  String get peopleSearchNoResultsMessage => '試試其他關鍵字，或調整關係篩選條件。';

  @override
  String get peopleCreateAction => '新增人物';

  @override
  String get peopleManageRelationshipsTooltip => '管理關係';

  @override
  String get peopleManageRelationshipsTitle => '管理關係';

  @override
  String get peopleManageRelationshipsGuide =>
      '拖曳左側把手可排序；點名稱可重新命名。新增時會同時寫入目前語言與另一語言的相同文字。';

  @override
  String get peopleReorderRelationshipTooltip => '拖曳排序';

  @override
  String get peopleManageRelationshipsEmpty => '尚未有任何關係類型';

  @override
  String get peopleAddRelationshipHint => '例如：導師';

  @override
  String get peopleAddRelationshipAction => '新增';

  @override
  String get peopleRenameRelationshipAction => '重新命名';

  @override
  String get peopleDeleteRelationshipAction => '刪除';

  @override
  String get peopleRelationshipNameEmpty => '關係名稱不可為空白';

  @override
  String get peopleRelationshipNameDuplicate => '這個關係名稱已經存在';

  @override
  String get peopleDeleteRelationshipConfirmTitle => '刪除關係？';

  @override
  String peopleDeleteRelationshipConfirmBody(int count) {
    return '有 $count 位人物使用此關係，刪除後會一併從這些人物移除。';
  }

  @override
  String get peopleSortTooltip => '排序方式';

  @override
  String get peopleSortLastMention => '最近提及';

  @override
  String get peopleSortTotalMentions => '提及篇數';

  @override
  String get peopleSortRecentMentions => '近 30 天';

  @override
  String get peopleSortName => '姓名';

  @override
  String get peopleFieldName => '姓名';

  @override
  String get peopleFieldColor => '人物顏色';

  @override
  String get peopleColorAutomatic => '自動配色';

  @override
  String get peopleColorCustom => '自訂顏色';

  @override
  String get peopleChooseCustomColor => '更多顏色';

  @override
  String peopleColorPreset(int number) {
    return '顏色 $number';
  }

  @override
  String get peopleFieldAliases => '別名';

  @override
  String get peopleFieldAliasesHint => '可用逗號分隔多個別名';

  @override
  String get peopleAddAliasLabel => '新增別名';

  @override
  String get peopleAddAliasAction => '加入別名';

  @override
  String get peopleAliasAlreadyAdded => '這個別名已經加入';

  @override
  String peopleRemoveAliasAction(String alias) {
    return '移除別名「$alias」';
  }

  @override
  String get peopleFieldMentionName => '@ 使用名稱';

  @override
  String get peopleFieldMentionNameHint => '選擇 @ 插入日記時使用的名稱或別名';

  @override
  String get peopleMentionNameUsesNameFallback => '名稱';

  @override
  String peopleExportRecapScope(String name) {
    return '與 $name 相關的日記';
  }

  @override
  String get peopleFieldRelationships => '關係';

  @override
  String get peopleFieldRelationshipDescription => '關係描述';

  @override
  String get peopleFieldNotes => '備註';

  @override
  String get peopleNoValue => '無';

  @override
  String get peopleFieldFriendliness => '熟悉程度';

  @override
  String get peopleFieldBirthday => '生日';

  @override
  String get peopleFieldAcquaintanceYear => '認識年份';

  @override
  String get peopleSectionBasic => '基本資料';

  @override
  String get peopleSectionRelationship => '關係';

  @override
  String get peopleSectionOther => '其他資訊';

  @override
  String get peopleMentionOverviewTitle => '提及概況';

  @override
  String get peopleProfileDetailsTitle => '人物資料';

  @override
  String get peopleFriendlinessLow => '陌生';

  @override
  String get peopleFriendlinessHigh => '很熟';

  @override
  String get peopleFriendlinessLevel1 => '陌生';

  @override
  String get peopleFriendlinessLevel2 => '不熟';

  @override
  String get peopleFriendlinessLevel3 => '認識';

  @override
  String get peopleFriendlinessLevel4 => '熟悉';

  @override
  String get peopleFriendlinessLevel5 => '很熟';

  @override
  String peopleAnalysisProgress(int processed, int total) {
    return '正在分析日記 $processed／$total';
  }

  @override
  String peopleIndexPreparationProgress(int processed, int total) {
    return '正在整理日記索引 $processed／$total';
  }

  @override
  String peopleFriendlinessSemantics(
    int level,
    int max,
    String low,
    String high,
  ) {
    return '$level／$max（$low–$high）';
  }

  @override
  String peopleFriendlinessValueSemantics(String label, int level, int max) {
    return '$label，$level／$max';
  }

  @override
  String get peopleCreateTitle => '新增人物';

  @override
  String get peopleEditTitle => '編輯人物';

  @override
  String get peopleDetailTitle => '人物';

  @override
  String get peopleSaveAction => '儲存';

  @override
  String get peopleDeleteAction => '刪除人物';

  @override
  String get peopleDeleteConfirmTitle => '刪除人物？';

  @override
  String get peopleDeleteConfirmBody => '只會刪除人物名冊與衍生統計，不會修改任何日記內容。';

  @override
  String get peopleNameRequired => '請填寫姓名';

  @override
  String get peopleNameConflict => '姓名或別名與既有人物重複';

  @override
  String get peopleDiscardChangesTitle => '捨棄人物修改？';

  @override
  String get peopleDiscardChangesBody => '尚未儲存的修改將會遺失。';

  @override
  String get peopleDiscardChangesAction => '捨棄';

  @override
  String peopleSaveFailure(String message) {
    return '無法儲存人物：$message';
  }

  @override
  String peopleDeleteFailure(String message) {
    return '無法刪除人物：$message';
  }

  @override
  String get peopleWarningConfirmTitle => '仍要儲存？';

  @override
  String get peopleWarningConfirmBody => '姓名過短或與其他人物名稱前綴重疊，可能造成統計誤判。';

  @override
  String get peopleRenameKeepAliasTitle => '保留舊姓名為別名？';

  @override
  String get peopleRenameKeepAliasBody => '改名後舊姓名會加入別名，既有日記仍可被分析到此人物。';

  @override
  String get peopleRenameKeepAliasAction => '保留';

  @override
  String peopleMentionCount(int count) {
    return '提及 $count 篇';
  }

  @override
  String peopleRecentMentionCount(int count) {
    return '近 30 天 $count 篇';
  }

  @override
  String peopleLastMention(String date) {
    return '上次提及 $date';
  }

  @override
  String get peopleLastMentionNever => '尚未提及';

  @override
  String get peopleTotalMentionsLabel => '總提及';

  @override
  String get peopleRecentMentionsLabel => '近 30 天';

  @override
  String get peopleLastMentionLabel => '上次提及';

  @override
  String peopleMentionEntriesValue(int count) {
    return '$count 篇';
  }

  @override
  String get peopleAnalysisLoading => '正在分析日記';

  @override
  String get peopleAnalysisRetry => '重新分析';

  @override
  String get peopleRelatedEntriesTitle => '相關日記';

  @override
  String get peopleRelatedEntriesEmpty => '尚無相關日記';

  @override
  String get peoplePickBirthday => '選擇生日';

  @override
  String get peopleClearBirthday => '清除生日';

  @override
  String get peopleClearAcquaintanceYear => '清除認識年份';

  @override
  String get editorMentionEmptyCatalog => '尚無名冊人物。請到人物分頁建立。';

  @override
  String get editorMentionNoMatches => '找不到符合的人物';

  @override
  String get editorMentionCreatePerson => '建立人物';

  @override
  String get homeTooltipNewEntry => '新增日記';

  @override
  String get homeTooltipSettings => '設定';

  @override
  String get homeTooltipExportHtml => '匯出 HTML';

  @override
  String get homeTooltipPin => '釘選';

  @override
  String get homeTooltipUnpin => '取消釘選';

  @override
  String homePinEntriesSuccess(int count) {
    return '已釘選 $count 篇';
  }

  @override
  String homeUnpinEntriesSuccess(int count) {
    return '已取消釘選 $count 篇';
  }

  @override
  String get homeTooltipDelete => '刪除';

  @override
  String get homeTooltipAddTag => '新增標籤';

  @override
  String get homeTooltipEditTag => '編輯標籤';

  @override
  String get homeTooltipDeleteTag => '刪除標籤';

  @override
  String get homeTooltipBackToTop => '返回頂部';

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
  String homeSearchResultCount(int count) {
    return '找到 $count 筆';
  }

  @override
  String get homeSearchNoResultsTitle => '沒有符合的日記';

  @override
  String get homeSearchNoResultsMessage => '試試其他關鍵字，或搜尋標題、內文與標籤。';

  @override
  String get homeEmptyDiaryTitle => '目前沒有日記';

  @override
  String get homeEmptyDiaryMessage => '建立第一篇日記後，就會在這裡看到您的首頁列表。';

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
  String get portableExportConfirmTitle => '確認匯出';

  @override
  String get portableExportConfirmAction => '匯出';

  @override
  String get portableExportPlaintextWarning =>
      '匯出後為明文檔案，日記內文與圖片不再受日記庫加密保護；取得檔案的人都能閱讀。';

  @override
  String get portableExportMarkdownFormatLabel => '格式：Markdown ZIP';

  @override
  String get portableExportHtmlFormatLabel => '格式：HTML';

  @override
  String portableExportEntryCount(int count) {
    return '篇數：$count';
  }

  @override
  String portableExportImageCount(int count) {
    return '圖片：$count';
  }

  @override
  String portableExportAttachmentCount(int count) {
    return '附件：$count';
  }

  @override
  String portableExportDateRange(String start, String end) {
    return '日期範圍：$start ～ $end';
  }

  @override
  String portableExportFileSize(String size) {
    return '檔案大小：約 $size';
  }

  @override
  String portableExportScopeLabel(String scope) {
    return '範圍：$scope';
  }

  @override
  String get portableExportIncludeImagesLabel => '匯出圖片與附件';

  @override
  String get portableExportHidePersonNamesLabel => '隱藏人物名稱';

  @override
  String get portableExportHidePersonNamesHint => '把名冊裡的姓名與別名換成人物A、人物B 等代號。';

  @override
  String get portableExportSelectEntriesLabel => '選擇日記';

  @override
  String portableExportSelectEntriesSummary(int selected, int total) {
    return '已選 $selected／$total 篇';
  }

  @override
  String get portableImportConfirmTitle => '確認匯入';

  @override
  String get portableImportConfirmAction => '開始匯入';

  @override
  String portableImportLikelyDuplicateCount(int count) {
    return '可能與庫內重複：$count 篇';
  }

  @override
  String get portableImportLikelyDuplicateMark => '可能重複';

  @override
  String portableImportSkippedFilesCount(int count) {
    return '無法解析：$count 個檔案';
  }

  @override
  String portableImportSkippedAttachmentsCount(int count) {
    return '略過附件：$count';
  }

  @override
  String get portableImportAddsAsNewHint => '仍會一律新增，不會自動去重。';

  @override
  String homeHtmlExportImageSize(String size) {
    return '圖片原始大小：約 $size';
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
  String get homeNoTagsMessage =>
      '可點下方按鈕建立一組預設標籤，或使用右上角的「+」自行新增；即使尚未套用到日記也會保留在清單中。';

  @override
  String get homeCreateDefaultTagsButton => '建立預設標籤';

  @override
  String get homeCreateDefaultTagsSuccess => '已建立預設標籤';

  @override
  String homeTagsSectionTitle(String countSummary) {
    return '標籤（$countSummary）';
  }

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
  String homeEntriesDeletedSuccess(int count) {
    return '已刪除 $count 篇日記';
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
  String get datePickerChooseDate => '選擇日期';

  @override
  String get datePickerChooseYearMonth => '選擇年月';

  @override
  String get datePickerChooseYear => '選擇年份';

  @override
  String get datePickerYearLabel => '年份';

  @override
  String get datePickerMonthLabel => '月份';

  @override
  String get datePickerDayLabel => '日期';

  @override
  String get timePickerChooseTime => '選擇時間';

  @override
  String get timePickerHourLabel => '小時';

  @override
  String get timePickerMinuteLabel => '分鐘';

  @override
  String get timePickerAm => 'AM';

  @override
  String get timePickerPm => 'PM';

  @override
  String get timePickerInvalidTime => '請輸入有效的時間';

  @override
  String get timePickerInputHint => '請輸入 1–12 的小時與 0–59 的分鐘';

  @override
  String get timePickerSwitchToInput => '切換為數字輸入';

  @override
  String get timePickerSwitchToDial => '切換為鐘面選擇';

  @override
  String get timePickerDialSemantics => '時間選擇鐘面';

  @override
  String get datePickerPreviousYear => '上一年';

  @override
  String get datePickerNextYear => '下一年';

  @override
  String get datePickerPreviousMonth => '上個月';

  @override
  String get datePickerNextMonth => '下個月';

  @override
  String datePickerMonthOption(int month) {
    return '$month 月';
  }

  @override
  String datePickerDayOption(int day) {
    return '$day 日';
  }

  @override
  String get datePickerWeekdaySun => '日';

  @override
  String get datePickerWeekdayMon => '一';

  @override
  String get datePickerWeekdayTue => '二';

  @override
  String get datePickerWeekdayWed => '三';

  @override
  String get datePickerWeekdayThu => '四';

  @override
  String get datePickerWeekdayFri => '五';

  @override
  String get datePickerWeekdaySat => '六';

  @override
  String homeCalendarEntryCount(int count) {
    return '$count 篇日記';
  }

  @override
  String get homeCalendarSelectedStatus => '已選取';

  @override
  String get homeCalendarWeekdaySun => '日';

  @override
  String get homeCalendarWeekdayMon => '一';

  @override
  String get homeCalendarWeekdayTue => '二';

  @override
  String get homeCalendarWeekdayWed => '三';

  @override
  String get homeCalendarWeekdayThu => '四';

  @override
  String get homeCalendarWeekdayFri => '五';

  @override
  String get homeCalendarWeekdaySat => '六';

  @override
  String sessionBackgroundTimeoutMinutes(int count) {
    return '$count 分鐘';
  }

  @override
  String sessionBackgroundTimeoutSeconds(int count) {
    return '$count 秒';
  }

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
  String get vaultTransferNeedsUnlockForPortableTransfer =>
      '請先解鎖日記庫，才能匯入或匯出日記。';

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
  String get vaultTransferLocalBackupActionsLockedHint =>
      '請先解鎖日記庫並建立復原金鑰，才能建立或匯出本機備份。';

  @override
  String get vaultTransferRestoreUnlockFailed =>
      '備份已還原，但復原金鑰解鎖失敗。請在安全總覽重新輸入復原金鑰。';

  @override
  String get vaultTransferPickBackupFileTitle => '選擇備份 ZIP';

  @override
  String get vaultTransferPickedFileUnreadable => '無法讀取所選備份，請重新選取或改用其他來源。';

  @override
  String get vaultTransferPickBackupDirectoryTitle => '選擇匯出備份的資料夾';

  @override
  String get vaultTransferPickMarkdownDirectoryTitle => '選擇匯出日記的資料夾';

  @override
  String get vaultTransferPickHtmlDirectoryTitle => '選擇匯出 HTML 的資料夾';

  @override
  String get vaultTransferImportDocumentsDirectoryPrompt =>
      '選擇包含要匯入之 App Markdown 或 HTML 的資料夾';

  @override
  String get vaultTransferImportDocumentsFileTitle =>
      '選擇 ZIP、Markdown 或 HTML 以匯入';

  @override
  String get vaultTransferBackupOutsideExpectedDirectory => '備份檔案不在預期目錄內';

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
  String get defaultTagTakeaways => '心得';

  @override
  String get defaultTagNotes => '筆記';

  @override
  String get defaultTagReflection => '反思';

  @override
  String get defaultTagIdeas => '靈感';

  @override
  String get defaultTagPlans => '計畫';

  @override
  String get defaultTagGoals => '目標';

  @override
  String get defaultTagWork => '工作';

  @override
  String get defaultTagLearning => '學習';

  @override
  String get defaultTagRelationships => '人際';

  @override
  String get defaultTagFamily => '家庭';

  @override
  String get defaultTagHealth => '健康';

  @override
  String get defaultTagGratitude => '感謝';

  @override
  String get settingsActionConfirm => '確認還原';

  @override
  String get settingsActionUpdate => '更新';

  @override
  String get settingsActionVerifyAndRestore => '驗證並還原';

  @override
  String get settingsRecoveryKeyFieldLabel => '復原金鑰';

  @override
  String get settingsRecoveryKeyFieldHint => 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX';

  @override
  String get settingsRecoveryKeyShowTooltip => '顯示復原金鑰';

  @override
  String get settingsRecoveryKeyHideTooltip => '隱藏復原金鑰';

  @override
  String settingsRecoveryKeyHintLine(String hint) {
    return '末四碼：$hint';
  }

  @override
  String get settingsBackupPhaseCreating => '正在建立備份…';

  @override
  String get settingsBackupPhaseCopying => '正在寫入備份…';

  @override
  String get settingsBackupPhaseDownloadingDrive => '正在從 Google Drive 下載…';

  @override
  String get settingsBackupPhaseRestoring => '正在還原備份，請勿關閉應用程式…';

  @override
  String get settingsBackupStartingAfterRestore => '正在啟動還原後的日記庫…';

  @override
  String get settingsSecurityLockStatusPreparing => '正在準備中…';

  @override
  String get settingsSecurityLockStatusUnlocked => '已解鎖，可以正常使用。';

  @override
  String get settingsSecurityLockStatusFatalError => '初始化失敗，請稍後再試。';

  @override
  String get settingsSecurityLockUnlockingWaitHint =>
      '若等候過久，驗證視窗可能被擋住。可取消後改用手動驗證。';

  @override
  String get settingsSecurityLockCancelUnlockButton => '取消並改用手動驗證';

  @override
  String get settingsSecurityLockUnlockWithRecoveryButton => '使用復原金鑰解鎖';

  @override
  String get settingsSecurityLockRecoveryUnlockHint => '輸入復原金鑰以解鎖日記庫。';

  @override
  String get settingsSecurityLockRetryVerificationButton => '重新驗證';

  @override
  String get settingsRecoveryKeyNotSetupBanner =>
      '尚未建立復原金鑰。復原金鑰是保護整個日記庫的重要依據，請先建立並妥善保存，以便換機、還原或裝置失效時使用。';

  @override
  String get settingsRecoveryKeySetupBanner => '復原金鑰已建立，請確認已妥善保存。';

  @override
  String get settingsRecoveryKeyCreateButton => '建立復原金鑰';

  @override
  String get settingsRecoveryKeyRotateButton => '更新復原金鑰';

  @override
  String get settingsRecoveryKeyFactVaultLabel => '日記庫';

  @override
  String get settingsRecoveryKeyFactHintLabel => '末四碼';

  @override
  String get settingsRecoveryKeyFactKdfLabel => '加密方式';

  @override
  String get settingsRecoveryKeySaveDialogTitle => '請保存復原金鑰';

  @override
  String get settingsRecoveryKeySaveNewDialogTitle => '請保存新的復原金鑰';

  @override
  String get settingsRecoveryKeySaveDialogHint => '請立即保存。關閉此畫面後不會再次顯示。';

  @override
  String get settingsRecoveryKeyCopyButton => '複製';

  @override
  String get settingsRecoveryKeyCopiedMessage => '已複製到剪貼簿';

  @override
  String get tagColorCodeCopiedMessage => '色碼已複製';

  @override
  String get settingsRecoveryKeyRotateDialogTitle => '更新復原金鑰？';

  @override
  String get settingsRecoveryKeyRotateDialogBody =>
      '將產生全新的復原金鑰，請立即保存。\n\n既有本機或 Google Drive 備份仍須使用舊金鑰還原；更新後請重新建立備份。';

  @override
  String get settingsSecurityOverviewSectionTitle => '安全狀態';

  @override
  String get settingsSecurityOverviewSectionDescription =>
      '查看復原金鑰、解鎖方式、搜尋索引與備份狀態是否正常。';

  @override
  String get settingsSecurityOverviewRecoveryKeyTitle => '復原金鑰';

  @override
  String get settingsSecurityOverviewRecoveryKeyReady => '已建立，可用於換機與還原。';

  @override
  String get settingsSecurityOverviewRecoveryKeyMissing => '尚未建立，請先建立後再備份或匯出。';

  @override
  String get settingsSecurityOverviewUnlockStatusTitle => '解鎖狀態';

  @override
  String get settingsSecurityOverviewUnlockStatusUnlocked => '日記庫目前已解鎖。';

  @override
  String get settingsSecurityOverviewUnlockStatusLocked => '請先解鎖，才能備份、還原或調整設定。';

  @override
  String get settingsSecurityOverviewUnlockModeTitle => '解鎖方式';

  @override
  String get settingsSecurityOverviewTrustedDeviceTitle => '可信裝置';

  @override
  String get settingsSecurityOverviewTrustedDeviceReady => '這台裝置已完成驗證，可快速解鎖。';

  @override
  String get settingsSecurityOverviewTrustedDeviceMissing => '這台裝置尚未完成驗證。';

  @override
  String get settingsSecurityOverviewUnlockModeNeedsRecoveryKeyMessage =>
      '請先建立復原金鑰。它是保護整個日記庫的重要依據，建立後才能設定解鎖方式，也能在換機、還原或裝置失效時重新進入日記庫。';

  @override
  String settingsSecurityOverviewUnlockModeProtectedMessage(
    String unlockModeLabel,
  ) {
    return '目前以 $unlockModeLabel 保護此裝置。';
  }

  @override
  String get settingsSecurityOverviewIndexTitle => '日記庫';

  @override
  String get settingsSecurityOverviewCreateRecoveryKeyButton => '建立復原金鑰';

  @override
  String get settingsSecurityOverviewRotateRecoveryKeyButton => '更新復原金鑰';

  @override
  String get settingsSecurityOverviewRepairVaultButton => '修復日記庫';

  @override
  String get settingsSecurityOverviewInspectVaultButton => '檢查日記庫';

  @override
  String get settingsSecurityOverviewHealthLevelOk => '正常';

  @override
  String get settingsSecurityOverviewHealthLevelWarning => '需注意';

  @override
  String get settingsSecurityOverviewHealthLevelError => '錯誤';

  @override
  String get settingsSecurityOverviewLocalBackupTitle => '本機備份';

  @override
  String get settingsSecurityOverviewLocalBackupNever => '尚未建立本機備份，建議儘快備份。';

  @override
  String settingsSecurityOverviewLocalBackupLast(String time, String method) {
    return '上次本機備份：$time（$method）。';
  }

  @override
  String get settingsSecurityOverviewLocalBackupStale =>
      '距離上次本機備份已超過 30 天，建議儘快備份。';

  @override
  String get settingsSecurityOverviewDriveBackupTitle => 'Google Drive 備份';

  @override
  String get settingsSecurityOverviewDriveBackupNever =>
      '尚未建立 Google Drive 備份，建議儘快備份。';

  @override
  String settingsSecurityOverviewDriveBackupLast(String time) {
    return '上次 Google Drive 備份：$time。';
  }

  @override
  String settingsSecurityOverviewDriveBackupLastWithAccount(
    String time,
    String account,
  ) {
    return '上次 Google Drive 備份：$time（$account）。';
  }

  @override
  String get settingsSecurityOverviewDriveBackupStale =>
      '距離上次 Google Drive 備份已超過 30 天，建議儘快備份。';

  @override
  String settingsSecurityOverviewBackupRecentFailure(String action) {
    return '最近一次「$action」失敗。';
  }

  @override
  String get settingsUnlockModeFullNone => '無';

  @override
  String get settingsUnlockModeFullDeviceLock => '裝置螢幕鎖';

  @override
  String get settingsUnlockModeFullBiometric => '生物驗證';

  @override
  String get settingsUnlockMethodSectionTitle => '解鎖方式';

  @override
  String settingsUnlockMethodSectionDescription(String timeoutLabel) {
    return 'App 放在背景超過 $timeoutLabel 會自動鎖定；如果只是短時間切換 App，通常不會。鎖定後回到 App 時，請依下方設定的解鎖方式重新驗證。';
  }

  @override
  String get settingsUnlockMethodSegmentNone => '無';

  @override
  String get settingsUnlockMethodSegmentDeviceLock => '螢幕鎖';

  @override
  String get settingsUnlockMethodSegmentBiometric => '生物驗證';

  @override
  String get settingsUnlockModeChangeCancelled => '已取消變更，解鎖方式維持不變。';

  @override
  String get settingsUnlockModeChangeAuthFailed => '驗證失敗，解鎖方式維持不變。';

  @override
  String get settingsUnlockModeDescriptionNone =>
      '鎖定後不額外驗證，直接解鎖。適合尚未設定螢幕鎖的裝置，安全性較低。';

  @override
  String get settingsUnlockModeDescriptionDeviceLock =>
      '鎖定後以螢幕鎖（PIN、圖案或密碼）驗證。請先在裝置設定中建立螢幕鎖。';

  @override
  String get settingsUnlockModeDescriptionBiometric =>
      '鎖定後優先使用指紋或臉部驗證；須先設定螢幕鎖並登錄生物辨識。若取消或失敗，可改以螢幕鎖解鎖，不必輸入復原金鑰。';

  @override
  String settingsSessionTimeoutBackgroundLockExplanation(String timeoutLabel) {
    return 'App 放在背景超過 $timeoutLabel 會自動鎖定；如果只是短時間切換 App，通常不會。';
  }

  @override
  String settingsSessionTimeoutAboutBackgroundTimeoutBody(String timeoutLabel) {
    return 'App 在背景超過 $timeoutLabel 後會自動鎖定；短暫切換通常不會。您可在「個人化」調整時間。備份、還原或匯入匯出進行中會暫停自動鎖定。';
  }

  @override
  String get settingsImportExportSectionTitle => '匯入與匯出';

  @override
  String get settingsImportExportSectionDescriptionEnabled =>
      '可從其他 App 或檔案匯入日記，也可把正式內容匯出成檔案。支援 Markdown、HTML 與 Easy Diary 備份。';

  @override
  String get settingsImportExportImportNoEntriesMessage => '找不到可匯入的日記，請確認檔案格式。';

  @override
  String get settingsImportExportExportNoEntriesMessage => '目前沒有可匯出的日記。';

  @override
  String get settingsImportExportPrepareProgress => '正在讀取與解析檔案…';

  @override
  String get settingsImportExportImportAllSkippedMessage =>
      '所選檔案皆無法匯入（格式不符、內容空白，或 Easy Diary 加密日記）。';

  @override
  String get settingsImportExportFailureSelectedFilesUnreadable =>
      '所選檔案無法讀取，請改用本機檔案或重新選取。';

  @override
  String get settingsImportExportFailureZipNoEntries =>
      'ZIP 內找不到可匯入的 Markdown、HTML 或 Easy Diary 完整備份。';

  @override
  String get settingsImportExportFailureEasyDiaryRealmReadFailed =>
      '無法讀取 Easy Diary 備份，可能版本不相容。請在 Easy Diary 重新建立備份後再試。';

  @override
  String get settingsImportExportFailureEasyDiaryEmptyBackup =>
      'Easy Diary 備份檔內沒有可匯入的日記。';

  @override
  String get settingsImportExportFailureEasyDiaryAllEncrypted =>
      'Easy Diary 備份內的日記皆為加密狀態，無法匯入。';

  @override
  String get settingsImportExportImportProgress => '正在匯入日記，請稍候…';

  @override
  String get settingsImportExportExportButton => '匯出日記';

  @override
  String get settingsImportExportImportButton => '匯入日記';

  @override
  String get settingsImportExportExportProgress => '正在匯出日記，整理內容與附件中…';

  @override
  String settingsImportExportExportSuccess(String path) {
    return '已匯出：$path';
  }

  @override
  String settingsImportExportImportSuccess(int count) {
    return '已匯入 $count 篇日記。';
  }

  @override
  String settingsImportExportImportSuccessWithSkippedFiles(
    int count,
    int skippedFiles,
  ) {
    return '已匯入 $count 篇日記，$skippedFiles 個檔案無法解析。';
  }

  @override
  String settingsImportExportImportSuccessWithSkippedAttachments(
    int count,
    int skippedAttachments,
  ) {
    return '已匯入 $count 篇日記，$skippedAttachments 張圖片無法匯入。';
  }

  @override
  String settingsImportExportImportSuccessWithSkippedFilesAndAttachments(
    int count,
    int skippedFiles,
    int skippedAttachments,
  ) {
    return '已匯入 $count 篇日記，$skippedFiles 個檔案無法解析，$skippedAttachments 張圖片無法匯入。';
  }

  @override
  String get settingsLocalBackupSectionTitle => '本機備份與還原';

  @override
  String get settingsLocalBackupSectionDescriptionEnabled =>
      '建立完整本機備份，還原時會以備份內容取代目前日記庫。（本機最多保留 5 份）';

  @override
  String get settingsLocalBackupCreateButton => '建立本機備份';

  @override
  String get settingsLocalBackupRestoreButton => '從本機備份還原';

  @override
  String get settingsLocalBackupExportToExternalButton => '匯出備份到資料夾';

  @override
  String get settingsLocalBackupImportFromExternalButton => '匯入外部備份';

  @override
  String get settingsLocalBackupPickDialogTitle => '選擇本機備份';

  @override
  String get settingsLocalBackupPickExternalBackupDialogTitle => '選擇備份 ZIP';

  @override
  String get settingsLocalBackupNoBackups => '目前沒有本機備份。';

  @override
  String get settingsLocalBackupDeleteBackupTooltip => '刪除備份';

  @override
  String get settingsLocalBackupDeleteConfirmTitle => '刪除本機備份？';

  @override
  String settingsLocalBackupBackupSuccessInApp(String fileName) {
    return '已建立本機備份：$fileName';
  }

  @override
  String settingsLocalBackupBackupExportSuccess(String fileName) {
    return '已匯出備份：$fileName';
  }

  @override
  String settingsLocalBackupBackupInspectFailed(String message) {
    return '備份檢查未通過。\n$message';
  }

  @override
  String settingsLocalBackupDeleteBackupSuccess(String fileName) {
    return '已刪除本機備份：$fileName';
  }

  @override
  String settingsLocalBackupDeleteConfirmBody(String fileName) {
    return '將刪除 $fileName。此動作不會影響目前日記庫。';
  }

  @override
  String get settingsDriveBackupSectionTitle => 'Google Drive 備份與還原';

  @override
  String get settingsDriveBackupSectionDescriptionEnabled =>
      '連結 Google 帳戶後，可建立 Google Drive 備份，或從 Google Drive 備份還原；還原時會以備份內容取代目前日記庫。上傳會在背景完成，可切換 App；請勿強制停止本 App。（Google Drive 最多保留 5 份）';

  @override
  String get settingsDriveBackupSectionDescriptionOAuthNotConfigured =>
      '此版本尚未設定 Google 登入，暫無法使用 Google Drive 備份。';

  @override
  String get settingsDriveBackupLinkButton => '連結 Google 帳戶';

  @override
  String get settingsDriveBackupSwitchAccountButton => '切換帳戶';

  @override
  String get settingsDriveBackupDisconnectButton => '中斷連結';

  @override
  String get settingsDriveBackupUploadButton => '備份到 Google Drive';

  @override
  String get settingsDriveBackupRestoreButton => '從 Google Drive 還原';

  @override
  String get settingsDriveBackupDisconnectedLabel => '尚未連結 Google 帳戶';

  @override
  String get settingsDriveBackupConnectionErrorLabel => '無法讀取 Google 連線狀態';

  @override
  String get settingsDriveBackupConnectionRetryButton => '重新載入';

  @override
  String get settingsDriveBackupFallbackAccountLabel => 'Google 帳戶';

  @override
  String get settingsDriveBackupLinkSuccessEmpty => 'Google 帳戶已連結，可以開始備份或還原。';

  @override
  String settingsDriveBackupLinkSuccess(String accountLabel) {
    return 'Google 帳戶已連結：$accountLabel';
  }

  @override
  String get settingsDriveBackupSwitchAccountSuccessEmpty => '已切換 Google 帳戶。';

  @override
  String settingsDriveBackupSwitchAccountSuccess(String accountLabel) {
    return '已切換為 $accountLabel';
  }

  @override
  String get settingsDriveBackupDisconnectSuccess =>
      '已中斷 Google 帳戶連線，Google Drive 備份仍會保留。';

  @override
  String get settingsDriveBackupDisconnectConfirmTitle => '中斷 Google 帳戶連線？';

  @override
  String get settingsDriveBackupDisconnectConfirmBody =>
      '中斷後需重新連結才能備份或還原。雲端上的備份檔不會被刪除。';

  @override
  String settingsDriveBackupUploadSuccess(String fileName) {
    return '已備份到 Google Drive：$fileName';
  }

  @override
  String settingsDriveBackupBackupInspectFailed(String message) {
    return 'Google Drive 備份未完成。\n$message';
  }

  @override
  String get settingsDriveBackupNoBackups => 'Google Drive 目前沒有可用備份，請先建立一份。';

  @override
  String get settingsDriveBackupPickDialogTitle => '選擇 Google Drive 備份';

  @override
  String get settingsDriveBackupUnknownCreatedTime => '無建立時間';

  @override
  String get settingsDriveBackupDeleteBackupTooltip => '刪除備份';

  @override
  String get settingsDriveBackupDeleteConfirmTitle => '刪除 Google Drive 備份？';

  @override
  String settingsDriveBackupDeleteBackupSuccess(String fileName) {
    return '已從 Google Drive 刪除：$fileName';
  }

  @override
  String settingsDriveBackupDeleteConfirmBody(String fileName) {
    return '將刪除 $fileName。此動作不會影響目前日記庫。';
  }

  @override
  String settingsDriveBackupRestoreSuccess(String fileName) {
    return '已從 Google Drive 還原：$fileName';
  }

  @override
  String get settingsBackupPhasePreparingDriveUpload =>
      '正在建立備份，完成前請保持 Quill Diary 顯示在畫面上…';

  @override
  String get driveUploadBackgroundStarted =>
      '已在背景上傳到 Google Drive。可切換到其他 App 或鎖定螢幕；請勿在系統設定中強制停止 App。若上傳服務被系統終止，請重新開啟 App 後再備份。';

  @override
  String get driveUploadNotificationsDeniedHint =>
      '未允許通知時，通知欄不會顯示進度與停止按鈕，請回 App 查看上傳狀態。';

  @override
  String driveUploadStatusUploading(String fileName, int percent) {
    return '正在背景上傳：$fileName（$percent%）';
  }

  @override
  String driveUploadStatusStaged(String fileName) {
    return '正在準備背景上傳：$fileName';
  }

  @override
  String driveUploadStatusWaitingNetwork(String fileName) {
    return '等待網路後繼續上傳：$fileName';
  }

  @override
  String get driveUploadStatusFinalizing => 'Google Drive 備份已上傳，正在完成收尾…';

  @override
  String get driveUploadStatusCancelCleanup => '正在清除未完成的 Google Drive 備份…';

  @override
  String driveUploadStatusCancelCleanupNeedsReauth(String accountEmail) {
    return '清除未完成備份需要重新連結 Google 帳戶（$accountEmail）。';
  }

  @override
  String driveUploadStatusCancelCleanupAccountMismatch(String accountEmail) {
    return '目前 Google 帳戶與上傳時不符。請連回 $accountEmail 完成清理，或放棄清理。';
  }

  @override
  String get driveUploadCancelButton => '取消上傳';

  @override
  String get driveUploadCancelConfirmTitle => '取消 Google Drive 上傳？';

  @override
  String get driveUploadCancelConfirmBody => '將停止目前的背景上傳。已建立的暫存備份會被清除。';

  @override
  String get driveUploadBusyBlocksAccountActions =>
      '上傳進行中，請先完成或取消後再變更 Google 帳戶。';

  @override
  String get driveUploadCancelCleanupBlocksAccountActions =>
      '正在清除未完成的 Google Drive 備份。若授權失效，請重新連結原帳號，或放棄清理。';

  @override
  String get driveUploadAbandonCancelCleanupButton => '放棄清理';

  @override
  String get driveUploadAbandonCancelCleanupConfirmTitle => '放棄清除未完成的備份？';

  @override
  String get driveUploadAbandonCancelCleanupConfirmBody =>
      '將解除本機鎖定，之後可重新備份或變更 Google 帳戶。Google Drive 上可能留下未完成的殘檔，且不會當成成功備份。';

  @override
  String get driveUploadAbandonedFailureTitle => 'Google Drive 備份失敗';

  @override
  String get driveUploadAbandonedFailureBody =>
      '上次 Google Drive 備份未完成，已取消。請重新備份。';

  @override
  String get driveUploadAbandonedFailureConfirm => '知道了';

  @override
  String get settingsSecurityOverviewDriveUploadInProgress =>
      '正在上傳到 Google Drive';

  @override
  String get settingsSecurityOverviewDriveUploadPending =>
      'Google Drive 上傳尚未完成';

  @override
  String get settingsRestoreDialogConfirmLocalTitle => '還原本機備份？';

  @override
  String get settingsRestoreDialogConfirmDriveTitle => '從 Google Drive 還原？';

  @override
  String get settingsRestoreConfirmOverwriteHeadline => '現有資料將被取代。還原後請依提示完成解鎖。';

  @override
  String get settingsRestoreConfirmFreshVaultHeadline => '將以備份內容建立日記庫。';

  @override
  String get settingsRestoreConfirmOverwriteAcknowledgeCheckbox =>
      '我了解現有日記將被備份覆蓋，且無法復原。';

  @override
  String get settingsRestorePrecheckSameVaultTitle => '同一日記庫';

  @override
  String get settingsRestorePrecheckSameVaultBody => '此備份與本機為同一日記庫。';

  @override
  String get settingsRestorePrecheckOtherVaultTitle => '其他裝置備份';

  @override
  String get settingsRestorePrecheckOtherVaultBody => '此備份來自其他裝置或不同日記庫。';

  @override
  String get settingsRestorePrecheckRotatedTitle => '復原金鑰已更新';

  @override
  String get settingsRestorePrecheckRotatedBody =>
      '此備份在更新復原金鑰之前建立，需使用當時保存的舊金鑰。';

  @override
  String get settingsRestorePrecheckTrustedUnlockTitle => '可能自動解鎖';

  @override
  String get settingsRestorePrecheckTrustedUnlockBody =>
      '若備份與本機使用同一把復原金鑰，還原後通常可直接使用。';

  @override
  String get settingsRestorePrecheckRecoveryKeyTitle => '還原後需輸入復原金鑰';

  @override
  String get settingsRestorePrecheckRecoveryKeyBody => '請準備建立此備份時保存的復原金鑰。';

  @override
  String get settingsRestorePrecheckHintTitle => '金鑰提示';

  @override
  String get settingsRestorePrecheckRebuildIndexTitle => '重建搜尋索引';

  @override
  String get settingsRestorePrecheckRebuildIndexBody => '搜尋索引會在解鎖後重新建立。';

  @override
  String get settingsRestorePrecheckRewrapTitle => '首次解鎖可能較久';

  @override
  String get settingsRestorePrecheckRewrapBody => '還原後首次解鎖可能需要較久，請保持 App 開啟。';

  @override
  String settingsRestoreDialogDriveFileLine(String name) {
    return '備份：$name';
  }

  @override
  String get settingsRestoreDialogRecoveryKeyTitle => '輸入備份復原金鑰';

  @override
  String get settingsRestoreDialogRecoveryKeyEmptyError => '請輸入復原金鑰。';

  @override
  String get settingsRestoreDialogRecoveryKeyVerifyNote =>
      '金鑰正確才會開始還原；錯誤則不會覆寫本機資料。';

  @override
  String get settingsRestoreDialogSubtitleRotatedBackup =>
      '此備份在更新復原金鑰之前建立。請輸入建立該備份時保存的舊金鑰，不是目前這把新金鑰。';

  @override
  String get settingsRestoreDialogSubtitleSameVaultManual =>
      '本機無法自動解鎖此備份。請輸入建立此備份時保存的復原金鑰。';

  @override
  String get settingsRestoreDialogSubtitleOtherVault =>
      '此備份來自其他裝置。請輸入建立此備份時保存的復原金鑰。';

  @override
  String get settingsRestoreBulletOverwriteWarning => '將以備份內容覆蓋本機日記，現有資料無法復原。';

  @override
  String get settingsRestoreBulletFreshVaultNote => '將以備份內容建立日記庫。';

  @override
  String get settingsRestoreBulletRebuildIndex => '搜尋索引會在解鎖後重新建立。';

  @override
  String get settingsRestoreBulletRotatedBackup =>
      '此備份在更新復原金鑰之前建立。還原後請輸入建立該備份時保存的舊復原金鑰，不是目前這把新金鑰。';

  @override
  String get settingsRestoreBulletTrustedAutoUnlock =>
      '若備份與本機使用同一把復原金鑰，還原後通常可直接使用。';

  @override
  String get settingsRestoreBulletTrustedAutoUnlockFallback =>
      '若無法直接解鎖，請輸入建立此備份時保存的復原金鑰。';

  @override
  String get settingsRestoreBulletRecoveryKeyAfterRestore =>
      '還原後需輸入建立此備份時保存的復原金鑰。';

  @override
  String get settingsRestoreBulletRewrapNote => '還原後首次解鎖可能需要較久，請保持 App 開啟。';

  @override
  String get settingsRepairVaultReadyMessage => '可隨時檢查並整理日記庫。';

  @override
  String get settingsRepairVaultLockedMessage => '解鎖後即可檢查日記庫。';

  @override
  String get settingsInspectVaultConfirmTitle => '檢查日記庫';

  @override
  String get settingsInspectVaultConfirmBody => '開始檢查前，可先確認上次修復紀錄。';

  @override
  String get settingsInspectVaultConfirmButton => '開始檢查';

  @override
  String get settingsInspectVaultPreflightCurrent => '目前狀態';

  @override
  String settingsInspectVaultPreflightTime(String finishedAt) {
    return '時間：$finishedAt';
  }

  @override
  String get settingsInspectVaultPreflightSourceInspect => '來源：檢查';

  @override
  String get settingsInspectVaultPreflightSourceRepair => '來源：修復';

  @override
  String settingsInspectVaultPreflightEntries(int count) {
    return '影響日記：$count 篇';
  }

  @override
  String get settingsInspectVaultPreflightLastRepair => '上次修復';

  @override
  String get settingsInspectVaultPreflightNoRepair => '尚未執行過修復。';

  @override
  String get settingsRepairDetailCompleted => '已完成';

  @override
  String get settingsRepairDetailGlobal => '全域清理';

  @override
  String get settingsRepairDetailUnresolved => '仍需處理';

  @override
  String get settingsRepairDetailAggregateFallback =>
      '此紀錄只保存彙總資料，逐篇明細會從下一次修復開始提供。';

  @override
  String settingsRepairDetailPurgedOldQuarantine(int count) {
    return '已清除舊隔離檔：$count';
  }

  @override
  String get settingsLastRepairLogEmpty => '尚未執行過修復。';

  @override
  String settingsLastRepairLogFinishedAt(String finishedAt) {
    return '上次修復時間：$finishedAt';
  }

  @override
  String settingsLastRepairLogCheckedEntries(int entryCount) {
    return '當時檢查 $entryCount 篇日記。';
  }

  @override
  String settingsLastRepairLogBackupFile(String fileName) {
    return '修復前備份：$fileName';
  }

  @override
  String settingsLastRepairLogRelocatedEntries(int count) {
    return '已移回正確位置的日記：$count';
  }

  @override
  String settingsLastRepairLogRelocatedAssets(int count) {
    return '已移回正確位置的附件：$count';
  }

  @override
  String settingsLastRepairLogRecoveredAttachments(int count) {
    return '已從可驗證副本恢復的附件：$count';
  }

  @override
  String settingsLastRepairLogRemovedBrokenReferences(int count) {
    return '已移除失效附件引用：$count';
  }

  @override
  String settingsLastRepairLogSplitAttachments(int count) {
    return '已拆分共用附件：$count';
  }

  @override
  String settingsLastRepairLogRemovedDuplicates(int count) {
    return '已移除重複日記檔：$count';
  }

  @override
  String settingsLastRepairLogRemovedOrphans(int count) {
    return '已移除孤立附件：$count';
  }

  @override
  String settingsLastRepairLogQuarantined(int count) {
    return '已隔離異常檔：$count';
  }

  @override
  String settingsLastRepairLogPurgedBadAssets(int count) {
    return '已清除損壞附件：$count';
  }

  @override
  String settingsLastRepairLogUnresolved(int count) {
    return '仍未解決：$count 篇';
  }

  @override
  String get settingsLastRepairLogNoActions => '當時沒有需要自動處理的項目。';

  @override
  String get settingsRepairDetailButton => '詳細資料';

  @override
  String get settingsRepairDetailTitle => '修復詳細資料';

  @override
  String get settingsRepairDetailEmpty => '沒有可顯示的逐篇修復紀錄。';

  @override
  String settingsRepairDetailGlobalOrphans(int count) {
    return '已清除孤立附件：$count';
  }

  @override
  String settingsRepairDetailGlobalPurgedBad(int count) {
    return '已清除損壞附件：$count';
  }

  @override
  String settingsRepairDetailRecoveredAttachments(int count) {
    return '已自動恢復圖片：$count';
  }

  @override
  String settingsRepairDetailRemovedMissingAttachments(int count) {
    return '已移除遺失圖片引用：$count';
  }

  @override
  String settingsRepairDetailPurgedBadAttachments(int count) {
    return '已清除損壞圖片：$count';
  }

  @override
  String settingsRepairDetailSplitAttachments(int count) {
    return '已拆分共用附件：$count';
  }

  @override
  String settingsRepairDetailRelocatedEntries(int count) {
    return '已整理日記檔：$count';
  }

  @override
  String settingsRepairDetailQuarantinedItems(int count) {
    return '已隔離異常檔：$count';
  }

  @override
  String settingsRepairDetailCleanupFailures(int count) {
    return '自動處理失敗：$count';
  }

  @override
  String get settingsMaintenanceProgressTitle => '正在處理日記庫…';

  @override
  String get settingsInspectVaultProgressScanningEntries => '正在檢查日記…';

  @override
  String get settingsInspectVaultProgressCheckingAttachments => '正在檢查附件…';

  @override
  String get settingsInspectVaultProgressRebuildingIndex => '正在整理搜尋資料…';

  @override
  String get settingsInspectVaultProgressRebuildingPeople => '正在更新人物資料…';

  @override
  String get settingsInspectVaultResultTitle => '檢查完成';

  @override
  String get settingsInspectVaultResultClean => '目前狀態良好。';

  @override
  String settingsInspectVaultResultWarning(int count) {
    return '發現 $count 篇日記需要處理。修復會先建立並驗證本機備份，再整理可修復的項目。';
  }

  @override
  String settingsInspectVaultResultCheckedEntries(int entryCount) {
    return '已檢查 $entryCount 篇日記。';
  }

  @override
  String get settingsInspectVaultHandleLaterButton => '稍後處理';

  @override
  String get settingsInspectVaultRepairAfterBackupButton => '備份後修復';

  @override
  String get settingsInspectVaultUnrecognizedEntry => '無法辨識的日記';

  @override
  String get settingsInspectVaultEntryDateUnknown => '日期不明';

  @override
  String get settingsInspectVaultPlannedQuarantine => '預計隔離無法確認的資料';

  @override
  String get settingsInspectVaultPlannedRemoveReference => '預計移除失效附件引用';

  @override
  String get settingsInspectVaultPlannedSplitAttachment => '預計拆分共用附件';

  @override
  String get settingsInspectVaultPlannedRelocate => '預計移回正確位置';

  @override
  String get settingsInspectVaultPlannedDeleteDuplicate => '預計清理重複檔';

  @override
  String get settingsInspectVaultPlannedNone => '需進一步確認';

  @override
  String get settingsRepairVaultProgressCreatingBackup => '正在建立修復前備份…';

  @override
  String get settingsRepairVaultProgressRepairingEntries => '正在修復日記…';

  @override
  String get settingsRepairVaultProgressRepairingAttachments => '正在整理附件…';

  @override
  String get settingsRepairVaultProgressUpdatingSearch => '正在更新搜尋資料…';

  @override
  String get settingsRepairVaultProgressScanningEntries => '正在檢查日記…';

  @override
  String get settingsRepairVaultProgressCheckingAttachments => '正在檢查附件…';

  @override
  String get settingsRepairVaultProgressRebuildingIndex => '正在整理搜尋資料…';

  @override
  String get settingsRepairVaultProgressRebuildingPeople => '正在更新人物資料…';

  @override
  String get settingsRepairVaultProgressCleaning => '正在完成整理…';

  @override
  String get settingsRepairVaultResultTitle => '修復完成';

  @override
  String get settingsRepairVaultResultClean => '日記庫已修復完成，目前狀態良好。';

  @override
  String settingsRepairVaultResultWarning(int count) {
    return '修復已完成，但有 $count 篇日記尚未解決。可手動修復可讀內容，或永久刪除無法復原的檔案。';
  }

  @override
  String settingsRepairVaultResultCheckedEntries(int entryCount) {
    return '已檢查 $entryCount 篇日記。';
  }

  @override
  String settingsRepairVaultResultIssueCount(String label, int count) {
    return '$label：$count 個';
  }

  @override
  String settingsRepairVaultResultQuarantinedCount(int count) {
    return '已隔離 $count 項。';
  }

  @override
  String settingsRepairVaultResultBackupFile(String fileName) {
    return '修復前備份：$fileName';
  }

  @override
  String get settingsRepairVaultResultMissingAttachment => '附件已遺失';

  @override
  String get settingsRepairVaultResultSalvageButton => '手動修復';

  @override
  String get settingsRepairVaultResultSalvageFailed =>
      '無法取出可讀內容，請改用永久刪除或從備份還原。';

  @override
  String get settingsRepairVaultBackupFailed => '修復前備份失敗，已中止修復，正式資料未變更。';

  @override
  String get settingsRepairVaultBackupCancelled => '已取消修復前備份，未進行修復。';

  @override
  String settingsRepairVaultBackupInspectFailed(String message) {
    return '修復前備份驗證失敗：$message';
  }

  @override
  String get settingsRepairIssueInvalidEntryMetadata => '部分日記資料不完整';

  @override
  String get settingsRepairIssueUnreadableEntry => '部分日記無法開啟';

  @override
  String get settingsRepairIssueEntryIdentityMismatch => '部分日記資料需要確認';

  @override
  String get settingsRepairIssueConflictingEntry => '發現內容不同的重複日記';

  @override
  String get settingsRepairIssueMissingAsset => '有附件找不到';

  @override
  String get settingsRepairIssueUnreadableAsset => '有附件無法開啟';

  @override
  String get settingsRepairIssueAssetIdentityMismatch => '有附件內容異常';

  @override
  String get settingsRepairIssueConflictingAsset => '發現內容不同的重複附件';

  @override
  String get settingsRepairIssueUnverifiedOrphanAsset => '有附件無法確認所屬日記';

  @override
  String get settingsRepairIssueCleanupFailure => '部分檔案尚未整理完成';

  @override
  String get settingsUnlockRequiredToChangeSettingMessage => '解鎖後可調整此設定。';

  @override
  String get settingsIndexLinkDriveProgress => '正在連結 Google 帳戶…';

  @override
  String get settingsIndexSwitchDriveAccountProgress => '正在切換帳戶…';

  @override
  String get settingsIndexDisconnectDriveProgress => '正在中斷連線…';

  @override
  String settingsInspectVaultCompleted(int entryCount, String finishedAt) {
    return '最近一次檢查：$finishedAt。已檢查 $entryCount 篇日記，未發現異常。';
  }

  @override
  String settingsInspectVaultCompletedWithIssues(
    int issueCount,
    String finishedAt,
  ) {
    return '最近一次檢查：$finishedAt。$issueCount 篇日記需要處理。';
  }

  @override
  String settingsRepairVaultCompleted(int entryCount, String finishedAt) {
    return '最近一次修復：$finishedAt。已檢查 $entryCount 篇日記，未發現異常。';
  }

  @override
  String settingsRepairVaultCompletedWithIssues(
    int issueCount,
    String finishedAt,
  ) {
    return '最近一次修復：$finishedAt。$issueCount 篇日記需要處理。';
  }

  @override
  String get settingsAbnormalEntriesPageTitle => '異常日記';

  @override
  String get settingsAbnormalEntriesEmpty => '目前沒有未解決的異常。';

  @override
  String get settingsAbnormalEntriesDeleteButton => '永久刪除';

  @override
  String get settingsAbnormalEntriesDeleteConfirmTitle => '永久刪除這些檔案？';

  @override
  String get settingsAbnormalEntriesDeleteConfirmBody =>
      '將永久刪除與此異常相關的正式檔案，無法復原。若仍需要內容，請先用本機備份還原。';

  @override
  String get settingsAbnormalEntriesDeleteSuccess => '已永久刪除相關檔案。';

  @override
  String get settingsAbnormalEntriesDeleteFailed => '刪除失敗，請稍後再試。';

  @override
  String get settingsAbnormalEntriesAttachmentPhoto => '照片';

  @override
  String get settingsAbnormalEntriesAttachmentFile => '附件';

  @override
  String get settingsSupportNavButtonLabel => '支持';

  @override
  String get settingsSupportPageTitle => '支持開發者';

  @override
  String get settingsSupportHeroTitle => '喜歡的話，歡迎支持';

  @override
  String get settingsSupportHeroBody =>
      '如果 Quill Diary 對您有幫助，您可以透過 Google Play 提供一次性支持。這不會解鎖額外功能，也不影響日記內容的存取與使用。';

  @override
  String get settingsSupportHeroChipNoExtraFeatures => '不解鎖額外功能';

  @override
  String get settingsSupportHeroChipRepeatablePurchase => '可再次支持';

  @override
  String get settingsSupportHeroChipGooglePlayPayment => 'Google Play 付款';

  @override
  String get settingsSupportComplianceCardTitle => '支持與資料說明';

  @override
  String get settingsSupportComplianceCardBody =>
      '支持付款由 Google Play 處理，屬一次性支持，非訂閱或會員方案。本應用程式不保存支持紀錄，也不讀取日記內容。';

  @override
  String get settingsSupportProductsSectionTitle => '支持選項';

  @override
  String get settingsSupportProductsSectionBody =>
      'Google Play 會依所在地區顯示各支持選項的標題、說明與金額。';

  @override
  String get settingsSupportBuyButtonPrefix => '支持';

  @override
  String get settingsSupportPendingMessage => '付款處理中，請稍候。';

  @override
  String get settingsSupportThanksMessage => '謝謝您的支持，這對開發很有幫助。';

  @override
  String get settingsSupportErrorMessage => '付款未完成，請稍後再試。';

  @override
  String get settingsSupportBillingUnavailableMessage =>
      '目前無法使用 Google Play 結帳，請確認已安裝 Google Play 商店且 Google Play 服務運作正常。';

  @override
  String get settingsSupportProductLoadErrorTitle => '暫時無法載入支持選項';

  @override
  String get settingsSupportProductLoadErrorBody => '請稍後再試。';

  @override
  String get settingsSupportProductsNotReadyTitle => '暫時無法顯示支持選項';

  @override
  String get settingsSupportProductsNotReadyBody =>
      '請確認網路連線正常；若問題持續，請更新本應用程式後再試。';

  @override
  String get settingsSupportProductsInitFailedTitle => '無法啟動 Google Play 結帳';

  @override
  String get settingsSupportProductsInitFailedBody =>
      '請確認 Google Play 服務正常後再試。';

  @override
  String get settingsSupportProductsQueryFailedTitle => '目前無法連線至 Google Play';

  @override
  String get settingsSupportProductsQueryFailedBody => '請確認網路連線後再試。';

  @override
  String get settingsSupportProductsPartialMessage => '部分方案暫時無法顯示，您仍可選擇其他可用金額。';

  @override
  String get settingsSupportRetryLoadProductsLabel => '重新載入';

  @override
  String get settingsSupportFooterNote => '支持完全自願，請依您的需求與意願決定。';

  @override
  String get sessionStartupNeedsRecoveryKeyMessage =>
      '尚未建立復原金鑰。復原金鑰是保護整個日記庫的重要依據，請先建立並妥善保存，這樣換機、還原或裝置失效時，才可以重新進入日記庫。';

  @override
  String get sessionStartupNeedsTrustedDeviceMessage => '這台裝置尚未授權，請使用復原金鑰解鎖。';

  @override
  String get sessionUnlockFailedMessage => '解鎖失敗，請再試一次。';

  @override
  String get sessionRecoveryUnlockSuccessMessage => '已使用復原金鑰解鎖。';

  @override
  String get sessionRecoverySetupSuccessMessage => '復原金鑰已建立，現在可以設定解鎖方式。';

  @override
  String get sessionAppLockedMessage => '應用程式已鎖定。';

  @override
  String get sessionTrustedUnlockInProgressMessage => '正在以可信裝置解鎖…';

  @override
  String get sessionLockedRetryVerificationMessage =>
      '目前已鎖定。請重新完成裝置驗證，不必輸入復原金鑰。';

  @override
  String get sessionRecoveryKeyRotatedMessage => '復原金鑰已更新，請立即保存新金鑰。';

  @override
  String get sessionRecoveryRequiredAfterRestoreMessage =>
      '還原後需輸入建立此備份時保存的復原金鑰。';

  @override
  String get sessionInvalidBackupFileMessage => '無法讀取備份檔，請確認檔案未損壞且為有效的 ZIP 備份。';

  @override
  String get sessionRestoreSuccessUnlockedMessage => '已還原備份，可以正常使用。';

  @override
  String get sessionRestoreSuccessLockedMessage => '已還原備份。請完成生物驗證或螢幕鎖驗證以繼續。';

  @override
  String get sessionRestoreSuccessRecoveryRequiredMessage =>
      '已還原備份。請輸入建立此備份時保存的復原金鑰。';

  @override
  String get sessionRestoreStartupFailedMessage =>
      '已還原備份，但啟動失敗。請到設定頁重試或輸入復原金鑰。';

  @override
  String get postRestoreOutcomeTitle => '還原已完成';

  @override
  String get postRestoreOutcomeNextStepLocked => '目前還差一步：請完成生物驗證或螢幕鎖驗證。';

  @override
  String get postRestoreOutcomeNextStepRecovery => '目前還差一步：請輸入建立此備份時保存的復原金鑰。';

  @override
  String get postRestoreOutcomeSecondaryHint => '首次解鎖可能較久，搜尋索引也會重新建立。';

  @override
  String get postRestoreOutcomePrimaryRetryVerification => '立即重新驗證';

  @override
  String get postRestoreOutcomePrimaryEnterRecoveryKey => '立即輸入復原金鑰';

  @override
  String get postRestoreOutcomeUnlockFailedTitle => '還原後仍無法解鎖';

  @override
  String get sessionRecoveryKeyMismatchMessage =>
      '復原金鑰不正確。若為更新復原金鑰前的舊備份，請輸入建立該備份時保存的舊金鑰。';

  @override
  String get sessionTrustedUnlockFailedAfterRestoreMessage =>
      '還原後無法自動解鎖。請輸入建立此備份時保存的復原金鑰。';

  @override
  String get sessionIndexDatabaseUnreadableMessage =>
      '搜尋索引無法讀取，可能已損壞。請用復原金鑰重新解鎖；若仍失敗，可嘗試重新還原備份。';

  @override
  String get sessionUnlockModeNeedsDeviceLockMessage =>
      '請先在裝置設定中建立螢幕鎖，才能使用此模式。';

  @override
  String get sessionUnlockModeChangeNeedsUnlockMessage => '請先解鎖日記庫後，再變更解鎖方式。';

  @override
  String get sessionBiometricNotEnrolledSwitchModeMessage =>
      '裝置尚未登錄指紋或臉部。請先到系統設定完成生物辨識設定，或改用裝置螢幕鎖。';

  @override
  String get sessionUseDeviceLockToUnlockMessage => '請使用裝置螢幕鎖解鎖。';

  @override
  String get sessionNoneModeLockedMessage => '背景逾時，正在重新解鎖日記庫…';

  @override
  String get sessionKeystoreMigrationMayReverifyMessage =>
      '若系統再次要求驗證，請完成以更新解鎖設定。';

  @override
  String get sessionStartupNeedsBiometricMessage => '請先完成生物驗證。';

  @override
  String get legalPrivacyEffectiveDateLabel => '生效日期：2026 年 8 月 27 日';

  @override
  String get legalChildrenPrivacyOneLiner =>
      '本應用程式並非專為十三歲（含）以下兒童而設計，亦不故意蒐集兒童之個人資料。';

  @override
  String get legalBrandDisclaimer =>
      'Quill Diary 名稱、圖示與 Google Play 商店 listing 為作者品牌，不隨程式碼授權一併轉讓。';

  @override
  String get legalBillingVaultPrivacyNote => '支持流程不讀取日記庫內容。';

  @override
  String get legalBillingPrivacyOneLiner =>
      '支持開發者之付款由 Google Play 處理，屬自願性一次性支持，不解鎖任何額外功能；支持流程不讀取日記庫內容。';

  @override
  String get legalBillingSupportPageBody =>
      '僅透過 Google Play Billing 提供一次性支持，非訂閱、非會員；付款由 Google 處理，開發者不保存支持紀錄。支持流程不讀取日記庫內容。';

  @override
  String get legalExternalLinkUnavailableMessage => '無法開啟瀏覽器，請稍後再試。';

  @override
  String get settingsLegalSectionTitle => '法律與隱私';

  @override
  String get settingsLegalSectionDescription =>
      '可在 GitHub 查看原始碼、隱私政策與第三方聲明；有問題歡迎透過 Issues 聯絡。';

  @override
  String get settingsLegalSourceCodeTitle => 'GitHub 原始碼';

  @override
  String get settingsLegalPrivacyPolicyTitle => '隱私權政策';

  @override
  String get settingsLegalThirdPartyNoticesTitle => '第三方聲明';

  @override
  String get settingsLegalContactAuthorTitle => '聯絡作者';

  @override
  String get aboutPageTitle => '關於';

  @override
  String get aboutTabIntroLabel => '簡介';

  @override
  String get aboutTabIntroHeroTitle => '把私人日記留在自己手上';

  @override
  String get aboutTabIntroHeroBody =>
      'Quill Diary 是為個人記錄設計的本機加密日記 App，不需註冊帳號。建立並妥善保存復原金鑰後，就能開始寫日記、備份與匯出；除非您主動操作，資料預設留在裝置上。';

  @override
  String get aboutTabIntroChip0 => '資料留在裝置';

  @override
  String get aboutTabIntroChip1 => 'Markdown / HTML';

  @override
  String get aboutTabIntroChip2 => '全文搜尋';

  @override
  String get aboutTabIntroChip3 => '完整備份';

  @override
  String get aboutTabIntroChip4 => '可攜式匯出';

  @override
  String get aboutTabIntroSection0Title => '為什麼適合拿來寫日記';

  @override
  String get aboutTabIntroSection0Subtitle => '從資料保存方式到日常操作，都以個人記錄與隱私為核心。';

  @override
  String get aboutTabIntroSection0Item0Title => '本機加密保存';

  @override
  String get aboutTabIntroSection0Item0Body =>
      '日記、附件、人物名冊、草稿與搜尋索引預設留在裝置上並加密保存。復原設定與少部分輔助資料不另行加密，但仍存放在 App 私有空間。';

  @override
  String get aboutTabIntroSection0Item1Title => '不用註冊就能開始';

  @override
  String get aboutTabIntroSection0Item1Body =>
      '不需建立 Quill Diary 帳號。第一次使用時設定復原金鑰，即可開始讀寫日記；只有使用 Google Drive 時才需連結 Google 帳號。';

  @override
  String get aboutTabIntroSection0Item2Title => '少收集、少干擾';

  @override
  String get aboutTabIntroSection0Item2Body =>
      'App 不內嵌廣告或追蹤 SDK，也不會把日記明文上傳到開發者控制的伺服器。您可以把它當成以隱私為前提的私人寫作空間。';

  @override
  String get aboutTabIntroSection1Title => '您可以怎麼使用它';

  @override
  String get aboutTabIntroSection1Subtitle => '從當下記錄，到之後回顧整理，常用功能都圍繞個人日記情境設計。';

  @override
  String get aboutTabIntroSection1Item0Title => '寫下每天想記住的內容';

  @override
  String get aboutTabIntroSection1Item0Body =>
      '支援標題、日期、標籤、圖片與一般附件。新建日記可直接開始寫，既有日記也能先看再編輯；需要時也能把內容匯出成 Markdown 或 HTML。';

  @override
  String get aboutTabIntroSection1Item1Title => '用不同角度看自己的紀錄';

  @override
  String get aboutTabIntroSection1Item1Body =>
      '主畫面提供列表、日曆、標籤、人物與總覽五種入口。您可以依時間瀏覽、按日期回看，或從標籤、人物和統計整理自己的生活軌跡。';

  @override
  String get aboutTabIntroSection1Item2Title => '找回以前寫過的內容';

  @override
  String get aboutTabIntroSection1Item2Body =>
      '解鎖後可搜尋標題、標籤與內文，適合回頭找某段經歷、某個關鍵字，或快速整理某段時間的紀錄。';

  @override
  String get aboutTabIntroSection1Item3Title => '備份與匯出，各有用途';

  @override
  String get aboutTabIntroSection1Item3Body =>
      '完整備份用來還原整個日記庫；Markdown 或 HTML 則適合閱讀、整理與搬移內容。Google Drive 只是可選的完整備份存放位置，不是即時同步服務。';

  @override
  String get aboutTabIntroSection2Title => '資料掌控權在您手上';

  @override
  String get aboutTabIntroSection2Subtitle =>
      '備份、匯出與解鎖方式各自扮演不同角色，目的是讓您能保留資料，也能理解風險邊界。';

  @override
  String get aboutTabIntroSection2Item0Title => '可信裝置與復原金鑰';

  @override
  String get aboutTabIntroSection2Item0Body =>
      '日常可用螢幕鎖或生物辨識快速回到 App；換機、還原或可信狀態失效時，復原金鑰才是重新取得存取權的關鍵。';

  @override
  String get aboutTabIntroSection2Item1Title => '完整備份用來還原日記庫';

  @override
  String get aboutTabIntroSection2Item1Body =>
      '完整備份中的日記、附件與人物名冊維持加密，但 ZIP 外層與部分復原、標籤及釘選資料不另行加密。它適合完整還原，不是可直接閱讀的匯出文件。';

  @override
  String get aboutTabIntroSection2Item2Title => '匯出內容後要自行保護';

  @override
  String get aboutTabIntroSection2Item2Body =>
      'Markdown 與 HTML 匯出適合閱讀、整理與轉移內容，但它們屬於可讀文件，不再等同於 App 內的加密保存狀態。';

  @override
  String get aboutTabIntroSection3Title => '開源與品牌';

  @override
  String get aboutTabIntroSection3Subtitle => '您可以查看原始碼與授權條件，也能清楚知道品牌使用界線。';

  @override
  String get aboutTabIntroSection3Item0Title => 'AGPL-3.0-or-later 開源';

  @override
  String get aboutTabIntroSection3Item0Body =>
      '原始碼以 AGPL-3.0-or-later 發布，可公開檢視產品行為與實作方式。目前僅支援 Android。';

  @override
  String get aboutTabIntroSection3Item1Title => 'Quill Diary 品牌';

  @override
  String get aboutTabUnlockSessionLabel => '解鎖與安全';

  @override
  String get aboutTabUnlockSessionHeroTitle => '方便使用，也不放鬆資料保護';

  @override
  String get aboutTabUnlockSessionHeroBody =>
      '您可以選擇不額外驗證、裝置螢幕鎖或生物辨識。App 會依背景逾時與鎖定原因決定何時重新驗證；換機、還原或可信狀態失效時，則可能需要復原金鑰。';

  @override
  String get aboutTabUnlockSessionChip0 => '生物辨識';

  @override
  String get aboutTabUnlockSessionChip1 => '螢幕鎖';

  @override
  String get aboutTabUnlockSessionChip2 => '自動鎖定';

  @override
  String get aboutTabUnlockSessionChip3 => '復原金鑰';

  @override
  String get aboutTabUnlockSessionSection0Title => '解鎖方式怎麼選';

  @override
  String get aboutTabUnlockSessionSection0Subtitle =>
      '您可以依裝置習慣與想要的保護程度，在設定頁切換不同解鎖方式。';

  @override
  String get aboutTabUnlockSessionSection0Item0Title => '無';

  @override
  String get aboutTabUnlockSessionSection0Item0Body =>
      '因背景逾時鎖定後，回到 App 不需系統驗證即可恢復存取；手動鎖定後仍須按「重新驗證」。此模式方便，但保護力最低。';

  @override
  String get aboutTabUnlockSessionSection0Item1Title => '裝置螢幕鎖';

  @override
  String get aboutTabUnlockSessionSection0Item1Body =>
      '回到 App 時用 PIN、圖案或密碼重新驗證。適合想保留系統層保護，又不一定使用生物辨識的人。';

  @override
  String get aboutTabUnlockSessionSection0Item2Title => '生物辨識';

  @override
  String get aboutTabUnlockSessionSection0Item2Body =>
      '優先使用指紋或臉部驗證；依裝置與系統畫面，可能提供螢幕鎖作為後備方式。這通常是日常使用最方便的選擇。';

  @override
  String get aboutTabUnlockSessionSection0Item3Title => '共同前提';

  @override
  String get aboutTabUnlockSessionSection0Item3Body =>
      '螢幕鎖與生物驗證模式都要求裝置先設定好螢幕鎖；要使用生物辨識，也必須先在系統中完成登錄。';

  @override
  String get aboutTabUnlockSessionSection1Title => '什麼時候會重新驗證';

  @override
  String get aboutTabUnlockSessionSection1Subtitle =>
      '只有在有效解鎖期間，才能讀寫日記、草稿、附件與搜尋資料。';

  @override
  String get aboutTabUnlockSessionSection1Item0Title => '有效解鎖期間';

  @override
  String get aboutTabUnlockSessionSection1Item0Body =>
      '解鎖後即可讀寫日記、編輯草稿、加入附件及使用搜尋。尚未建立復原金鑰時，即使已進入主畫面，日記內容仍無法使用。';

  @override
  String get aboutTabUnlockSessionSection1Item1Title => '背景逾時';

  @override
  String get aboutTabUnlockSessionSection1Item2Title => '回到 App 時';

  @override
  String get aboutTabUnlockSessionSection1Item2Body =>
      '短暫切出去再回來，通常不會立刻要求重驗；背景超過設定時間後才回來，則依您選擇的模式決定是否重新驗證。鎖定只會暫停存取，不會刪除日記。';

  @override
  String get aboutTabUnlockSessionSection1Item3Title => '驗證取消或失敗後';

  @override
  String get aboutTabUnlockSessionSection1Item3Body =>
      '取消或未通過驗證時，App 會維持鎖定並停止自動重試；需要時可再按「重新驗證」。';

  @override
  String get aboutTabUnlockSessionSection1Item4Title => '手動鎖定時';

  @override
  String get aboutTabUnlockSessionSection1Item4Body =>
      '從設定手動鎖定後，切回 App 需自行按「重新驗證」，不會自動解鎖。';

  @override
  String get aboutTabUnlockSessionSection2Title => '為什麼還需要復原金鑰';

  @override
  String get aboutTabUnlockSessionSection2Subtitle =>
      '螢幕鎖與生物辨識方便日常使用；換機、還原或可信狀態失效時，仍可能需要復原金鑰。';

  @override
  String get aboutTabUnlockSessionSection2Item0Title => '換機或重設後';

  @override
  String get aboutTabUnlockSessionSection2Item0Body =>
      '當您換手機、清除 App 資料，或要在另一台裝置上恢復日記庫時，可信裝置狀態通常不會跟著過去，這時就需要復原金鑰。';

  @override
  String get aboutTabUnlockSessionSection2Item1Title => '可信狀態失效';

  @override
  String get aboutTabUnlockSessionSection2Item1Body =>
      '可信狀態失效或與日記庫不符時，不能只靠本機快速進入，需改用復原金鑰。';

  @override
  String get aboutTabUnlockSessionSection2Item2Title => '請妥善保存';

  @override
  String get aboutTabUnlockSessionSection2Item2Body =>
      '復原金鑰是換機、還原或可信裝置失效時重新取得存取權的重要憑證。遺失後可能無法恢復日記庫，請另外保存在安全位置。';

  @override
  String get aboutTabEncryptionLabel => '資料加密';

  @override
  String get aboutTabEncryptionHeroTitle => '資料預設以加密形式保存';

  @override
  String get aboutTabEncryptionHeroBody =>
      '正式日記、附件、人物名冊與草稿會以 LDJ2 格式和 AES-256-GCM 加密，搜尋索引也會另外加密。只有在有效解鎖期間，App 才能讀寫這些內容。';

  @override
  String get aboutTabEncryptionChip0 => '本機加密';

  @override
  String get aboutTabEncryptionChip1 => '加密檔案';

  @override
  String get aboutTabEncryptionChip2 => '內容加密';

  @override
  String get aboutTabEncryptionChip3 => '金鑰保護';

  @override
  String get aboutTabEncryptionChip4 => '可信裝置';

  @override
  String get aboutTabEncryptionChip5 => '裝置安全儲存';

  @override
  String get aboutTabEncryptionSection0Title => '這套保護機制在幫您做什麼';

  @override
  String get aboutTabEncryptionSection0Subtitle =>
      '內容寫入裝置前先加密，讀取時再透過目前有效的解鎖狀態開啟。';

  @override
  String get aboutTabEncryptionSection0Item0Title => '加密保存敏感內容';

  @override
  String get aboutTabEncryptionSection0Item0Body =>
      '正式日記、附件、人物名冊與草稿會以 AES-256-GCM 加密。即使取得檔案，也無法直接閱讀內容。';

  @override
  String get aboutTabEncryptionSection0Item1Title => '偵測異常就停止開啟';

  @override
  String get aboutTabEncryptionSection0Item1Body =>
      '加密檔案也帶有完整性驗證。若內容或檔頭遭到修改，解密會失敗，不會把無法驗證的資料當成正常內容。';

  @override
  String get aboutTabEncryptionSection0Item2Title => '不同檔案使用不同金鑰';

  @override
  String get aboutTabEncryptionSection0Item2Body =>
      '每個加密檔案都使用獨立產生的金鑰，避免所有內容共用同一把檔案金鑰。';

  @override
  String get aboutTabEncryptionSection1Title => '您可以怎麼打開自己的資料';

  @override
  String get aboutTabEncryptionSection1Subtitle =>
      '日常與緊急情況走的是不同入口，但最後都會回到同一套解密流程。';

  @override
  String get aboutTabEncryptionSection1Item0Title => '可信裝置';

  @override
  String get aboutTabEncryptionSection1Item0Body =>
      '日常可透過螢幕鎖或生物辨識重新進入；日記庫金鑰由裝置內建安全機制保護。';

  @override
  String get aboutTabEncryptionSection1Item1Title => '復原金鑰';

  @override
  String get aboutTabEncryptionSection1Item1Body =>
      '換機、還原備份或本機可信狀態失效時，可以用復原金鑰重新取得日記庫存取權。';

  @override
  String get aboutTabEncryptionSection1Item2Title => '先確認日記庫，再解開各檔';

  @override
  String get aboutTabEncryptionSection1Item2Body =>
      'App 會先確認您能正確進入日記庫，再開啟其中的檔案，避免把金鑰錯誤誤判成資料損壞。';

  @override
  String get aboutTabEncryptionSection2Title => '使用前要知道的邊界';

  @override
  String get aboutTabEncryptionSection2Subtitle =>
      '內容檔案會加密，但部分復原與輔助 metadata、可讀匯出及解鎖後的使用情境有不同風險。';

  @override
  String get aboutTabEncryptionSection2Item0Title => '匯出後不再是同一層保護';

  @override
  String get aboutTabEncryptionSection2Item0Body =>
      '只要您把內容匯出成 Markdown 或 HTML，可讀文件之後的存放與分享風險，就不再由 App 內的加密機制接手。';

  @override
  String get aboutTabEncryptionSection2Item1Title => '復原金鑰要自己保管';

  @override
  String get aboutTabEncryptionSection2Item1Body =>
      '復原金鑰是重新進入日記庫的重要依據。若它外洩、遺失，或您沒有妥善保存，之後可能影響資料安全或可恢復性。';

  @override
  String get aboutTabEncryptionSection2Item2Title => '解鎖後仍要保護裝置';

  @override
  String get aboutTabEncryptionSection2Item2Body =>
      '加密主要保護存放中的資料。若他人取得已解鎖的 App 或已入侵的裝置，仍可能讀取當下可用的內容。';

  @override
  String get aboutTabSearchIndexLabel => '搜尋';

  @override
  String get aboutTabSearchIndexHeroTitle => '解鎖後，您可以快速找回以前寫過的內容';

  @override
  String get aboutTabSearchIndexHeroBody =>
      'App 使用加密搜尋資料加快查找，不必每次逐篇讀取所有日記。搜尋只在日記庫解鎖期間可用。';

  @override
  String get aboutTabSearchIndexChip0 => '標題/內文搜尋';

  @override
  String get aboutTabSearchIndexChip1 => '加密索引';

  @override
  String get aboutTabSearchIndexChip2 => '解鎖期間可用';

  @override
  String get aboutTabSearchIndexChip3 => '可重建';

  @override
  String get aboutTabSearchIndexSection0Title => '搜尋能幫您找什麼';

  @override
  String get aboutTabSearchIndexSection0Subtitle => '適合在回顧、整理或想找某段經歷時，快速縮小範圍。';

  @override
  String get aboutTabSearchIndexSection0Item0Title => '搜尋標題、標籤與內文';

  @override
  String get aboutTabSearchIndexSection0Item0Body =>
      '您可以直接查找標題、內文與標籤中的關鍵字，不需要一篇篇翻找過去寫過什麼。';

  @override
  String get aboutTabSearchIndexSection0Item1Title => '結果來自正式已儲存內容';

  @override
  String get aboutTabSearchIndexSection0Item1Body =>
      '搜尋看到的是已正式寫入日記庫的內容，而不是暫時停在編輯器中的草稿。';

  @override
  String get aboutTabSearchIndexSection0Item2Title => '索引本身也受保護';

  @override
  String get aboutTabSearchIndexSection0Item2Body =>
      '搜尋索引檔會加密保存，只有在日記庫解鎖後，App 才會開啟並查詢其中的搜尋資料。';

  @override
  String get aboutTabSearchIndexSection1Title => '索引如何加快搜尋';

  @override
  String get aboutTabSearchIndexSection1Subtitle =>
      '它把查找工作交給索引層，而不是每次都逐篇掃描正式日記。';

  @override
  String get aboutTabSearchIndexSection1Item0Title => '以索引換速度';

  @override
  String get aboutTabSearchIndexSection1Item0Body =>
      '輸入關鍵字時，App 會查詢搜尋索引，不需逐篇解密整個日記庫。';

  @override
  String get aboutTabSearchIndexSection1Item1Title => '正式儲存後才更新';

  @override
  String get aboutTabSearchIndexSection1Item1Body =>
      '正式儲存或匯入完成後才更新索引，避免結果混入草稿。';

  @override
  String get aboutTabSearchIndexSection1Item2Title => '必要時可重建';

  @override
  String get aboutTabSearchIndexSection1Item2Body =>
      '搜尋索引是可重建的衍生資料。格式更新、還原備份或索引無法沿用時，App 會重新建立。';

  @override
  String get aboutTabSearchIndexSection2Title => '它和安全性的關係';

  @override
  String get aboutTabSearchIndexSection2Subtitle => '搜尋好用，不代表要放棄保護邊界。';

  @override
  String get aboutTabSearchIndexSection2Item0Title => '只在解鎖期間可用';

  @override
  String get aboutTabSearchIndexSection2Item0Body => '索引只在解鎖期間建立、更新與使用；鎖定後會關閉。';

  @override
  String get aboutTabSearchIndexSection2Item1Title => '草稿不進搜尋';

  @override
  String get aboutTabSearchIndexSection2Item1Body =>
      '編輯中的草稿不會出現在搜尋結果裡，避免把未完成內容誤當成正式紀錄。';

  @override
  String get aboutTabSearchIndexSection2Item2Title => '正式資料仍以日記庫為準';

  @override
  String get aboutTabSearchIndexSection2Item2Body =>
      '搜尋索引只用來快速找到內容；正式日記仍以加密日記庫中的資料為準。';

  @override
  String get aboutTabEditorLabel => '寫日記';

  @override
  String get aboutTabEditorHeroTitle => '安心寫作，完成後再正式儲存';

  @override
  String get aboutTabEditorHeroBody =>
      '編輯中的變更會先保存為加密草稿。確認儲存後，內容才會寫入正式日記並更新搜尋資料，方便意外中斷後繼續編輯。';

  @override
  String get aboutTabEditorChip0 => 'Markdown 編輯';

  @override
  String get aboutTabEditorChip1 => '圖片附件';

  @override
  String get aboutTabEditorChip2 => '自動草稿';

  @override
  String get aboutTabEditorChip3 => '未儲存提醒';

  @override
  String get aboutTabEditorSection0Title => '日常寫作功能';

  @override
  String get aboutTabEditorSection0Subtitle => '以個人記錄為核心，把常用的整理方式分開放進同一個編輯流程。';

  @override
  String get aboutTabEditorSection0Item0Title => '新建或修改既有日記';

  @override
  String get aboutTabEditorSection0Item0Body =>
      '新建日記會直接進入編輯模式；既有日記則可先閱讀，確定要改時再切換到編輯狀態。';

  @override
  String get aboutTabEditorSection0Item1Title => '內容、標題與日期';

  @override
  String get aboutTabEditorSection0Item1Body =>
      '您可以編輯標題、日期、時間與內文。正式儲存時至少要有標題或內文，避免留下空白日記。';

  @override
  String get aboutTabEditorSection0Item2Title => '標籤';

  @override
  String get aboutTabEditorSection0Item2Body =>
      '可建立、選擇與整理標籤，並用顏色區分；之後能從標籤頁瀏覽，或直接搜尋標籤文字。';

  @override
  String get aboutTabEditorSection0Item3Title => '任務清單';

  @override
  String get aboutTabEditorSection0Item3Body =>
      '可在文字中加入任務清單，直接勾選項目並繼續編輯；預覽時也能操作核取方塊。';

  @override
  String get aboutTabEditorSection0Item4Title => '圖片與一般附件';

  @override
  String get aboutTabEditorSection0Item4Body =>
      '可加入多張圖片或一般檔案，並調整圖片順序。這讓日記不只是一段文字，也能保留當下的素材與脈絡。';

  @override
  String get aboutTabEditorSection1Title => '草稿機制';

  @override
  String get aboutTabEditorSection1Subtitle => '自動草稿可降低意外中斷時遺失內容的風險。';

  @override
  String get aboutTabEditorSection1Item0Title => '變更會自動保存';

  @override
  String get aboutTabEditorSection1Item0Body =>
      '進入編輯後，變更會自動寫成加密草稿，降低中斷時遺失內容的風險。';

  @override
  String get aboutTabEditorSection1Item1Title => '再次開啟時可還原';

  @override
  String get aboutTabEditorSection1Item1Body =>
      '重新打開同一篇日記或未完成的新建內容時，如果本地仍保留草稿，App 會先詢問您要不要接著上次進度寫。';

  @override
  String get aboutTabEditorSection1Item2Title => '正式儲存後自動清理';

  @override
  String get aboutTabEditorSection1Item2Body =>
      '當內容成功正式寫入日記庫，草稿就會被清掉；如果您取消編輯且沒有留下新變更，也不會一直堆積舊草稿。';

  @override
  String get aboutTabEditorSection2Title => '和其他資料的關係';

  @override
  String get aboutTabEditorSection2Subtitle => '編輯中的內容與正式保存的內容有清楚界線，避免把兩者混為一談。';

  @override
  String get aboutTabEditorSection2Item0Title => '草稿不進搜尋結果';

  @override
  String get aboutTabEditorSection2Item0Body =>
      '搜尋只看正式寫入日記庫的內容，草稿不會出現在結果中，避免未完成內容被誤認為正式紀錄。';

  @override
  String get aboutTabEditorSection2Item1Title => '草稿不進完整備份';

  @override
  String get aboutTabEditorSection2Item1Body =>
      '完整備份只含正式日記庫，不含尚未正式儲存的本地草稿；匯入匯出流程也不會把這些草稿當成正式資料。';

  @override
  String get aboutTabEditorSection2Item2Title => '未儲存提示';

  @override
  String get aboutTabEditorSection2Item2Body =>
      '如果某篇日記仍留有本地草稿，列表與檢視模式會顯示「未儲存」標記，提醒您還有內容尚未正式保存。';

  @override
  String get aboutTabPeopleLabel => '人物';

  @override
  String get aboutTabPeopleHeroTitle => '整理日記裡的重要人物';

  @override
  String get aboutTabPeopleHeroBody =>
      '為生活中的重要人物建立資料。App 會從已儲存的日記找出姓名與別名，方便回顧相關紀錄。';

  @override
  String get aboutTabPeopleChip0 => '姓名與別名';

  @override
  String get aboutTabPeopleChip1 => '關係與備註';

  @override
  String get aboutTabPeopleChip2 => '提及統計';

  @override
  String get aboutTabPeopleChip3 => '@ 快速插入';

  @override
  String get aboutTabPeopleSection0Title => '建立與整理人物資料';

  @override
  String get aboutTabPeopleSection0Subtitle => '記下辨識人物與理解彼此關係時真正有幫助的資訊。';

  @override
  String get aboutTabPeopleSection0Item0Title => '姓名與別名';

  @override
  String get aboutTabPeopleSection0Item0Body =>
      '用正式姓名建立人物，也能加入暱稱或其他稱呼。重新命名時可保留舊名字為別名，讓過去日記仍能被辨識。';

  @override
  String get aboutTabPeopleSection0Item1Title => '關係與熟悉程度';

  @override
  String get aboutTabPeopleSection0Item1Body =>
      '可記錄一種或多種關係、補充關係說明與熟悉程度，再用顏色和備註留下更容易辨認的線索。';

  @override
  String get aboutTabPeopleSection0Item2Title => '生日與認識年份';

  @override
  String get aboutTabPeopleSection0Item2Body =>
      '可選擇記下生日的月日與認識年份，方便保存彼此關係中的重要時間。';

  @override
  String get aboutTabPeopleSection1Title => '從日記回顧彼此的故事';

  @override
  String get aboutTabPeopleSection1Subtitle =>
      'App 會在您使用人物功能時，依姓名與別名更新可重建的提及分析，方便查看相關紀錄。';

  @override
  String get aboutTabPeopleSection1Item0Title => '辨識正式姓名與別名';

  @override
  String get aboutTabPeopleSection1Item0Body =>
      'App 會透過加密搜尋資料中的標題與內容，比對人物的正式姓名與別名，不需每次逐篇解密整個日記庫。';

  @override
  String get aboutTabPeopleSection1Item1Title => '查看提及與相關日記';

  @override
  String get aboutTabPeopleSection1Item1Body =>
      '人物頁會顯示提及總數、近 30 天提及、最近提及時間與相關日記；人物清單也能依這些資訊排序。';

  @override
  String get aboutTabPeopleSection1Item2Title => '用 @ 快速帶入姓名';

  @override
  String get aboutTabPeopleSection1Item2Body =>
      '在日記編輯器輸入 @，可選擇人物並插入該人物指定的名稱（預設為姓名，也可改選別名）。插入後仍是一般文字，不會把日記變成特殊格式。';

  @override
  String get aboutTabPeopleSection2Title => '使用前要知道的事';

  @override
  String get aboutTabPeopleSection2Subtitle => '人物管理協助整理日記，但不會取代或改寫您保存的內容。';

  @override
  String get aboutTabPeopleSection2Item0Title => '統計來自已儲存日記';

  @override
  String get aboutTabPeopleSection2Item0Body =>
      '人物提及只根據正式儲存的日記整理；草稿要等正式儲存後才會反映。提及分析不包含在完整備份中，還原後可重新建立。';

  @override
  String get aboutTabPeopleSection2Item1Title => '刪除人物不會刪除日記';

  @override
  String get aboutTabPeopleSection2Item1Body =>
      '刪除人物只會移除人物名冊與相關統計，原本的日記文字和內容都會保留。';

  @override
  String get aboutTabPeopleSection2Item2Title => '名稱越明確越容易辨識';

  @override
  String get aboutTabPeopleSection2Item2Body =>
      '過短或彼此重疊的姓名與別名可能造成誤判。使用較明確的稱呼，能讓人物提及整理得更準確。';

  @override
  String get aboutTabBackupRestoreLabel => '備份與還原';

  @override
  String get aboutTabBackupRestoreHeroTitle => '保留整個日記庫，或帶出可閱讀內容';

  @override
  String get aboutTabBackupRestoreHeroBody =>
      '完整備份用來保存並還原整個日記庫；Markdown / HTML 匯出則把正式內容轉成可閱讀、可整理的文件。兩者格式與用途不同，不能互相取代。';

  @override
  String get aboutTabBackupRestoreChip0 => '完整備份';

  @override
  String get aboutTabBackupRestoreChip1 => 'Google Drive';

  @override
  String get aboutTabBackupRestoreChip2 => 'Markdown';

  @override
  String get aboutTabBackupRestoreChip3 => 'HTML';

  @override
  String get aboutTabBackupRestoreSection0Title => '完整備份適合什麼情境';

  @override
  String get aboutTabBackupRestoreSection0Subtitle =>
      '如果您想保留整個正式日記庫，之後能原樣還原，走的就是完整備份。';

  @override
  String get aboutTabBackupRestoreSection0Item0Title => '保存完整日記庫';

  @override
  String get aboutTabBackupRestoreSection0Item0Body =>
      '完整備份包含日記、附件、人物名冊與復原設定。日記內容維持加密，但備份外層、復原 metadata，以及存在時的標籤目錄與釘選項目 ID 不另行加密。';

  @override
  String get aboutTabBackupRestoreSection0Item1Title => '建立後會先檢查';

  @override
  String get aboutTabBackupRestoreSection0Item1Body =>
      '完整備份會先經過結構檢查，確認內容可用後，才交付到本機、外部資料夾或 Google Drive。';

  @override
  String get aboutTabBackupRestoreSection0Item2Title => '保留份數';

  @override
  String aboutTabBackupRestoreSection0Item2Body(int retainCount) {
    return '本機備份與 Google Drive 都保留最新 $retainCount 份；若您匯出到外部資料夾，則不會自動輪替或刪除舊檔。';
  }

  @override
  String get aboutTabBackupRestoreSection1Title => '還原時會發生什麼';

  @override
  String get aboutTabBackupRestoreSection1Subtitle =>
      '還原不是補回少掉的幾篇內容，而是把目前正式日記庫換成備份中的那一份。';

  @override
  String get aboutTabBackupRestoreSection1Item0Title => '正式日記庫會被覆寫';

  @override
  String get aboutTabBackupRestoreSection1Item0Body =>
      '不論備份來自 App 內清單、外部 ZIP 或 Google Drive，還原都會用備份內容取代目前的正式日記庫。';

  @override
  String get aboutTabBackupRestoreSection1Item1Title => '搜尋索引會重建';

  @override
  String get aboutTabBackupRestoreSection1Item1Body =>
      '還原後會重新建立搜尋資料，並可能要求您重新驗證；同裝置且仍處於有效解鎖時，有時可直接繼續使用。';

  @override
  String get aboutTabBackupRestoreSection1Item2Title => '可能會要求復原金鑰';

  @override
  String get aboutTabBackupRestoreSection1Item2Body =>
      '如果目前裝置上的可信狀態不能直接對應到那份備份，流程就會要求輸入建立該備份時保存的復原金鑰。';

  @override
  String get aboutTabBackupRestoreSection2Title => '匯入與匯出適合什麼用途';

  @override
  String get aboutTabBackupRestoreSection2Subtitle =>
      '這條流程處理的是內容交換與閱讀，不是拿來完整還原整個日記庫。';

  @override
  String get aboutTabBackupRestoreSection2Item0Title => '匯入';

  @override
  String get aboutTabBackupRestoreSection2Item0Body =>
      '「匯入日記」可處理 Markdown、HTML、資料夾，以及支援的可攜 ZIP 或 Easy Diary 備份；Quill Diary 的完整備份 ZIP 必須改走「匯入外部備份」還原，兩者不能混用。';

  @override
  String get aboutTabBackupRestoreSection2Item1Title => '匯出';

  @override
  String get aboutTabBackupRestoreSection2Item1Body =>
      '您可以從設定匯出 Markdown，也能從主畫面或總覽匯出 HTML，方便閱讀、整理或移轉正式內容。';

  @override
  String get aboutTabBackupRestoreSection2Item2Title => '它不是同步服務';

  @override
  String get aboutTabBackupRestoreSection2Item2Body =>
      'Google Drive 是由您手動操作的完整備份存放位置，不是跨裝置即時同步。上傳交接完成後可在背景繼續；若在遠端驗證前中斷，需重新建立備份。';

  @override
  String get aboutTabBackupRestoreSection3Title => '使用前要知道的事';

  @override
  String get aboutTabBackupRestoreSection3Subtitle =>
      '備份與匯出都很重要，但它們保護的對象與責任邊界並不相同。';

  @override
  String get aboutTabBackupRestoreSection3Item0Title => '完整備份不包含草稿';

  @override
  String get aboutTabBackupRestoreSection3Item0Body =>
      '完整備份不含尚在編輯中、尚未正式儲存的本地草稿；執行還原時也會清除裝置上所有草稿與待上傳附件暫存。';

  @override
  String get aboutTabBackupRestoreSection3Item1Title => '可讀匯出要自己保管';

  @override
  String get aboutTabBackupRestoreSection3Item1Body =>
      'Markdown 與 HTML 匯出是為了閱讀、整理與轉移內容，但它們不再是 App 內的加密格式，後續保存方式要由您自己決定。';

  @override
  String get aboutTabBackupRestoreSection3Item2Title => '別把兩條流程混用';

  @override
  String get aboutTabBackupRestoreSection3Item2Body =>
      '如果您要的是之後完整恢復整個日記庫，請使用完整備份；如果您要的是把內容帶出去看或整理，才使用 Markdown / HTML 匯出。';
}
