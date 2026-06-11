/// App 需要解鎖後由 [AppSessionController] 請求的 UI 動作。
enum ResumeUnlockAction {
  /// 立即執行可信裝置直接解包（none 模式）。
  autoTrusted,

  /// 透過已設定的 Android Keystore 提示執行可信裝置解鎖。
  keystoreUnlock,
}
