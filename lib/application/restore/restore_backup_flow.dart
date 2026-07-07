import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/infrastructure/providers/core_providers.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/presentation/settings/vault_transfer_access.dart';
import 'post_restore_session.dart';
import 'restore_prepared_context.dart';
import 'package:quill_diary/presentation/restore/widgets/restore_recovery_key_dialog.dart';

class RestoreBackupFlow {
  RestoreBackupFlow(this.ref);

  final WidgetRef ref;

  Future<VaultTransferAccess> _loadTransferAccess(AppLocalizations l10n) async {
    final AppSessionState sessionState = await ref.read(
      effectiveAppSessionProvider.future,
    );
    final bool hasUnlockedSession =
        sessionState.isUnlocked && sessionState.session != null;
    final bool hasRecoveryKey =
        await ref.read(vaultRepositoryProvider).readRecoveryMetadata() != null;
    return VaultTransferAccess.fromContext(
      l10n: l10n,
      hasUnlockedSession: hasUnlockedSession,
      hasRecoveryKey: hasRecoveryKey,
      lockStatus: sessionState.status,
    );
  }

  Future<String?> collectValidatedRecoveryKey(
    BuildContext context,
    File backupFile,
    RestorePrecheck precheck,
  ) async {
    final transferService = ref.read(vaultTransferServiceProvider);
    String? validationError;
    while (true) {
      if (!context.mounted) {
        return null;
      }
      final String? key = await showRestoreRecoveryKeyDialog(
        context,
        precheck: precheck,
        validationError: validationError,
      );
      if (key == null) {
        return null;
      }
      try {
        await transferService.verifyBackupRecoveryKey(backupFile, key);
        return key;
      } on StateError catch (error) {
        validationError = error.message;
      }
    }
  }

  Future<RestorePreparedContext?> prepare({
    required BuildContext context,
    required File backupFile,
    required RestorePrecheck precheck,
    required Future<bool> Function(
      RestorePrecheck precheck, {
      String? driveBackupName,
    })
    confirm,
    String? driveBackupName,
  }) async {
    final AppLocalizations l10n = context.l10n;
    final VaultTransferAccess access = await _loadTransferAccess(l10n);
    access.ensureCanRestore(l10n);

    if (!context.mounted) {
      return null;
    }

    if (!await confirm(precheck, driveBackupName: driveBackupName)) {
      return null;
    }

    if (!context.mounted) {
      return null;
    }

    String? backupRecoveryKey;
    if (precheck.expectsRecoveryKeyAfterRestore) {
      backupRecoveryKey = await collectValidatedRecoveryKey(
        context,
        backupFile,
        precheck,
      );
      if (!context.mounted || backupRecoveryKey == null) {
        return null;
      }
    }

    return RestorePreparedContext(
      precheck: precheck,
      backupRecoveryKey: backupRecoveryKey,
    );
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
