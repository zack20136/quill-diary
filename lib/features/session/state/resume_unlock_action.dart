/// UI actions requested by [AppSessionController] after the app needs to unlock.
enum ResumeUnlockAction {
  /// Immediately run trusted-device plain unwrap (none mode).
  autoTrusted,

  /// Run trusted-device unlock through the configured Android Keystore prompt.
  keystoreUnlock,
}
