/// 應用程式解鎖方式（與復原金鑰無關，僅控制 trusted device 解鎖體驗）。
enum AppUnlockMode {
  /// 不額外要求系統驗證；逾時後自動 plain unwrap。
  none,

  /// 裝置螢幕鎖（系統 PIN／圖案／密碼）保護 Keystore unwrap。
  deviceLock,

  /// 系統生物辨識保護 Keystore unwrap；失敗時可改以裝置螢幕鎖（credential 槽）備援。
  biometric,
}

extension AppUnlockModeStorage on AppUnlockMode {
  String get storageValue => name;

  static AppUnlockMode fromStorage(String? raw) {
    return switch (raw) {
      'none' => AppUnlockMode.none,
      'deviceLock' => AppUnlockMode.deviceLock,
      'biometric' => AppUnlockMode.biometric,
      _ => AppUnlockMode.none,
    };
  }
}
