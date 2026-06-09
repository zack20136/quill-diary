import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/keystore_unlock_policy.dart';

void main() {
  test('missing unlock mode defaults to none', () {
    expect(AppUnlockModeStorage.fromStorage(null), AppUnlockMode.none);
    expect(AppUnlockModeStorage.fromStorage('none'), AppUnlockMode.none);
    expect(AppUnlockModeStorage.fromStorage('deviceLock'), AppUnlockMode.deviceLock);
    expect(AppUnlockModeStorage.fromStorage('biometric'), AppUnlockMode.biometric);
  });

  test('keystoreAuthFor maps unlock modes', () {
    expect(keystoreAuthFor(AppUnlockMode.none), KeystoreAuthKind.plain);
    expect(keystoreAuthFor(AppUnlockMode.deviceLock), KeystoreAuthKind.deviceCredential);
    expect(keystoreAuthFor(AppUnlockMode.biometric), KeystoreAuthKind.biometric);
  });

  test('fromSlotId parses secure keystore slot ids', () {
    expect(
      KeystoreAuthKindWire.fromSlotId('dev_android_keystore_plain_vlt_x'),
      KeystoreAuthKind.plain,
    );
    expect(
      KeystoreAuthKindWire.fromSlotId('dev_android_keystore_deviceCredential_vlt_x'),
      KeystoreAuthKind.deviceCredential,
    );
    expect(
      KeystoreAuthKindWire.fromSlotId('dev_android_keystore_biometric_vlt_x'),
      KeystoreAuthKind.biometric,
    );
  });
}
