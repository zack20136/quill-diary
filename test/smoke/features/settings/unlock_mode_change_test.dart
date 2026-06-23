import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/security/keystore_unlock_policy.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../../../helpers/vault/fake_device_key_manager.dart';
import '../../../helpers/vault/vault_test_harness.dart';

void main() {
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

