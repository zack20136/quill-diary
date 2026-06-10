import 'package:cryptography/cryptography.dart';

import '../../infrastructure/database/index_database_errors.dart';
import '../../infrastructure/security/device_key_manager.dart';
import '../../shared/utils/user_facing_error.dart';
import '../settings/settings_copy.dart';
import 'state/app_session_state.dart';

export '../../infrastructure/security/unlock_mode_policy.dart'
    show
        kBiometricNotEnrolledSwitchModeMessage,
        kStartupNeedsBiometricMessage,
        kUnlockModeChangeNeedsUnlockMessage,
        kUnlockModeNeedsDeviceLockMessage,
        kUseDeviceLockToUnlockMessage;

const String kAndroidOnlyMessage = '此應用程式目前僅支援 Android。';
const String kStartupNeedsRecoveryKeyMessage = '尚未建立復原金鑰。';
const String kStartupNeedsTrustedDeviceMessage = '這台裝置尚未授權，請使用復原金鑰解鎖。';
const String kUnlockFailedMessage = '解鎖失敗，請再試一次。';
const String kRecoveryUnlockSuccessMessage = '已使用復原金鑰解鎖。';
const String kRecoverySetupSuccessMessage = '復原金鑰已建立，裝置保護已啟用。';
const String kAppLockedMessage = '應用程式已鎖定。';

const String kTrustedUnlockInProgressMessage = '正在以可信裝置解鎖…';
const String kLockedRetryVerificationMessage =
    '目前已鎖定。請重新完成裝置驗證，不必輸入復原金鑰。';
const String kUnlockModeNoneDescription =
    '回到前景時不額外驗證，直接以可信裝置解鎖。適合尚未設定螢幕鎖的裝置，安全性較低。';
const String kUnlockModeBiometricDescription =
    '回到前景時優先以指紋或臉部辨識解鎖，系統提示內可改用裝置螢幕鎖，不必輸入復原金鑰。';
const String kUnlockModeDeviceLockDescription =
    '回到前景時一律以裝置螢幕鎖（PIN、圖案或密碼）解鎖。請先在裝置設定中建立螢幕鎖。';
const String kRecoveryKeyRotatedMessage = '復原金鑰已更新，請立即保存新金鑰。';
const String kRecoveryRequiredAfterRestoreMessage =
    '還原後需輸入建立此備份時保存的復原金鑰。';
const String kRestoreNeedsUnlockMessage = SettingsSensitiveVaultCopy.needsUnlockMessage;
const String kSensitiveVaultTransferNeedsRecoveryKeyMessage =
    SettingsSensitiveVaultCopy.needsRecoveryKeyMessage;
const String kInvalidBackupFileMessage = '無法讀取備份檔，請確認檔案未損壞且為有效的 zip 備份。';
const String kRestoreInProgressMessage = '正在還原備份，請勿關閉應用程式…';
const String kPostRestoreStartupMessage = '正在啟動還原後的日記庫…';

const String kRestoreSuccessUnlockedMessage = '已還原備份，可以正常使用。';
const String kRestoreSuccessLockedMessage = '已還原備份。請完成生物驗證或裝置螢幕鎖驗證以繼續。';
const String kRestoreSuccessRecoveryRequiredMessage =
    '已還原備份。請在下方輸入建立此備份時保存的復原金鑰。';
const String kRestoreSuccessNeedsRecoveryKeySetupMessage =
    '已還原備份。此備份尚未建立復原金鑰，請先建立以保護日記庫。';
const String kRestoreStartupFailedMessage =
    '已還原備份，但啟動失敗。請到設定頁重試或輸入復原金鑰。';
const String kRecoveryKeyMismatchMessage =
    '復原金鑰與日記庫資料不相符。若為「更新復原金鑰」前的舊備份，請輸入建立該備份時保存的舊復原金鑰（不是目前這把新金鑰）。';
const String kTrustedUnlockFailedAfterRestoreMessage =
    '還原後無法以可信裝置自動解鎖。請在下方輸入建立此備份時保存的復原金鑰。';
const String kIndexDatabaseUnreadableMessage =
    '索引資料庫無法讀取（可能已損壞或與目前日記庫金鑰不相符）。請使用復原金鑰重新解鎖；若問題持續，可嘗試重新還原備份。';

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
