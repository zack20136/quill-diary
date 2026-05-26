import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_lock_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_lock_diary/infrastructure/security/keystore_unlock_policy.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_repository.dart';

import '../helpers/vault_test_harness.dart';

void main() {
  group('KeystoreAuthKind.fromSlotId', () {
    test('parses current slot ids', () {
      expect(
        KeystoreAuthKindWire.fromSlotId('dev_android_keystore_plain_vlt_a'),
        KeystoreAuthKind.plain,
      );
      expect(
        KeystoreAuthKindWire.fromSlotId('dev_android_keystore_deviceCredential_vlt_a'),
        KeystoreAuthKind.deviceCredential,
      );
      expect(
        KeystoreAuthKindWire.fromSlotId('dev_android_keystore_biometric_vlt_a'),
        KeystoreAuthKind.biometric,
      );
    });
  });

  test('setupRecoveryKey works without device credential when mode is none', () async {
    final VaultTestHarness harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);

    harness.appLockService.canUseDeviceCredentialResult = false;
    await harness.appLockService.setUnlockMode(AppUnlockMode.none);

    await expectLater(harness.repository.setupRecoveryKey(), completes);
    expect(harness.deviceKeyManager.lastWrapAuthKind, KeystoreAuthKind.plain);
  });

  test('openTrustedSession accepts plain trusted slot in none mode', () async {
    final VaultTestHarness harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);

    await harness.appLockService.setUnlockMode(AppUnlockMode.none);
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();

    await harness.repository.closeUnlockedResources();

    final UnlockedVaultSession session = await harness.repository.openTrustedSession();
    expect(session.vaultId, setup.session.vaultId);
    expect(session.trustedDevice, isTrue);
  });
}
