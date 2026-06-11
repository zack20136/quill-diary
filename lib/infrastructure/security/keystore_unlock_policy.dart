import 'app_unlock_mode.dart';

/// 用於包裝復原材料的 Android Keystore 驗證政策。
enum KeystoreAuthKind {
  plain,
  deviceCredential,
  biometric,
}

extension KeystoreAuthKindWire on KeystoreAuthKind {
  String get wireValue => switch (this) {
        KeystoreAuthKind.plain => 'plain',
        KeystoreAuthKind.deviceCredential => 'deviceCredential',
        KeystoreAuthKind.biometric => 'biometric',
      };

  String get storageSuffix => wireValue;

  static KeystoreAuthKind? fromSlotId(String slotId) {
    if (slotId.contains('_plain_') || slotId.contains('keystore_plain')) {
      return KeystoreAuthKind.plain;
    }
    if (slotId.contains('deviceCredential')) {
      return KeystoreAuthKind.deviceCredential;
    }
    if (slotId.contains('biometric')) {
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
