import '../session/state/app_session_state.dart';

/// 設定頁備份／還原操作的存取政策（由 session 狀態一次算出）。
class VaultTransferAccess {
  const VaultTransferAccess({
    required this.canBackup,
    required this.canRestore,
    this.backupDisabledReason,
    this.restoreDisabledReason,
  });

  final bool canBackup;
  final bool canRestore;
  final String? backupDisabledReason;
  final String? restoreDisabledReason;

  factory VaultTransferAccess.fromContext({
    required bool hasUnlockedSession,
    required bool hasRecoveryKey,
    required AppLockStatus lockStatus,
  }) {
    final bool canBackup = hasUnlockedSession && hasRecoveryKey;
    final bool canRestore = _canRestoreWithoutUnlock(
      hasUnlockedSession: hasUnlockedSession,
      hasRecoveryKey: hasRecoveryKey,
      lockStatus: lockStatus,
    );

    return VaultTransferAccess(
      canBackup: canBackup,
      canRestore: canRestore,
      backupDisabledReason: canBackup
          ? null
          : _backupDisabledReason(
              hasUnlockedSession: hasUnlockedSession,
              hasRecoveryKey: hasRecoveryKey,
            ),
      restoreDisabledReason: canRestore
          ? null
          : VaultTransferCopy.needsUnlockForRestore,
    );
  }

  /// 流程層防護：不符合還原條件時拋 [StateError]。
  void ensureCanRestore() {
    if (canRestore) {
      return;
    }
    throw StateError(
      restoreDisabledReason ?? VaultTransferCopy.needsUnlockForRestore,
    );
  }

  static bool _canRestoreWithoutUnlock({
    required bool hasUnlockedSession,
    required bool hasRecoveryKey,
    required AppLockStatus lockStatus,
  }) {
    if (hasUnlockedSession) {
      return true;
    }
    if (!hasRecoveryKey) {
      return true;
    }
    if (lockStatus == AppLockStatus.recoveryRequired) {
      return true;
    }
    return false;
  }

  static String _backupDisabledReason({
    required bool hasUnlockedSession,
    required bool hasRecoveryKey,
  }) {
    if (!hasUnlockedSession) {
      return VaultTransferCopy.needsUnlockForBackup;
    }
    if (!hasRecoveryKey) {
      return VaultTransferCopy.needsRecoveryKeyForBackup;
    }
    return VaultTransferCopy.needsUnlockForBackup;
  }
}

abstract final class VaultTransferCopy {
  static const String needsUnlockForBackup =
      '請先解鎖日記庫，才能備份或匯出。';
  static const String needsRecoveryKeyForBackup =
      '請先建立復原金鑰，才能備份或匯出。';
  static const String needsUnlockForRestore =
      '請先解鎖日記庫，才能還原備份。';

  static const String localSectionDescriptionBackupLocked =
      '建立本機備份與匯出需先解鎖日記庫並建立復原金鑰；'
      '尚未建立復原金鑰或忘記金鑰時，可直接匯入外部備份還原。';

  static const String driveSectionDescriptionBackupLocked =
      '備份到 Google Drive 需先解鎖日記庫並建立復原金鑰；'
      '尚未建立復原金鑰或忘記金鑰時，可直接從 Google Drive 還原。';

  static const String driveBackupActionsLockedHint =
      '請先解鎖日記庫並建立復原金鑰，才能備份到 Google Drive。';

  static const String restoreUnlockFailed =
      '備份已還原，但復原金鑰解鎖失敗。請在安全總覽重新輸入復原金鑰。';
}
