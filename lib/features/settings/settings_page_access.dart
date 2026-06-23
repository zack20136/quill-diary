import '../session/state/app_session_state.dart';
import '../../l10n/l10n.dart';
import 'vault_transfer_access.dart';

/// 設定與個人化頁的 session 互動政策（由 session 狀態一次算出）。
class SettingsPageAccess {
  const SettingsPageAccess({
    required this.hasUnlockedSession,
    required this.hasRecoveryKey,
    required this.vaultTransfer,
    required this.canCreateRecoveryKey,
    required this.canManageDriveAccount,
    required this.canChangeSessionTimeout,
  });

  final bool hasUnlockedSession;
  final bool hasRecoveryKey;
  final VaultTransferAccess vaultTransfer;
  final bool canCreateRecoveryKey;
  final bool canManageDriveAccount;
  final bool canChangeSessionTimeout;

  factory SettingsPageAccess.fromSession({
    required AppLocalizations l10n,
    required AppSessionState? sessionState,
    required bool hasRecoveryKey,
  }) {
    final bool hasUnlockedSession =
        sessionState?.isUnlocked == true && sessionState?.session != null;
    final AppLockStatus lockStatus =
        sessionState?.status ?? AppLockStatus.uninitialized;
    final VaultTransferAccess vaultTransfer = VaultTransferAccess.fromContext(
      l10n: l10n,
      hasUnlockedSession: hasUnlockedSession,
      hasRecoveryKey: hasRecoveryKey,
      lockStatus: lockStatus,
    );

    return SettingsPageAccess(
      hasUnlockedSession: hasUnlockedSession,
      hasRecoveryKey: hasRecoveryKey,
      vaultTransfer: vaultTransfer,
      // 首次建立復原金鑰時尚無 vault session（bootstrap 為 unlocked + session null）。
      canCreateRecoveryKey: !hasRecoveryKey,
      canManageDriveAccount: hasUnlockedSession,
      canChangeSessionTimeout: hasRecoveryKey && hasUnlockedSession,
    );
  }

  String lockedSettingMessage(AppLocalizations l10n) =>
      l10n.settingsUnlockRequiredToChangeSettingMessage;
}
