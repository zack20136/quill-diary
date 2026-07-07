import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'vault_transfer_access.dart';

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
      // 擐活撱箇?敺拙??????vault session嚗ootstrap ??unlocked + session null嚗?
      canCreateRecoveryKey: !hasRecoveryKey,
      canManageDriveAccount: hasUnlockedSession,
      canChangeSessionTimeout: hasRecoveryKey && hasUnlockedSession,
    );
  }

  String lockedSettingMessage(AppLocalizations l10n) =>
      l10n.settingsUnlockRequiredToChangeSettingMessage;
}
