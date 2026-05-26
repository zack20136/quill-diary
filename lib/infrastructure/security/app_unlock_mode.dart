/// App unlock modes that protect trusted-device recovery material.
enum AppUnlockMode {
  /// No extra system verification; background timeout uses plain unwrap.
  none,

  /// Android device credential, such as PIN, pattern, or password.
  deviceLock,

  /// Strong biometric prompt, with Android device credential as system fallback.
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
