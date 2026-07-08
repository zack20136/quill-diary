import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/settings/vault_transfer_capabilities.dart';
import 'package:quill_diary/l10n/l10n.dart';

class SettingsPageCapabilities {
  const SettingsPageCapabilities({
    required this.hasUnlockedSession,
    required this.hasRecoveryKey,
    required this.vaultTransferCapabilities,
    required this.canCreateRecoveryKey,
    required this.canManageDriveAccount,
    required this.canChangeSessionTimeout,
  });

  final bool hasUnlockedSession;
  final bool hasRecoveryKey;
  final VaultTransferCapabilities vaultTransferCapabilities;
  final bool canCreateRecoveryKey;
  final bool canManageDriveAccount;
  final bool canChangeSessionTimeout;

  factory SettingsPageCapabilities.fromSessionState({
    required AppLocalizations l10n,
    required AppSessionState? sessionState,
    required bool hasRecoveryKey,
  }) {
    final bool hasUnlockedSession =
        sessionState?.isUnlocked == true && sessionState?.session != null;
    final AppLockStatus lockStatus =
        sessionState?.status ?? AppLockStatus.uninitialized;
    final VaultTransferCapabilities vaultTransferCapabilities =
        VaultTransferCapabilities.fromSessionContext(
          l10n: l10n,
          hasUnlockedSession: hasUnlockedSession,
          hasRecoveryKey: hasRecoveryKey,
          lockStatus: lockStatus,
        );

    return SettingsPageCapabilities(
      hasUnlockedSession: hasUnlockedSession,
      hasRecoveryKey: hasRecoveryKey,
      vaultTransferCapabilities: vaultTransferCapabilities,
      // 建立復原金鑰只取決於 metadata 是否已存在，不依賴暫時性的 session 狀態。
      canCreateRecoveryKey: !hasRecoveryKey,
      canManageDriveAccount: hasUnlockedSession,
      canChangeSessionTimeout: hasRecoveryKey && hasUnlockedSession,
    );
  }

  String lockedSettingMessage(AppLocalizations l10n) =>
      l10n.settingsUnlockRequiredToChangeSettingMessage;
}
