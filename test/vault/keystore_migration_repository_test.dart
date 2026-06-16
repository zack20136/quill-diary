import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/keystore_unlock_policy.dart';
import 'package:quill_diary/infrastructure/security/unlock_mode_policy.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../helpers/vault_test_harness.dart';

void main() {
  late VaultTestHarness harness;

  setUp(() async {
    harness = await VaultTestHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('needsKeystoreMigration 在 plain 模式下切換至 deviceLock 時為 true', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();

    expect(
      await harness.repository.needsKeystoreMigration(setup.session),
      isFalse,
    );

    await harness.appLockService.setUnlockMode(AppUnlockMode.deviceLock);
    expect(
      await harness.repository.needsKeystoreMigration(setup.session),
      isTrue,
    );
  });

  test(
    'ensureKeystoreMatchesUnlockMode 會 re-wrap 並 purge inactive 金鑰',
    () async {
      final RecoverySetupResult setup = await harness.repository
          .setupRecoveryKey();
      await harness.appLockService.setUnlockMode(AppUnlockMode.deviceLock);

      final int purgeBefore =
          harness.deviceKeyManager.purgeInactiveDeviceKeysCalls;
      final UnlockedVaultSession synced = await harness.repository
          .ensureKeystoreMatchesUnlockMode(
            setup.session,
            targetMode: AppUnlockMode.deviceLock,
          );

      expect(synced.deviceSlotId, contains('deviceCredential'));
      expect(
        harness.deviceKeyManager.lastWrapAuthKind,
        KeystoreAuthKind.deviceCredential,
      );
      expect(
        harness.deviceKeyManager.purgeInactiveDeviceKeysCalls,
        purgeBefore + 1,
      );
      expect(
        harness.deviceKeyManager.lastPurgeAuthKind,
        KeystoreAuthKind.deviceCredential,
      );
      expect(await harness.repository.needsKeystoreMigration(synced), isFalse);
    },
  );

  test('unlockWithRecoveryKey 在 biometric 模式但無 enrollment 時失敗', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    await harness.repository.clearTrustedDeviceAccess();
    await harness.appLockService.setUnlockMode(AppUnlockMode.biometric);
    harness.appLockService.canUseBiometricResult = false;
    harness.appLockService.canUseDeviceCredentialResult = true;

    await expectLater(
      harness.repository.unlockWithRecoveryKey(setup.recoveryKey),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          kBiometricNotEnrolledSwitchModeMessage,
        ),
      ),
    );
  });
}
