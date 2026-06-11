import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/security/keystore_unlock_policy.dart';
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

  test('預設使用 plain keystore 保護 trusted session（無解鎖模式）', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();

    await harness.repository.closeUnlockedResources();
    final UnlockedVaultSession session = await harness.repository.unlockWithRecoveryKey(
      setup.recoveryKey,
    );
    final WrappedRecoveryKeyRecord? record =
        await harness.deviceKeyManager.readWrappedRecoveryKey(session.vaultId);

    expect(harness.deviceKeyManager.lastEnsureAuthKind, KeystoreAuthKind.plain);
    expect(harness.deviceKeyManager.lastWrapAuthKind, KeystoreAuthKind.plain);
    expect(session.deviceSlotId, 'dev_android_keystore_plain_${session.vaultId}');
    expect(record?.slotId, 'dev_android_keystore_plain_${session.vaultId}');
    expect(record?.formatVersion, WrappedRecoveryKeyRecord.kWrappedRecoveryKeyFormatVersion);
  });

  test('開啟生物驗證後，refreshTrustedSessionProtection 會切到 biometric trusted session', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    await harness.appLockService.setUnlockMode(AppUnlockMode.biometric);

    final UnlockedVaultSession refreshed = await harness.repository.refreshTrustedSessionProtection(
      setup.session,
      authKind: KeystoreAuthKind.biometric,
    );
    final WrappedRecoveryKeyRecord? record =
        await harness.deviceKeyManager.readWrappedRecoveryKey(refreshed.vaultId);

    expect(harness.deviceKeyManager.lastEnsureAuthKind, KeystoreAuthKind.biometric);
    expect(harness.deviceKeyManager.lastWrapAuthKind, KeystoreAuthKind.biometric);
    expect(refreshed.deviceSlotId, 'dev_android_keystore_biometric_${refreshed.vaultId}');
    expect(record?.slotId, 'dev_android_keystore_biometric_${refreshed.vaultId}');
    expect(record?.formatVersion, WrappedRecoveryKeyRecord.kWrappedRecoveryKeyFormatVersion);
  });

  test('WrappedRecoveryKeyRecord 拒絕 format_version 2', () {
    expect(
      () => WrappedRecoveryKeyRecord.fromJson(<Object?, Object?>{
        'slot_id': 'dev_test',
        'nonce': 'abc',
        'ciphertext': 'def',
        'wrapped_at': DateTime.now().toIso8601String(),
        'format_version': 2,
        'platform': 'android',
      }),
      throwsA(isA<DeviceKeyUnsupportedFormatException>()),
    );
  });
}
