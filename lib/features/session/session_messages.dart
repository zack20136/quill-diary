import 'package:cryptography/cryptography.dart';

import '../settings/settings_copy.dart';
import 'state/app_session_state.dart';

const String kAndroidOnlyMessage = '此應用程式目前僅支援 Android。';
const String kStartupNeedsRecoveryKeyMessage = '尚未建立復原金鑰。';
const String kStartupNeedsTrustedDeviceMessage = '這台裝置尚未授權，請使用復原金鑰解鎖。';
const String kStartupNeedsBiometricMessage = '請先完成生物驗證。';
const String kUnlockFailedMessage = '解鎖失敗，請再試一次。';
const String kRecoveryUnlockSuccessMessage = '已使用復原金鑰解鎖。';
const String kRecoverySetupSuccessMessage = '復原金鑰已建立，裝置保護已啟用。';
const String kAppLockedMessage = '應用程式已鎖定。';

const String kTrustedUnlockInProgressMessage = '正在以本機受信任裝置解鎖…';
const String kLockedRetryVerificationMessage =
    '目前已鎖定。請重新完成裝置驗證，不必輸入復原金鑰。';
const String kUseDeviceLockToUnlockMessage = '請使用裝置螢幕鎖解鎖。';
const String kBiometricFallbackDeviceLockMessage =
    '生物驗證已取消。可改用裝置螢幕鎖解鎖。';
const String kBiometricNotEnrolledSwitchModeMessage =
    '裝置尚未登錄指紋或臉部。請到設定改為「生物驗證」、「裝置螢幕鎖」或「無」。';
const String kUnlockModeNoneDescription =
    '回到前景時直接沿用本機受信任裝置，不會再跳出指紋或螢幕鎖對話框。適合已信任本機、且希望操作最順暢的情況。';
const String kUnlockModeBiometricDescription =
    '回到前景時優先以指紋或臉部辨識解鎖。若你取消驗證或辨識失敗，可改以裝置螢幕鎖繼續，不必輸入復原金鑰。';
const String kUnlockModeDeviceLockDescription =
    '回到前景時一律以裝置螢幕鎖（PIN、圖案或密碼）解鎖。請先在裝置設定中建立螢幕鎖。';
const String kUnlockModeNeedsDeviceLockMessage = '請先在裝置設定中建立螢幕鎖，才能使用此模式。';
const String kRecoveryKeyRotatedMessage = '復原金鑰已更新，請立即保存新金鑰。';
const String kRecoveryRequiredAfterRestoreMessage =
    '還原後需輸入建立此備份時保存的復原金鑰。';
const String kRestoreNeedsUnlockMessage = SettingsSensitiveVaultCopy.needsUnlockMessage;
const String kSensitiveVaultTransferNeedsRecoveryKeyMessage =
    SettingsSensitiveVaultCopy.needsRecoveryKeyMessage;
const String kInvalidBackupFileMessage = '無法讀取備份檔，請確認檔案未損壞且為有效的 .jbackup。';
const String kRestoreInProgressMessage = '正在還原備份，請勿關閉應用程式…';

const String kRestoreSuccessUnlockedMessage = '已還原備份，可以正常使用。';
const String kRestoreSuccessLockedMessage = '已還原備份。請完成生物驗證或裝置螢幕鎖驗證以繼續。';
const String kRestoreSuccessRecoveryRequiredMessage =
    '已還原備份。請在下方輸入建立此備份時保存的復原金鑰。';
const String kRestoreSuccessNeedsRecoveryKeySetupMessage =
    '已還原備份。此備份尚未建立復原金鑰，請先建立以保護日記庫。';
const String kRestoreStartupFailedMessage = '已還原備份，但啟動失敗：';
const String kRecoveryKeyMismatchMessage =
    '復原金鑰與日記庫資料不相符。若為「更新復原金鑰」前的舊備份，請輸入建立該備份時保存的舊復原金鑰（不是目前這把新金鑰）。';
const String kTrustedUnlockFailedAfterRestoreMessage =
    '還原後無法以本機受信任裝置自動解鎖。請在下方輸入建立此備份時保存的復原金鑰。';

/// 將技術性錯誤轉成設定頁／安全鎖狀態可讀訊息。
String friendlySessionErrorMessage(
  Object error, {
  bool afterRestoreTrustedUnlock = false,
}) {
  if (error is SecretBoxAuthenticationError) {
    return afterRestoreTrustedUnlock
        ? kTrustedUnlockFailedAfterRestoreMessage
        : kRecoveryKeyMismatchMessage;
  }
  if (error is StateError) {
    final String message = error.message;
    if (afterRestoreTrustedUnlock &&
        (message.contains('不相符') || message.contains('驗證復原金鑰'))) {
      return kTrustedUnlockFailedAfterRestoreMessage;
    }
    return message;
  }
  return '$error';
}

String snackbarMessageForPostRestore(AppLockStatus status, {String? sessionMessage}) {
  return switch (status) {
    AppLockStatus.unlocked => sessionMessage == kStartupNeedsRecoveryKeyMessage
        ? kRestoreSuccessNeedsRecoveryKeySetupMessage
        : kRestoreSuccessUnlockedMessage,
    AppLockStatus.locked => kRestoreSuccessLockedMessage,
    AppLockStatus.recoveryRequired => kRestoreSuccessRecoveryRequiredMessage,
    AppLockStatus.fatalError => '$kRestoreStartupFailedMessage${sessionMessage ?? ''}',
    _ => kRestoreSuccessUnlockedMessage,
  };
}
