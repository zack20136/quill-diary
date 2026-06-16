import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/security/keystore_unlock_policy.dart';
import 'package:quill_diary/infrastructure/security/unlock_mode_policy.dart';

void main() {
  const DeviceAuthCapabilities noCapabilities = DeviceAuthCapabilities(
    deviceCredentialAvailable: false,
    biometricStrongAvailable: false,
  );
  const DeviceAuthCapabilities lockOnly = DeviceAuthCapabilities(
    deviceCredentialAvailable: true,
    biometricStrongAvailable: false,
  );
  const DeviceAuthCapabilities lockAndBiometric = DeviceAuthCapabilities(
    deviceCredentialAvailable: true,
    biometricStrongAvailable: true,
  );

  test('migrate 至 deviceLock 需要螢幕鎖', () {
    expect(
      checkUnlockModeCapability(
        mode: AppUnlockMode.deviceLock,
        capabilities: noCapabilities,
        context: UnlockModeCapabilityContext.migrate,
      ),
      UnlockModeCapabilityFailure.requiresDeviceLock,
    );
    expect(
      checkUnlockModeCapability(
        mode: AppUnlockMode.deviceLock,
        capabilities: lockOnly,
        context: UnlockModeCapabilityContext.migrate,
      ),
      isNull,
    );
  });

  test('migrate 至 biometric 需要 strong biometric', () {
    expect(
      checkUnlockModeCapability(
        mode: AppUnlockMode.biometric,
        capabilities: lockOnly,
        context: UnlockModeCapabilityContext.migrate,
      ),
      UnlockModeCapabilityFailure.requiresBiometricEnrollment,
    );
    expect(
      checkUnlockModeCapability(
        mode: AppUnlockMode.biometric,
        capabilities: lockAndBiometric,
        context: UnlockModeCapabilityContext.migrate,
      ),
      isNull,
    );
  });

  test('unlock 使用 biometric 模式時不要求已登錄 biometric', () {
    expect(
      checkUnlockModeCapability(
        mode: AppUnlockMode.biometric,
        capabilities: lockOnly,
        context: UnlockModeCapabilityContext.unlock,
      ),
      isNull,
    );
  });

  test('trustedProtectionMatches 需 index、session 與 record 一致', () {
    const UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: 'vlt_a',
      trustedDevice: true,
      deviceSlotId: 'dev_android_keystore_deviceCredential_vlt_a',
    );
    final WrappedRecoveryKeyRecord record = WrappedRecoveryKeyRecord(
      slotId: 'dev_android_keystore_deviceCredential_vlt_a',
      nonceBase64: 'abc',
      ciphertextBase64: 'def',
      wrappedAt: DateTime.fromMillisecondsSinceEpoch(0),
      formatVersion: WrappedRecoveryKeyRecord.kWrappedRecoveryKeyFormatVersion,
      platform: 'android',
    );

    expect(
      trustedProtectionMatches(
        session: session,
        expected: KeystoreAuthKind.deviceCredential,
        syncedSuffix: KeystoreAuthKind.deviceCredential.storageSuffix,
        wrappedRecord: record,
      ),
      isTrue,
    );
    expect(
      trustedProtectionMatches(
        session: session,
        expected: KeystoreAuthKind.biometric,
        syncedSuffix: KeystoreAuthKind.deviceCredential.storageSuffix,
        wrappedRecord: record,
      ),
      isFalse,
    );
    expect(
      trustedProtectionMatches(
        session: session,
        expected: KeystoreAuthKind.deviceCredential,
        syncedSuffix: KeystoreAuthKind.deviceCredential.storageSuffix,
        wrappedRecord: record.copyWith(
          slotId: 'dev_android_keystore_biometric_vlt_a',
        ),
      ),
      isFalse,
    );
  });

  test('lockedResumeMessageFor 依模式回傳提示', () {
    expect(
      lockedResumeMessageFor(AppUnlockMode.deviceLock),
      kUseDeviceLockToUnlockMessage,
    );
    expect(
      lockedResumeMessageFor(AppUnlockMode.biometric),
      kStartupNeedsBiometricMessage,
    );
  });
}

extension on WrappedRecoveryKeyRecord {
  WrappedRecoveryKeyRecord copyWith({String? slotId}) {
    return WrappedRecoveryKeyRecord(
      slotId: slotId ?? this.slotId,
      nonceBase64: nonceBase64,
      ciphertextBase64: ciphertextBase64,
      wrappedAt: wrappedAt,
      formatVersion: formatVersion,
      platform: platform,
    );
  }
}
