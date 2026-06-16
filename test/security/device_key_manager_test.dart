import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/security/keystore_unlock_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('quill_diary/device_key_bridge');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('ensureDeviceKey maps missing biometric enrollment errors', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'ensureKey') {
            throw PlatformException(
              code: 'device_key_biometric_not_enrolled',
              message: '啟用生物驗證前，請先到裝置設定新增至少一種生物辨識。',
            );
          }
          return null;
        });

    final AndroidDeviceKeyManager manager = AndroidDeviceKeyManager(
      channel: channel,
    );

    await expectLater(
      () => manager.ensureDeviceKey(
        'vault_test',
        authKind: KeystoreAuthKind.biometric,
      ),
      throwsA(isA<DeviceKeyBiometricNotEnrolledException>()),
    );
  });

  test('unwrapWithDeviceKey maps no device credential error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'unwrapWithDeviceKey') {
            throw PlatformException(
              code: 'device_key_no_device_credential',
              message: '請先在裝置設定中建立螢幕鎖，才能使用此解鎖方式。',
            );
          }
          return null;
        });

    final AndroidDeviceKeyManager manager = AndroidDeviceKeyManager(
      channel: channel,
    );

    await expectLater(
      () => manager.unwrapWithDeviceKey(
        vaultId: 'vault_test',
        slotId: 'dev_android_keystore_deviceCredential_vault_test',
        nonceBase64: 'abc',
        ciphertextBase64: 'def',
      ),
      throwsA(isA<DeviceKeyNoDeviceCredentialException>()),
    );
  });

  test('unwrapWithDeviceKey maps auth lockout error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'unwrapWithDeviceKey') {
            throw PlatformException(
              code: 'device_key_auth_lockout',
              message: '驗證失敗次數過多，請稍後再試。',
            );
          }
          return null;
        });

    final AndroidDeviceKeyManager manager = AndroidDeviceKeyManager(
      channel: channel,
    );

    await expectLater(
      () => manager.unwrapWithDeviceKey(
        vaultId: 'vault_test',
        slotId: 'dev_android_keystore_biometric_vault_test',
        nonceBase64: 'abc',
        ciphertextBase64: 'def',
      ),
      throwsA(isA<DeviceKeyAuthLockoutException>()),
    );
  });

  test('unwrapWithDeviceKey maps auth timeout error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'unwrapWithDeviceKey') {
            throw PlatformException(
              code: 'device_key_auth_timeout',
              message: '驗證逾時，請再試一次。',
            );
          }
          return null;
        });

    final AndroidDeviceKeyManager manager = AndroidDeviceKeyManager(
      channel: channel,
    );

    await expectLater(
      () => manager.unwrapWithDeviceKey(
        vaultId: 'vault_test',
        slotId: 'dev_android_keystore_deviceCredential_vault_test',
        nonceBase64: 'abc',
        ciphertextBase64: 'def',
      ),
      throwsA(isA<DeviceKeyAuthTimeoutException>()),
    );
  });
}
