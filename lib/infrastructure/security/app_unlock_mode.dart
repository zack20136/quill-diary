/// 保護可信裝置復原材料的 App 解鎖模式。
enum AppUnlockMode {
  /// 無額外系統驗證；背景逾時時直接解包。
  none,

  /// Android 裝置憑證，例如 PIN、圖形鎖或密碼。
  deviceLock,

  /// 強生物辨識提示，系統後備為 Android 裝置憑證。
  biometric,
}

extension AppUnlockModeStorage on AppUnlockMode {
  String get storageValue => name;

  static AppUnlockMode fromStorage(String? raw) {
    return switch (raw) {
      'biometric' => AppUnlockMode.biometric,
      'deviceLock' => AppUnlockMode.deviceLock,
      'none' => AppUnlockMode.none,
      _ => AppUnlockMode.none,
    };
  }
}
