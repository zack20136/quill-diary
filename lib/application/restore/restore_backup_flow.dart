import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/settings/vault_transfer_capabilities.dart';
import 'post_restore_session.dart';
import 'restore_prepared_context.dart';

class RestoreBackupFlow {
  RestoreBackupFlow(this.ref);

  final WidgetRef ref;

  Future<VaultTransferCapabilities> _loadTransferCapabilities(
    AppLocalizations l10n,
  ) async {
    final AppSessionState sessionState = await ref.read(
      effectiveAppSessionProvider.future,
    );
    final bool hasUnlockedSession =
        sessionState.isUnlocked && sessionState.session != null;
    final bool hasRecoveryKey =
        await ref.read(vaultRepositoryProvider).readRecoveryMetadata() != null;
    return VaultTransferCapabilities.fromSessionContext(
      l10n: l10n,
      hasUnlockedSession: hasUnlockedSession,
      hasRecoveryKey: hasRecoveryKey,
      lockStatus: sessionState.status,
    );
  }

  Future<void> ensureRestoreAllowed(AppLocalizations l10n) async {
    final VaultTransferCapabilities access = await _loadTransferCapabilities(
      l10n,
    );
    access.ensureCanRestore(l10n);
  }

  Future<void> verifyBackupRecoveryKey(
    File backupFile,
    String recoveryKey,
  ) async {
    await ref
        .read(vaultTransferServiceProvider)
        .verifyBackupRecoveryKey(backupFile, recoveryKey);
  }

  Future<UnlockedVaultSession?> executeRestore({
    required File backupFile,
    required RestorePreparedContext prepared,
    BackupTaskProgressListener? onProgress,
  }) async {
    final transferService = ref.read(vaultTransferServiceProvider);
    final AppSessionController sessionController = ref.read(
      appSessionProvider.notifier,
    );
    final AppSessionState liveState = ref.read(appSessionProvider);
    final UnlockedVaultSession? liveSession = liveState.isUnlocked
        ? liveState.session
        : null;
    final bool hasActiveSession = liveSession != null;
    final UnlockedVaultSession? livePriorSession =
        prepared.precheck.canResumeTrustedSession(liveSession)
        ? liveSession
        : null;

    Future<void> restoreBackup() async {
      await transferService.restoreFromBackupFile(
        backupFile,
        preserveTrustedDeviceAccess:
            prepared.precheck.expectsTrustedUnlockAfterRestore,
        onProgress: onProgress,
      );
    }

    if (hasActiveSession) {
      await sessionController.runSensitiveTask((_) => restoreBackup());
    } else {
      await sessionController.runBackgroundSafeTask(() async {
        await ref.read(vaultRepositoryProvider).closeUnlockedResources();
        await restoreBackup();
      });
    }
    return livePriorSession;
  }

  Future<AppSessionState> executeRestoreAndFinishSession({
    required File backupFile,
    required RestorePreparedContext prepared,
    BackupTaskProgressListener? onProgress,
  }) async {
    final UnlockedVaultSession? livePriorSession = await executeRestore(
      backupFile: backupFile,
      prepared: prepared,
      onProgress: onProgress,
    );
    onProgress?.call(BackupTaskProgress.startingAfterRestore);
    return finishRestoreSession(
      ref,
      prepared: prepared,
      livePriorSession: livePriorSession,
    );
  }
}
