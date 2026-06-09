/// 編輯器相關的繁體中文 UI 文案。
abstract final class EditorCopy {
  static const String pageTitle = '編輯日記';
  static const String titleHint = '輸入標題';
  static const String titleRequiredError = '請輸入標題';
  static const String bodyHint = '在這裡輸入內容…';
  static const String bodyEmptyPreview = '尚未輸入內容';
  static const String needsRecoveryKeyMessage = '請先建立復原金鑰，才能開始建立或編輯日記。';
  static const String sessionLockedFallback = '請先重新解鎖日記庫後再繼續。';
  static const String saveNeedsTitleMessage = '請輸入標題才能儲存';
  static const String unsavedDraftLabel = '未儲存';

  static const String confirmDeleteTitle = '確認刪除';
  static const String confirmDeleteBody = '確定要刪除這篇日記嗎？刪除後無法復原。';

  static const String tagsStudioTitle = '標籤';
  static const String tagsStudioGuide = '右上角可建立新標籤；下方為文庫標籤，輕觸加入。';
  static const String tagsStudioEmptyChosen = '尚未套用任何標籤';
  static const String tagsStudioAddButton = '加入';
  static const String previewUnavailable = '無法預覽';

  static const String tagSearchHint = '搜尋標籤…';
  static const String tagLibraryHint = '文庫裡的標籤 · 輕觸加入';
  static const String tagPoolEmpty = '文庫裡暫時沒有其他可用標籤，或已全部加入目前清單';
  static const String tagAddTooltip = '新增標籤';

  static const String tooltipCancel = '取消';
  static const String tooltipSave = '儲存';
  static const String tooltipSaveNeedsTitle = '請先輸入標題';
  static const String tooltipDate = '日期';
  static const String tooltipTime = '時間';
  static const String tooltipEditTags = '編輯標籤';
  static const String tooltipUploadImages = '上傳圖片（可一次選多張）';
  static const String tooltipAddAttachment = '新增附件';
  static const String tooltipDelete = '刪除';
  static const String tooltipEdit = '編輯';

  static const String restoreDraftTitle = '發現未完成的草稿';
  static const String restoreDraftDecline = '不使用';
  static const String restoreDraftAccept = '還原草稿';
  static const String untitledDraft = '無標題';

  static String restoreDraftOverwrite(String title, String savedAt) =>
      '草稿：$title\n最後儲存：$savedAt\n\n還原後會覆蓋目前檢視中的內容。';

  static String restoreDraftPrompt(String title, String savedAt) =>
      '草稿：$title\n最後儲存：$savedAt\n\n是否要還原這份草稿？';

  static const String discardDraftTitle = '捨棄草稿？';
  static const String discardDraftBody = '目前的修改尚未儲存為日記，確定要捨棄草稿並離開嗎？';
  static const String discardDraftConfirm = '捨棄';
}
