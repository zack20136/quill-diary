import 'dart:io';

import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';

import 'fake_vault_transfer_service.dart';

/// 記錄還原流程呼叫的 VaultTransferService 測試替身。
class RecordingVaultTransferService extends FakeVaultTransferService {
  RestorePrecheck? nextPrecheck;
  int precheckCalls = 0;
  int restoreCalls = 0;
  bool? lastPreserveTrusted;
  int verifyCalls = 0;
  final List<String> verifyKeys = <String>[];
  StateError? verifyError;

  @override
  Future<RestorePrecheck> precheckRestore(File backupFile) async {
    precheckCalls++;
    if (nextPrecheck == null) {
      throw StateError('nextPrecheck 未設定');
    }
    return nextPrecheck!;
  }

  @override
  Future<void> verifyBackupRecoveryKey(File backupFile, String recoveryKey) async {
    verifyCalls++;
    verifyKeys.add(recoveryKey);
    if (verifyError != null) {
      throw verifyError!;
    }
  }

  @override
  Future<void> restoreFromBackupFile(
    File backupFile, {
    bool preserveTrustedDeviceAccess = false,
  }) async {
    restoreCalls++;
    lastPreserveTrusted = preserveTrustedDeviceAccess;
  }
}
