import 'app_unlock_mode.dart';

/// Android Keystore unwrap 驗證強度（與 [AppUnlockMode] 對應）。
enum KeystoreAuthKind {
  plain,
  deviceCredential,
  biometric,
}

extension KeystoreAuthKindWire on KeystoreAuthKind {
  /// 傳給 Android MethodChannel 的值。
  String get wireValue => switch (this) {
        KeystoreAuthKind.plain => 'plain',
        KeystoreAuthKind.deviceCredential => 'deviceCredential',
        KeystoreAuthKind.biometric => 'biometric',
      };

  /// 寫入 index `keystore_wrap_mode` 與 slot id 後綴。
  String get storageSuffix => wireValue;

  static KeystoreAuthKind? fromSlotId(String slotId) {
    if (slotId.contains('_plain_')) {
      return KeystoreAuthKind.plain;
    }
    if (slotId.contains('_credential_')) {
      return KeystoreAuthKind.deviceCredential;
    }
    if (slotId.contains('_biometric_')) {
      return KeystoreAuthKind.biometric;
    }
    return null;
  }
}

KeystoreAuthKind keystoreAuthFor(AppUnlockMode mode) => switch (mode) {
      AppUnlockMode.none => KeystoreAuthKind.plain,
      AppUnlockMode.deviceLock => KeystoreAuthKind.deviceCredential,
      AppUnlockMode.biometric => KeystoreAuthKind.biometric,
    };
