import '../../domain/security/unlocked_vault_session.dart';
import '../../l10n/l10n.dart';
import 'app_lock_service.dart';
import 'app_unlock_mode.dart';
import 'device_key_manager.dart';
import 'keystore_unlock_policy.dart';

const String kUnlockModeNeedsDeviceLockMessage = '請先在裝置設定中建立螢幕鎖，才能使用此模式。';
const String kUnlockModeChangeNeedsUnlockMessage = '請先解鎖日記庫後，再變更解鎖方式。';
const String kBiometricNotEnrolledSwitchModeMessage =
    '裝置尚未登錄指紋或臉部。請先到系統設定完成生物辨識設定，或改用裝置螢幕鎖。';
const String kUseDeviceLockToUnlockMessage = '請使用裝置螢幕鎖解鎖。';
const String kStartupNeedsBiometricMessage = '請先完成生物驗證。';
const String kUnlockModeChangeCancelledMessage = '已取消變更，解鎖方式維持不變。';
const String kUnlockModeChangeAuthFailedMessage = '驗證失敗，解鎖方式維持不變。';
const String kKeystoreMigrationInProgressMessage = '正在更新解鎖設定，請完成驗證…';

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

extension UnlockModeCapabilityFailureMessages on UnlockModeCapabilityFailure {
  String get message => switch (this) {
    UnlockModeCapabilityFailure.requiresUnlockedSession =>
      kUnlockModeChangeNeedsUnlockMessage,
    UnlockModeCapabilityFailure.requiresDeviceLock =>
      kUnlockModeNeedsDeviceLockMessage,
    UnlockModeCapabilityFailure.requiresBiometricEnrollment =>
      kBiometricNotEnrolledSwitchModeMessage,
  };
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
    throw StateError(failure.message);
  }
  return keystoreAuthFor(mode);
}

String lockedResumeMessageFor(AppUnlockMode mode, {required AppLocalizations l10n}) {
  return switch (mode) {
    AppUnlockMode.none => l10n.sessionUseDeviceLockToUnlockMessage,
    AppUnlockMode.deviceLock => l10n.sessionUseDeviceLockToUnlockMessage,
    AppUnlockMode.biometric => l10n.sessionStartupNeedsBiometricMessage,
  };
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

  final KeystoreAuthKind? sessionSlotKind = _slotAuthKind(session.deviceSlotId);
  if (sessionSlotKind != expected) {
    return false;
  }

  if (wrappedRecord == null) {
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

KeystoreAuthKind? _slotAuthKind(String? slotId) {
  if (slotId == null || slotId.isEmpty) {
    return null;
  }
  return KeystoreAuthKindWire.fromSlotId(slotId);
}
