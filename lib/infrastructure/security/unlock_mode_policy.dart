import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/security/app_lock_service.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/security/keystore_unlock_policy.dart';

/// 何時檢查裝置是否支援某解鎖模式。
enum UnlockModeCapabilityContext {
  /// 使用既有可信裝置包裝解鎖（生物辨識可事後移除，仍可用螢幕鎖後備）。
  unlock,

  /// 建立或切換 Keystore 包裝（生物驗證模式須已登錄強生物辨識）。
  migrate,
}

/// 解鎖模式能力檢查失敗原因。
enum UnlockModeCapabilityFailure {
  requiresUnlockedSession,
  requiresDeviceLock,
  requiresBiometricEnrollment,
}

class UnlockModeCapabilityException implements Exception {
  const UnlockModeCapabilityException(this.failure);

  final UnlockModeCapabilityFailure failure;
}

/// 裝置驗證能力快照（單次原生查詢，避免檢查與使用時間差）。
class DeviceAuthCapabilities {
  const DeviceAuthCapabilities({
    required this.deviceCredentialAvailable,
    required this.biometricStrongAvailable,
  });

  final bool deviceCredentialAvailable;
  final bool biometricStrongAvailable;
}

UnlockModeCapabilityFailure? checkUnlockModeCapability({
  required AppUnlockMode mode,
  required DeviceAuthCapabilities capabilities,
  UnlockModeCapabilityContext context = UnlockModeCapabilityContext.unlock,
}) {
  switch (mode) {
    case AppUnlockMode.none:
      return null;
    case AppUnlockMode.deviceLock:
    case AppUnlockMode.biometric:
      if (!capabilities.deviceCredentialAvailable) {
        return UnlockModeCapabilityFailure.requiresDeviceLock;
      }
      if (mode == AppUnlockMode.biometric &&
          context == UnlockModeCapabilityContext.migrate &&
          !capabilities.biometricStrongAvailable) {
        return UnlockModeCapabilityFailure.requiresBiometricEnrollment;
      }
      return null;
  }
}

Future<UnlockModeCapabilityFailure?> precheckUnlockModeChange({
  required AppLockService appLock,
  required AppUnlockMode mode,
}) async {
  final DeviceAuthCapabilities capabilities = await appLock
      .getDeviceAuthCapabilities();
  return checkUnlockModeCapability(
    mode: mode,
    capabilities: capabilities,
    context: UnlockModeCapabilityContext.migrate,
  );
}

Future<KeystoreAuthKind> requireKeystoreAuthKindForMode({
  required AppLockService appLock,
  required AppUnlockMode mode,
}) async {
  final DeviceAuthCapabilities capabilities = await appLock
      .getDeviceAuthCapabilities();
  final UnlockModeCapabilityFailure? failure = checkUnlockModeCapability(
    mode: mode,
    capabilities: capabilities,
    context: UnlockModeCapabilityContext.unlock,
  );
  if (failure != null) {
    throw UnlockModeCapabilityException(failure);
  }
  return keystoreAuthFor(mode);
}

/// 比對 Keystore slot 與 wrapped record 是否已符合目標策略（不含索引後綴）。
bool keystoreSlotsMatchExpected({
  required UnlockedVaultSession session,
  required KeystoreAuthKind expected,
  WrappedRecoveryKeyRecord? wrappedRecord,
}) {
  if (wrappedRecord == null) {
    return false;
  }

  final KeystoreAuthKind? sessionSlotKind = _slotAuthKind(session.deviceSlotId);
  if (sessionSlotKind != expected) {
    return false;
  }

  final KeystoreAuthKind? recordSlotKind = _slotAuthKind(wrappedRecord.slotId);
  if (recordSlotKind != expected) {
    return false;
  }

  if (session.deviceSlotId != null &&
      wrappedRecord.slotId != session.deviceSlotId) {
    return false;
  }

  return true;
}

/// 僅索引 [kKeystoreWrapModeKey] 落後，Keystore slot 本身已正確。
bool needsOnlyIndexSuffixSync({
  required UnlockedVaultSession session,
  required KeystoreAuthKind expected,
  required String? syncedSuffix,
  WrappedRecoveryKeyRecord? wrappedRecord,
}) {
  if (trustedProtectionMatches(
    session: session,
    expected: expected,
    syncedSuffix: syncedSuffix,
    wrappedRecord: wrappedRecord,
  )) {
    return false;
  }
  return keystoreSlotsMatchExpected(
    session: session,
    expected: expected,
    wrappedRecord: wrappedRecord,
  );
}

/// 比對 session、安全儲存區與索引是否皆符合目標 Keystore 策略。
bool trustedProtectionMatches({
  required UnlockedVaultSession session,
  required KeystoreAuthKind expected,
  required String? syncedSuffix,
  WrappedRecoveryKeyRecord? wrappedRecord,
}) {
  if (syncedSuffix != expected.storageSuffix) {
    return false;
  }

  return keystoreSlotsMatchExpected(
    session: session,
    expected: expected,
    wrappedRecord: wrappedRecord,
  );
}

KeystoreAuthKind? _slotAuthKind(String? slotId) {
  if (slotId == null || slotId.isEmpty) {
    return null;
  }
  return KeystoreAuthKindWire.fromSlotId(slotId);
}
