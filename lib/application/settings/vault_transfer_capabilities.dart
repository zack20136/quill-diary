import 'package:quill_diary/application/session/session_state.dart';

enum VaultTransferBlock {
  backupNeedsUnlock,
  backupNeedsRecoveryKey,
  portableNeedsUnlock,
  restoreNeedsUnlock,
}

class VaultTransferBlockedException implements Exception {
  const VaultTransferBlockedException(this.reason);
  final VaultTransferBlock reason;
}

class VaultTransferCapabilities {
  const VaultTransferCapabilities({
    required this.canBackup,
    required this.canPortableTransfer,
    required this.canRestore,
    this.backupDisabledReason,
    this.portableTransferDisabledReason,
    this.restoreDisabledReason,
  });
  final bool canBackup;
  final bool canPortableTransfer;
  final bool canRestore;
  final VaultTransferBlock? backupDisabledReason;
  final VaultTransferBlock? portableTransferDisabledReason;
  final VaultTransferBlock? restoreDisabledReason;

  factory VaultTransferCapabilities.fromSessionContext({
    required bool hasUnlockedSession,
    required bool hasRecoveryKey,
    required AppLockStatus lockStatus,
  }) {
    final canBackup = hasUnlockedSession && hasRecoveryKey;
    final canRestore =
        hasUnlockedSession ||
        !hasRecoveryKey ||
        lockStatus == AppLockStatus.recoveryRequired;
    return VaultTransferCapabilities(
      canBackup: canBackup,
      canPortableTransfer: hasUnlockedSession,
      canRestore: canRestore,
      backupDisabledReason: canBackup
          ? null
          : !hasUnlockedSession
          ? VaultTransferBlock.backupNeedsUnlock
          : VaultTransferBlock.backupNeedsRecoveryKey,
      portableTransferDisabledReason: hasUnlockedSession
          ? null
          : VaultTransferBlock.portableNeedsUnlock,
      restoreDisabledReason: canRestore
          ? null
          : VaultTransferBlock.restoreNeedsUnlock,
    );
  }

  void ensureCanRestore() {
    if (!canRestore) {
      throw VaultTransferBlockedException(
        restoreDisabledReason ?? VaultTransferBlock.restoreNeedsUnlock,
      );
    }
  }
}
