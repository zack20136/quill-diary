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
const String kRecoveryRequiredAfterRestoreMessage =
    '還原後需輸入建立此備份時保存的復原金鑰。';
const String kRestoreNeedsUnlockMessage = '請先解鎖日記庫後，再進行備份或還原。';
const String kInvalidBackupFileMessage = '無法讀取備份檔，請確認檔案未損壞且為有效的 .jbackup。';
const String kRestoreInProgressMessage = '正在還原備份，請勿關閉應用程式…';

const String kRestoreSuccessUnlockedMessage = '已還原備份，可以正常使用。';
const String kRestoreSuccessLockedMessage = '已還原備份。請完成生物辨識或裝置驗證以繼續。';
const String kRestoreSuccessRecoveryRequiredMessage =
    '已還原備份。請在下方輸入建立此備份時保存的復原金鑰。';
const String kRestoreSuccessNeedsRecoveryKeySetupMessage =
    '已還原備份。此備份尚未建立復原金鑰，請先建立以保護日記庫。';
const String kRestoreStartupFailedMessage = '已還原備份，但啟動失敗：';

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
