/// 逾時鎖定後，UI 應執行的自動解鎖步驟（由 [AppSessionController] 設定）。
enum ResumeUnlockAction {
  /// 模式「無」：直接 trusted unlock。
  autoTrusted,

  /// 模式「裝置螢幕鎖」或「生物」：觸發 Keystore 系統對話框。
  keystoreUnlock,

  /// 生物模式 Keystore 失敗：改以裝置螢幕鎖（credential 槽）解鎖。
  deviceCredentialFallback,
}
