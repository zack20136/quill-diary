import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/infrastructure/security/device_key_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('quill_lock_diary/device_key_bridge');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('ensureDeviceKey maps missing biometric enrollment errors', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'ensureKey') {
        throw PlatformException(
          code: 'device_key_error',
          message:
              'java.lang.IllegalStateException: At least one biometric must be enrolled to create keys requiring user authentication for every use',
        );
      }
      return null;
    });

    final AndroidDeviceKeyManager manager = AndroidDeviceKeyManager(channel: channel);

    await expectLater(
      () => manager.ensureDeviceKey(
        'vault_test',
        userAuthenticationRequired: true,
      ),
      throwsA(isA<DeviceKeyBiometricNotEnrolledException>()),
    );
  });
}
