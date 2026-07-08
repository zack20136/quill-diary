import 'package:cryptography/cryptography.dart';

import 'package:quill_diary/infrastructure/database/index_database_errors.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/application/settings/settings_text.dart';
import 'package:quill_diary/shared/utils/user_facing_error.dart';
import 'state/app_session_state.dart';

export '../../infrastructure/security/unlock_mode_policy.dart'
    show
        kBiometricNotEnrolledSwitchModeMessage,
        kStartupNeedsBiometricMessage,
        kUnlockModeChangeNeedsUnlockMessage,
        kUnlockModeNeedsDeviceLockMessage,
        kUseDeviceLockToUnlockMessage;

String sessionUnsupportedRuntimeMessage(AppLocalizations l10n) =>
    l10n.sessionUnsupportedRuntimeMessage;

String sessionStartupNeedsRecoveryKeyMessage(AppLocalizations l10n) =>
    l10n.sessionStartupNeedsRecoveryKeyMessage;

String sessionStartupNeedsTrustedDeviceMessage(AppLocalizations l10n) =>
    l10n.sessionStartupNeedsTrustedDeviceMessage;

String sessionUnlockFailedMessage(AppLocalizations l10n) =>
    l10n.sessionUnlockFailedMessage;

String sessionRecoveryUnlockSuccessMessage(AppLocalizations l10n) =>
    l10n.sessionRecoveryUnlockSuccessMessage;

String sessionRecoverySetupSuccessMessage(AppLocalizations l10n) =>
    l10n.sessionRecoverySetupSuccessMessage;

String sessionAppLockedMessage(AppLocalizations l10n) =>
    l10n.sessionAppLockedMessage;

String sessionTrustedUnlockInProgressMessage(AppLocalizations l10n) =>
    l10n.sessionTrustedUnlockInProgressMessage;

String sessionLockedRetryVerificationMessage(AppLocalizations l10n) =>
    l10n.sessionLockedRetryVerificationMessage;

String sessionUnlockModeNoneDescription(AppLocalizations l10n) =>
    AppUnlockMode.none.description(l10n);

String sessionUnlockModeBiometricDescription(AppLocalizations l10n) =>
    AppUnlockMode.biometric.description(l10n);

String sessionUnlockModeDeviceLockDescription(AppLocalizations l10n) =>
    AppUnlockMode.deviceLock.description(l10n);

String sessionRecoveryKeyRotatedMessage(AppLocalizations l10n) =>
    l10n.sessionRecoveryKeyRotatedMessage;

String sessionRecoveryRequiredAfterRestoreMessage(AppLocalizations l10n) =>
    l10n.sessionRecoveryRequiredAfterRestoreMessage;

String sessionRestoreNeedsUnlockMessage(AppLocalizations l10n) =>
    l10n.vaultTransferNeedsUnlockForRestore;

String sessionSensitiveVaultTransferNeedsRecoveryKeyMessage(
  AppLocalizations l10n,
) => l10n.vaultTransferNeedsRecoveryKeyForBackup;

String sessionInvalidBackupFileMessage(AppLocalizations l10n) =>
    l10n.sessionInvalidBackupFileMessage;

String sessionPostRestoreStartupMessage(AppLocalizations l10n) =>
    l10n.settingsBackupStartingAfterRestore;

String sessionRestoreSuccessUnlockedMessage(AppLocalizations l10n) =>
    l10n.sessionRestoreSuccessUnlockedMessage;

String sessionRestoreSuccessLockedMessage(AppLocalizations l10n) =>
    l10n.sessionRestoreSuccessLockedMessage;

String sessionRestoreSuccessRecoveryRequiredMessage(AppLocalizations l10n) =>
    l10n.sessionRestoreSuccessRecoveryRequiredMessage;

String sessionRestoreStartupFailedMessage(AppLocalizations l10n) =>
    l10n.sessionRestoreStartupFailedMessage;

String sessionRecoveryKeyMismatchMessage(AppLocalizations l10n) =>
    l10n.sessionRecoveryKeyMismatchMessage;

String sessionTrustedUnlockFailedAfterRestoreMessage(AppLocalizations l10n) =>
    l10n.sessionTrustedUnlockFailedAfterRestoreMessage;

String sessionIndexDatabaseUnreadableMessage(AppLocalizations l10n) =>
    l10n.sessionIndexDatabaseUnreadableMessage;

bool isIndexRelatedSessionMessage(AppLocalizations l10n, String? message) {
  final String trimmed = message?.trim() ?? '';
  if (trimmed.isEmpty) {
    return false;
  }
  return trimmed == sessionIndexDatabaseUnreadableMessage(l10n);
}

final RegExp _userFacingTextPattern = RegExp(r'[\u4e00-\u9fff，。；：！？、]');

bool _looksLikeUserFacingText(String message) {
  final String trimmed = message.trim();
  return trimmed.isNotEmpty && _userFacingTextPattern.hasMatch(trimmed);
}

String friendlySessionErrorMessage(
  AppLocalizations l10n,
  Object error, {
  bool afterRestoreTrustedUnlock = false,
}) {
  if (error is SecretBoxAuthenticationError) {
    return afterRestoreTrustedUnlock
        ? sessionTrustedUnlockFailedAfterRestoreMessage(l10n)
        : sessionRecoveryKeyMismatchMessage(l10n);
  }
  if (isUnreadableEncryptedIndexError(error)) {
    return sessionIndexDatabaseUnreadableMessage(l10n);
  }
  if (error is DeviceKeyUserCancelledException ||
      error is DeviceKeyAuthFailedException ||
      error is DeviceKeyAuthTimeoutException) {
    return sessionLockedRetryVerificationMessage(l10n);
  }
  if (error is DeviceKeyException) {
    return error.message;
  }
  if (error is StateError) {
    final String message = error.message.trim();
    if (afterRestoreTrustedUnlock &&
        (message.contains('不相符') || message.contains('驗證復原金鑰'))) {
      return sessionTrustedUnlockFailedAfterRestoreMessage(l10n);
    }
    if (_looksLikeUserFacingText(message)) {
      return stripLocalPathsFromMessage(message, l10n: l10n);
    }
    return sessionUnlockFailedMessage(l10n);
  }
  return sessionUnlockFailedMessage(l10n);
}

String snackbarMessageForPostRestore(
  AppLocalizations l10n,
  AppLockStatus status,
) {
  return switch (status) {
    AppLockStatus.unlocked => sessionRestoreSuccessUnlockedMessage(l10n),
    AppLockStatus.locked => sessionRestoreSuccessLockedMessage(l10n),
    AppLockStatus.recoveryRequired =>
      sessionRestoreSuccessRecoveryRequiredMessage(l10n),
    AppLockStatus.fatalError => sessionRestoreStartupFailedMessage(l10n),
    _ => sessionRestoreStartupFailedMessage(l10n),
  };
}
