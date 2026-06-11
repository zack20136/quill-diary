import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/security/unlocked_vault_session.dart';
import '../../infrastructure/storage/restore_precheck.dart';
import '../../shared/providers/core_providers.dart';
import '../session/providers/session_providers.dart';
import '../session/state/app_session_state.dart';
import '../settings/vault_transfer_access.dart';
import 'widgets/restore_recovery_key_dialog.dart';

/// 還原備份：確認 → 驗證金鑰 → 寫入（結構驗證由呼叫端 precheck 負責）。
class RestoreBackupFlow {
  RestoreBackupFlow(this.ref);

  final WidgetRef ref;

  Future<VaultTransferAccess> _loadTransferAccess() async {
    final AppSessionState sessionState = ref.read(appSessionProvider);
    final bool hasUnlockedSession =
        sessionState.isUnlocked && sessionState.session != null;
    final bool hasRecoveryKey =
        await ref.read(vaultRepositoryProvider).readRecoveryMetadata() != null;
    return VaultTransferAccess.fromContext(
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
        await transferService.verifyBackupRecoveryKey(
          backupFile,
          key,
        );
        return key;
      } on StateError catch (error) {
        validationError = error.message;
      }
    }
  }

  Future<void> run({
    required BuildContext context,
    required File backupFile,
    required RestorePrecheck precheck,
    required Future<bool> Function(RestorePrecheck precheck, {String? driveBackupName})
        confirm,
    required Future<void> Function({
      String? backupRecoveryKey,
      required RestorePrecheck precheck,
      UnlockedVaultSession? priorSession,
    }) onComplete,
    String? driveBackupName,
  }) async {
    final transferService = ref.read(vaultTransferServiceProvider);
    final VaultTransferAccess access = await _loadTransferAccess();
    access.ensureCanRestore();

    if (!context.mounted) {
      return;
    }

    if (!await confirm(precheck, driveBackupName: driveBackupName)) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    String? backupRecoveryKey;
    if (precheck.expectsRecoveryKeyAfterRestore) {
      backupRecoveryKey = await collectValidatedRecoveryKey(
        context,
        backupFile,
        precheck,
      );
      if (!context.mounted || backupRecoveryKey == null) {
        return;
      }
    }

    final AppSessionController sessionController =
        ref.read(appSessionProvider.notifier);
    final UnlockedVaultSession? priorSession =
        ref.read(appSessionProvider).session;
    final bool hasActiveSession =
        priorSession != null && ref.read(appSessionProvider).isUnlocked;

    Future<void> restoreBackup() async {
      await transferService.restoreFromBackupFile(
        backupFile,
        preserveTrustedDeviceAccess: precheck.expectsTrustedUnlockAfterRestore,
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

    await onComplete(
      backupRecoveryKey: backupRecoveryKey,
      precheck: precheck,
      priorSession: priorSession,
    );
  }
}
