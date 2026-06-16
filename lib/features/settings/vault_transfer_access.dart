import '../session/state/app_session_state.dart';
import '../../l10n/l10n.dart';

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
    required AppLocalizations l10n,
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
              l10n: l10n,
            ),
      restoreDisabledReason: canRestore
          ? null
          : VaultTransferCopy.needsUnlockForRestore(l10n),
    );
  }

  /// 流程層防護：不符合還原條件時拋 [StateError]。
  void ensureCanRestore(AppLocalizations l10n) {
    if (canRestore) {
      return;
    }
    throw StateError(
      restoreDisabledReason ?? VaultTransferCopy.needsUnlockForRestore(l10n),
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
    required AppLocalizations l10n,
    required bool hasUnlockedSession,
    required bool hasRecoveryKey,
  }) {
    if (!hasUnlockedSession) {
      return VaultTransferCopy.needsUnlockForBackup(l10n);
    }
    if (!hasRecoveryKey) {
      return VaultTransferCopy.needsRecoveryKeyForBackup(l10n);
    }
    return VaultTransferCopy.needsUnlockForBackup(l10n);
  }
}

abstract final class VaultTransferCopy {
  static String needsUnlockForBackup(AppLocalizations l10n) =>
      l10n.vaultTransferNeedsUnlockForBackup;
  static String needsRecoveryKeyForBackup(AppLocalizations l10n) =>
      l10n.vaultTransferNeedsRecoveryKeyForBackup;
  static String needsUnlockForRestore(AppLocalizations l10n) =>
      l10n.vaultTransferNeedsUnlockForRestore;

  static String localSectionDescriptionBackupLocked(AppLocalizations l10n) =>
      l10n.vaultTransferLocalSectionDescriptionBackupLocked;

  static String driveSectionDescriptionBackupLocked(AppLocalizations l10n) =>
      l10n.vaultTransferDriveSectionDescriptionBackupLocked;

  static String driveBackupActionsLockedHint(AppLocalizations l10n) =>
      l10n.vaultTransferDriveBackupActionsLockedHint;

  static String restoreUnlockFailed(AppLocalizations l10n) =>
      l10n.vaultTransferRestoreUnlockFailed;
}
