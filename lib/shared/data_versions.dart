/// 本機資料格式與持久化內容的目前版本；App 發行版本由 pubspec.yaml 管理。
///
/// 各欄位獨立升版，避免單一格式變更連帶使其他資料失效。
abstract final class DataVersions {
  static const int encryptedDocument = 1;
  static const int recoveryMetadata = 1;
  static const int wrappedRecoveryKey = 1;
  static const int peopleCatalog = 1;
  static const int aiSettings = 1;
  static const int pinnedEntries = 1;
  static const int chatDiary = 1;
  static const int indexDatabase = 1;
  static const int entryIndexGeneration = 1;

  /// 姓名比對規則變更時遞增，讓衍生統計重新建立。
  static const int peopleAnalyticsGeneration = 1;

  static const int onboardingIntro = 1;

  /// 新日記庫的起始值；既有紀錄仍保留各自的金鑰版本。
  static const int initialRecoveryKey = 1;
}
