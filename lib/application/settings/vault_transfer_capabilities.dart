import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/l10n/l10n.dart';

class VaultTransferCapabilities {
  const VaultTransferCapabilities({
    required this.canBackup,
    required this.canRestore,
    this.backupDisabledReason,
    this.restoreDisabledReason,
  });

  final bool canBackup;
  final bool canRestore;
  final String? backupDisabledReason;
  final String? restoreDisabledReason;

  factory VaultTransferCapabilities.fromSessionContext({
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

    return VaultTransferCapabilities(
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
          : l10n.vaultTransferNeedsUnlockForRestore,
    );
  }

  void ensureCanRestore(AppLocalizations l10n) {
    if (canRestore) {
      return;
    }
    throw StateError(
      restoreDisabledReason ?? l10n.vaultTransferNeedsUnlockForRestore,
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
      return l10n.vaultTransferNeedsUnlockForBackup;
    }
    if (!hasRecoveryKey) {
      return l10n.vaultTransferNeedsRecoveryKeyForBackup;
    }
    return l10n.vaultTransferNeedsUnlockForBackup;
  }
}
