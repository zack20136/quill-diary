import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/storage/restore_precheck.dart';
import '../../shared/providers/core_providers.dart';
import '../session/providers/session_providers.dart';
import 'widgets/restore_recovery_key_dialog.dart';

/// 還原備份：precheck → 確認 → 驗證金鑰 → 寫入。
class RestoreBackupFlow {
  RestoreBackupFlow(this.ref);

  final WidgetRef ref;

  Future<String?> collectValidatedRecoveryKey(
    BuildContext context,
    File backupFile,
    RestorePrecheck precheck,
  ) async {
    String? validationError;
    while (context.mounted) {
      final String? key = await showRestoreRecoveryKeyDialog(
        context,
        precheck: precheck,
        validationError: validationError,
      );
      if (key == null) {
        return null;
      }
      try {
        await ref.read(vaultTransferServiceProvider).verifyBackupRecoveryKey(
          backupFile,
          key,
        );
        return key;
      } on StateError catch (error) {
        validationError = error.message;
      }
    }
    return null;
  }

  Future<void> run({
    required BuildContext context,
    required File backupFile,
    required Future<bool> Function(RestorePrecheck precheck, {String? driveBackupName})
        confirm,
    required Future<void> Function({
      String? backupRecoveryKey,
      required RestorePrecheck precheck,
    }) onComplete,
    String? driveBackupName,
  }) async {
    final RestorePrecheck precheck =
        await ref.read(vaultTransferServiceProvider).precheckRestore(backupFile);

    if (!await confirm(precheck, driveBackupName: driveBackupName)) {
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

    await ref.read(appSessionProvider.notifier).runSensitiveTask((_) async {
      await ref.read(vaultTransferServiceProvider).restoreFromBackupFile(
        backupFile,
        preserveTrustedDeviceAccess: precheck.expectsTrustedUnlockAfterRestore,
      );
    });

    await onComplete(backupRecoveryKey: backupRecoveryKey, precheck: precheck);
  }
}
