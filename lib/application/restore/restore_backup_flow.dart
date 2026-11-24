import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/restore/post_restore_session.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/vault_transfer_capabilities.dart';
import 'package:quill_diary/application/transfer/vault_backup_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';

class RestoreBackupFlow {
  RestoreBackupFlow(this.ref);

  final Ref ref;

  Future<void> ensureRestoreAllowed() async {
    final AppSessionState sessionState = await ref.read(
      effectiveAppSessionProvider.future,
    );
    final bool hasUnlockedSession =
        sessionState.isUnlocked && sessionState.session != null;
    final bool hasRecoveryKey =
        await ref.read(vaultRepositoryProvider).readRecoveryMetadata() != null;
    VaultTransferCapabilities.fromSessionContext(
      hasUnlockedSession: hasUnlockedSession,
      hasRecoveryKey: hasRecoveryKey,
      lockStatus: sessionState.status,
    ).ensureCanRestore();
  }

  Future<VerifiedBackupKey> verifyBackupRecoveryKey(
    File backupFile,
    String recoveryKey,
  ) => ref
      .read(vaultRestoreServiceProvider)
      .verifyBackupRecoveryKey(backupFile, recoveryKey);

  Future<void> executeRestoreAndFinishSession({
    required File backupFile,
    required RestorePreparedContext prepared,
    BackupTaskProgressListener? onProgress,
  }) async {
    final state = ref.read(appSessionProvider);
    final controller = ref.read(appSessionProvider.notifier);
    final transfer = ref.read(vaultRestoreServiceProvider);

    Future<void> restore() async {
      final restored = await transfer.restoreFromBackupFile(
        backupFile,
        expectedPreview: prepared.precheck.preview,
        verifiedKey: prepared.verifiedKey,
        preserveTrustedDeviceAccess:
            prepared.verifiedKey == null &&
            prepared.precheck.canResumeTrustedSession(state.session),
        onProgress: onProgress,
      );
      onProgress?.call(BackupTaskProgress.startingAfterRestore);
      return finishRestoreSession(ref, restored);
    }

    return state.isUnlocked && state.session != null
        ? controller.runSensitiveTask((_) => restore())
        : controller.runBackgroundSafeTask(restore);
  }
}

class RestorePreparedContext {
  const RestorePreparedContext({required this.precheck, this.verifiedKey});

  final RestorePrecheck precheck;
  final VerifiedBackupKey? verifiedKey;
}
