import 'package:cryptography/cryptography.dart';

import '../../infrastructure/database/index_database_errors.dart';
import '../../infrastructure/security/app_unlock_mode.dart';
import '../../infrastructure/security/device_key_manager.dart';
import '../../l10n/l10n.dart';
import '../../shared/utils/user_facing_error.dart';
import '../settings/settings_copy.dart';
import '../settings/vault_transfer_access.dart';
import 'state/app_session_state.dart';

export '../../infrastructure/security/unlock_mode_policy.dart'
    show
        kBiometricNotEnrolledSwitchModeMessage,
        kStartupNeedsBiometricMessage,
        kUnlockModeChangeNeedsUnlockMessage,
        kUnlockModeNeedsDeviceLockMessage,
        kUseDeviceLockToUnlockMessage;

bool get _isEn => currentAppLocalizations.localeName == 'en';
String _t(String zh, [String? en]) => _isEn ? (en ?? zh) : zh;

String get kAndroidOnlyMessage => SettingsPlatformCopy.sectionDescription;
String get kStartupNeedsRecoveryKeyMessage => _t('尚未建立復原金鑰。', 'No recovery key has been created yet.');
String get kStartupNeedsTrustedDeviceMessage =>
    _t('這台裝置尚未授權，請使用復原金鑰解鎖。', 'This device is not authorized yet. Unlock it with the recovery key.');
String get kUnlockFailedMessage => _t('解鎖失敗，請再試一次。', 'Unlock failed. Please try again.');
String get kRecoveryUnlockSuccessMessage => _t('已使用復原金鑰解鎖。', 'Unlocked with the recovery key.');
String get kRecoverySetupSuccessMessage =>
    _t('復原金鑰已建立，現在可以設定解鎖方式。', 'Recovery key created. You can now configure an unlock method.');
String get kAppLockedMessage => _t('應用程式已鎖定。', 'The app is locked.');

String get kTrustedUnlockInProgressMessage => _t('正在以可信裝置解鎖…', 'Unlocking with trusted device…');
String get kLockedRetryVerificationMessage =>
    _t('目前已鎖定。請重新完成裝置驗證，不必輸入復原金鑰。', 'The app is locked. Complete device verification again. No recovery key is required.');
String get kUnlockModeNoneDescription =>
    SettingsUnlockMethodCopy.unlockModeDescription(AppUnlockMode.none);
String get kUnlockModeBiometricDescription =>
    SettingsUnlockMethodCopy.unlockModeDescription(AppUnlockMode.biometric);
String get kUnlockModeDeviceLockDescription =>
    SettingsUnlockMethodCopy.unlockModeDescription(AppUnlockMode.deviceLock);
String get kRecoveryKeyRotatedMessage => _t('復原金鑰已更新，請立即保存新金鑰。', 'Recovery key updated. Save the new key now.');
String get kRecoveryRequiredAfterRestoreMessage =>
    _t('還原後需輸入建立此備份時保存的復原金鑰。', 'After restore, enter the recovery key saved when this backup was created.');
String get kRestoreNeedsUnlockMessage =>
    VaultTransferCopy.needsUnlockForRestore(currentAppLocalizations);
String get kSensitiveVaultTransferNeedsRecoveryKeyMessage =>
    VaultTransferCopy.needsRecoveryKeyForBackup(currentAppLocalizations);
String get kInvalidBackupFileMessage =>
    _t('無法讀取備份檔，請確認檔案未損壞且為有效的 zip 備份。', 'Unable to read the backup file. Make sure it is intact and a valid zip backup.');
String get kPostRestoreStartupMessage => SettingsBackupTaskProgressCopy.startingAfterRestore;

String get kRestoreSuccessUnlockedMessage => _t('已還原備份，可以正常使用。', 'Backup restored. Everything is ready to use.');
String get kRestoreSuccessLockedMessage =>
    _t('已還原備份。請完成生物驗證或螢幕鎖驗證以繼續。', 'Backup restored. Complete biometric or device-lock verification to continue.');
String get kRestoreSuccessRecoveryRequiredMessage =>
    _t('已還原備份。請輸入建立此備份時保存的復原金鑰。', 'Backup restored. Enter the recovery key saved when this backup was created.');
String get kRestoreSuccessNeedsRecoveryKeySetupMessage =>
    _t('已還原備份。此備份尚未建立復原金鑰，請先建立。', 'Backup restored. This backup does not have a recovery key yet. Create one first.');
String get kRestoreStartupFailedMessage =>
    _t('已還原備份，但啟動失敗。請到設定頁重試或輸入復原金鑰。', 'Backup restored, but startup failed. Retry from Settings or enter the recovery key.');
String get kRecoveryKeyMismatchMessage =>
    _t('復原金鑰不正確。若為更新復原金鑰前的舊備份，請輸入建立該備份時保存的舊金鑰。',
        'The recovery key is incorrect. If this is an older backup created before rotating the recovery key, enter the old key saved for that backup.');
String get kTrustedUnlockFailedAfterRestoreMessage =>
    _t('還原後無法自動解鎖。請輸入建立此備份時保存的復原金鑰。', 'Automatic unlock failed after restore. Enter the recovery key saved for this backup.');
String get kIndexDatabaseUnreadableMessage =>
    _t('搜尋索引無法讀取，可能已損壞。請用復原金鑰重新解鎖；若仍失敗，可嘗試重新還原備份。',
        'The search index cannot be read and may be corrupted. Unlock again with the recovery key, or try restoring the backup again if it still fails.');

final RegExp _userFacingTextPattern = RegExp(r'[\u4e00-\u9fff，。；：！？、]');

bool _looksLikeUserFacingText(String message) {
  final String trimmed = message.trim();
  return trimmed.isNotEmpty && _userFacingTextPattern.hasMatch(trimmed);
}

/// 將技術性錯誤轉成設定頁 / 安全鎖狀態可讀訊息。
String friendlySessionErrorMessage(
  Object error, {
  bool afterRestoreTrustedUnlock = false,
}) {
  if (error is SecretBoxAuthenticationError) {
    return afterRestoreTrustedUnlock
        ? kTrustedUnlockFailedAfterRestoreMessage
        : kRecoveryKeyMismatchMessage;
  }
  if (isUnreadableEncryptedIndexError(error)) {
    return kIndexDatabaseUnreadableMessage;
  }
  if (error is DeviceKeyUserCancelledException ||
      error is DeviceKeyAuthFailedException ||
      error is DeviceKeyAuthTimeoutException) {
    return kLockedRetryVerificationMessage;
  }
  if (error is DeviceKeyException) {
    return error.message;
  }
  if (error is StateError) {
    final String message = error.message.trim();
    if (afterRestoreTrustedUnlock &&
        (message.contains('不相符') || message.contains('驗證復原金鑰'))) {
      return kTrustedUnlockFailedAfterRestoreMessage;
    }
    if (_looksLikeUserFacingText(message)) {
      return stripLocalPathsFromMessage(message);
    }
    return kUnlockFailedMessage;
  }
  return kUnlockFailedMessage;
}

String snackbarMessageForPostRestore(AppLockStatus status, {String? sessionMessage}) {
  if (status == AppLockStatus.fatalError) {
    final String? message = sessionMessage?.trim();
    if (message == kIndexDatabaseUnreadableMessage ||
        message == kTrustedUnlockFailedAfterRestoreMessage ||
        message == kRecoveryRequiredAfterRestoreMessage) {
      return kRestoreSuccessRecoveryRequiredMessage;
    }
    if (message != null && _looksLikeUserFacingText(message)) {
      return message;
    }
    return kRestoreStartupFailedMessage;
  }

  return switch (status) {
    AppLockStatus.unlocked => sessionMessage == kStartupNeedsRecoveryKeyMessage
        ? kRestoreSuccessNeedsRecoveryKeySetupMessage
        : kRestoreSuccessUnlockedMessage,
    AppLockStatus.locked => kRestoreSuccessLockedMessage,
    AppLockStatus.recoveryRequired => kRestoreSuccessRecoveryRequiredMessage,
    _ => kRestoreSuccessUnlockedMessage,
  };
}
