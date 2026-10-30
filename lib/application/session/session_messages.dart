import 'package:cryptography/cryptography.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/infrastructure/database/index_database_errors.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/security/unlock_mode_policy.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/l10n/l10n.dart';

String friendlySessionErrorMessage(
  AppLocalizations l10n,
  Object error, {
  bool afterRestoreTrustedUnlock = false,
}) {
  if (error is SecretBoxAuthenticationError) {
    return afterRestoreTrustedUnlock
        ? l10n.sessionTrustedUnlockFailedAfterRestoreMessage
        : l10n.sessionRecoveryKeyMismatchMessage;
  }
  if (isUnreadableEncryptedIndexError(error)) {
    return l10n.sessionIndexDatabaseUnreadableMessage;
  }
  if (error is UnlockModeCapabilityException) {
    return switch (error.failure) {
      UnlockModeCapabilityFailure.requiresUnlockedSession =>
        l10n.sessionUnlockModeChangeNeedsUnlockMessage,
      UnlockModeCapabilityFailure.requiresDeviceLock =>
        l10n.sessionUnlockModeNeedsDeviceLockMessage,
      UnlockModeCapabilityFailure.requiresBiometricEnrollment =>
        l10n.sessionBiometricNotEnrolledSwitchModeMessage,
    };
  }
  if (error is TrustedSessionException) {
    return switch (error.failure) {
      TrustedSessionFailure.recoveryKeyMissing =>
        l10n.sessionStartupNeedsRecoveryKeyMessage,
      TrustedSessionFailure.deviceNotRegistered =>
        l10n.sessionTrustedDeviceNotRegisteredMessage,
      TrustedSessionFailure.dataUnusable =>
        l10n.sessionTrustedDeviceDataUnusableMessage,
    };
  }
  if (error is DeviceKeyUserCancelledException ||
      error is DeviceKeyAuthFailedException ||
      error is DeviceKeyAuthTimeoutException) {
    return l10n.sessionLockedRetryVerificationMessage;
  }
  if (error is DeviceKeyAuthLockoutException) {
    return l10n.sessionDeviceKeyAuthLockoutMessage;
  }
  if (error is DeviceKeyNoDeviceCredentialException) {
    return l10n.sessionUnlockModeNeedsDeviceLockMessage;
  }
  if (error is DeviceKeyBiometricNotEnrolledException) {
    return l10n.sessionBiometricNotEnrolledSwitchModeMessage;
  }
  if (error is DeviceKeyUnsupportedFormatException) {
    return l10n.sessionDeviceKeyUnsupportedFormatMessage;
  }
  if (error is DeviceKeyInvalidatedException) {
    return l10n.sessionDeviceKeyInvalidatedMessage;
  }
  if (error is DeviceKeyException) {
    return l10n.sessionUnlockFailedMessage;
  }
  return l10n.sessionUnlockFailedMessage;
}

String snackbarMessageForPostRestore(
  AppLocalizations l10n,
  AppLockStatus status,
) {
  return switch (status) {
    AppLockStatus.unlocked => l10n.sessionRestoreSuccessUnlockedMessage,
    AppLockStatus.locked => l10n.sessionRestoreSuccessLockedMessage,
    AppLockStatus.recoveryRequired =>
      l10n.sessionRestoreSuccessRecoveryRequiredMessage,
    AppLockStatus.fatalError => l10n.sessionRestoreStartupFailedMessage,
    _ => l10n.sessionRestoreStartupFailedMessage,
  };
}

String lockedResumeMessageFor(
  AppUnlockMode mode, {
  required AppLocalizations l10n,
}) {
  return switch (mode) {
    AppUnlockMode.none => l10n.sessionNoneModeLockedMessage,
    AppUnlockMode.deviceLock => l10n.sessionUseDeviceLockToUnlockMessage,
    AppUnlockMode.biometric => l10n.sessionStartupNeedsBiometricMessage,
  };
}
