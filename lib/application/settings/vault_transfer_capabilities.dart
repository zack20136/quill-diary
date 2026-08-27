import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/l10n/l10n.dart';

class VaultTransferCapabilities {
  const VaultTransferCapabilities({
    required this.canBackup,
    required this.canPortableTransfer,
    required this.canRestore,
    this.backupDisabledReason,
    this.portableTransferDisabledReason,
    this.restoreDisabledReason,
  });

  /// 完整備份／匯出本機或 Drive 備份（需解鎖 + Recovery Key）。
  final bool canBackup;

  /// 可攜式匯入／Markdown／HTML 匯出（只需解鎖 session）。
  final bool canPortableTransfer;

  final bool canRestore;
  final String? backupDisabledReason;
  final String? portableTransferDisabledReason;
  final String? restoreDisabledReason;

  factory VaultTransferCapabilities.fromSessionContext({
    required AppLocalizations l10n,
    required bool hasUnlockedSession,
    required bool hasRecoveryKey,
    required AppLockStatus lockStatus,
  }) {
    final bool canBackup = hasUnlockedSession && hasRecoveryKey;
    final bool canPortableTransfer = hasUnlockedSession;
    final bool canRestore = _canRestoreWithoutUnlock(
      hasUnlockedSession: hasUnlockedSession,
      hasRecoveryKey: hasRecoveryKey,
      lockStatus: lockStatus,
    );

    return VaultTransferCapabilities(
      canBackup: canBackup,
      canPortableTransfer: canPortableTransfer,
      canRestore: canRestore,
      backupDisabledReason: canBackup
          ? null
          : _backupDisabledReason(
              hasUnlockedSession: hasUnlockedSession,
              hasRecoveryKey: hasRecoveryKey,
              l10n: l10n,
            ),
      portableTransferDisabledReason: canPortableTransfer
          ? null
          : l10n.vaultTransferNeedsUnlockForPortableTransfer,
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
