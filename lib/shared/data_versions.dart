/// 本機資料格式的目前版本；App 發行版本由 pubspec.yaml 管理。
///
/// 各欄位獨立升版，避免單一格式變更連帶使其他資料失效。
/// 只有不相容的結構、型別或語意變更才升格式版；提示詞、UI、模型目錄、
/// 預設值與有預設值的可選欄位不升版，不另設提示詞版本或 AI 總版本。
/// 操作狀態、起始值與可重建快取的規則修訂不放在此處。
abstract final class DataVersions {
  /// LDJ2 加密檔頭與封裝結構；日記、附件及加密 JSON 共用。
  static const int encryptedDocument = 1;

  /// recovery.json 的復原描述子結構，包含日記庫識別、提示與 KDF 參數。
  static const int recoveryMetadata = 1;

  /// 安全儲存區內的裝置包裝紀錄結構，不是 Android Keystore 金鑰的版本。
  static const int wrappedRecoveryKey = 1;

  /// people.json.enc 解密後的人物名冊 JSON 結構。
  static const int peopleCatalog = 1;

  /// ai_settings.json.enc 解密後的 AI 連線、模型與參數設定結構。
  static const int aiSettings = 2;

  /// pinned_entries.json 的釘選 ID 清單結構，不隨釘選操作增加。
  static const int pinnedEntries = 1;

  /// 聊天日記 session JSON 的訊息分支、圖片及編輯狀態結構。
  static const int chatDiary = 1;

  /// 人物分身 state.json.enc 的記憶、聊天風格與工作狀態結構。
  static const int persona = 1;

  /// 分身 pending_imports 內匯入聊天的訊息、說話者及隱私範圍結構。
  static const int personaImport = 1;

  /// 日記整理草稿的對話、候選稿及套用狀態 JSON 結構。
  static const int diaryOrganization = 1;

  /// 加密搜尋索引的 SQLite schema，用於資料表與欄位遷移。
  static const int indexDatabase = 1;
}
