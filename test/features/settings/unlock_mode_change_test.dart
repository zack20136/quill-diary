import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/security/keystore_unlock_policy.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../../helpers/fake_device_key_manager.dart';
import '../../helpers/vault_test_harness.dart';

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

  test('targetMode deviceLock 驗證取消時 storage 維持 none', () async {
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

  test('targetMode biometric 驗證取消時 storage 維持 deviceLock', () async {
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

  test('targetMode 成功後才應寫入 app lock mode', () async {
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
