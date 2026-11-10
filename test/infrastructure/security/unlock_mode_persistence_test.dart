import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/security/keystore_unlock_policy.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../../helpers/vault/fake_device_key_manager.dart';
import '../../helpers/vault/vault_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final invalid in ['[]', '{', '{"slot_id":123}', '{"slot_id":""}']) {
    test('裝置資訊錯誤 JSON $invalid 導向可辨識的復原錯誤', () async {
      FlutterSecureStorage.setMockInitialValues({
        'vault.test.device_info': invalid,
      });
      final manager = AndroidDeviceKeyManager(
        storage: const FlutterSecureStorage(),
      );
      await expectLater(
        manager.readDeviceInfo('test'),
        throwsA(isA<DeviceKeyUnsupportedFormatException>()),
      );
    });
  }
  for (final invalid in ['[]', '{', '{}']) {
    test('裝置包裝錯誤 JSON $invalid 不延遲為 unwrap 失敗', () async {
      FlutterSecureStorage.setMockInitialValues({
        'vault.test.wrapped_recovery_key': invalid,
      });
      final manager = AndroidDeviceKeyManager(
        storage: const FlutterSecureStorage(),
      );
      await expectLater(
        manager.readWrappedRecoveryKey('test'),
        throwsA(isA<DeviceKeyUnsupportedFormatException>()),
      );
    });
  }

  for (final field in ['slot_id', 'nonce', 'ciphertext']) {
    for (final value in [null, '', 123]) {
      test('裝置包裝記錄 $field 為 $value 時立即拒讀', () {
        final json = <Object?, Object?>{
          'slot_id': 'slot',
          'nonce': base64Encode(List.filled(12, 1)),
          'ciphertext': base64Encode(List.filled(48, 2)),
          'format_version': 1,
          'wrapped_at': DateTime.utc(2026).toIso8601String(),
          'platform': 'android',
        };
        if (value == null) {
          json.remove(field);
        } else {
          json[field] = value;
        }
        expect(
          () => WrappedRecoveryKeyRecord.fromJson(json),
          throwsA(isA<DeviceKeyUnsupportedFormatException>()),
        );
      });
    }
  }
  test('裝置記錄缺少可選 metadata 使用固定缺省，但錯誤編碼拒讀', () {
    final json = <Object?, Object?>{
      'slot_id': 'slot',
      'nonce': base64Encode(List.filled(12, 1)),
      'ciphertext': base64Encode(List.filled(48, 2)),
    };
    final value = WrappedRecoveryKeyRecord.fromJson(json);
    expect(value.formatVersion, 1);
    expect(value.wrappedAt.millisecondsSinceEpoch, 0);
    expect(value.platform, '');
    json['nonce'] = '不是 base64';
    expect(
      () => WrappedRecoveryKeyRecord.fromJson(json),
      throwsA(isA<DeviceKeyUnsupportedFormatException>()),
    );
  });

  late VaultTestHarness harness;
  late CancellingDeviceKeyManager cancellingManager;

  setUp(() async {
    cancellingManager = CancellingDeviceKeyManager();
    harness = await VaultTestHarness.create(
      deviceKeyManager: cancellingManager,
    );
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('目標模式為 deviceLock 時，儲存的 app lock mode 會維持 none', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    await harness.repository.ensureKeystoreMatchesUnlockMode(setup.session);
    expect(await harness.appLockService.getUnlockMode(), AppUnlockMode.none);

    cancellingManager.cancelWrap = true;

    await expectLater(
      harness.repository.ensureKeystoreMatchesUnlockMode(
        setup.session,
        targetMode: AppUnlockMode.deviceLock,
      ),
      throwsA(isA<DeviceKeyUserCancelledException>()),
    );

    expect(await harness.appLockService.getUnlockMode(), AppUnlockMode.none);
  });

  test('目標模式為 biometric 時，儲存的 app lock mode 會維持 deviceLock', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    await harness.appLockService.setUnlockMode(AppUnlockMode.deviceLock);
    await harness.repository.ensureKeystoreMatchesUnlockMode(
      setup.session,
      targetMode: AppUnlockMode.deviceLock,
    );

    cancellingManager.cancelWrap = true;

    await expectLater(
      harness.repository.ensureKeystoreMatchesUnlockMode(
        setup.session,
        targetMode: AppUnlockMode.biometric,
      ),
      throwsA(isA<DeviceKeyUserCancelledException>()),
    );

    expect(
      await harness.appLockService.getUnlockMode(),
      AppUnlockMode.deviceLock,
    );
  });

  test('目標模式切換後會更新 app lock mode', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    await harness.repository.ensureKeystoreMatchesUnlockMode(setup.session);

    await harness.repository.ensureKeystoreMatchesUnlockMode(
      setup.session,
      targetMode: AppUnlockMode.deviceLock,
    );
    expect(
      cancellingManager.lastWrapAuthKind,
      KeystoreAuthKind.deviceCredential,
    );

    await harness.appLockService.setUnlockMode(AppUnlockMode.deviceLock);
    expect(
      await harness.appLockService.getUnlockMode(),
      AppUnlockMode.deviceLock,
    );
  });
}
