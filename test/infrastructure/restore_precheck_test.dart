import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_lock_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_lock_diary/infrastructure/storage/restore_precheck.dart';

void main() {
  final RecoveryMetadata backupMetadata = RecoveryMetadata(
    vaultId: 'vlt_backup',
    recoveryEnabled: true,
    recoveryKeyVersion: 2,
    recoveryKeyHint: 'WXYZ',
    createdAt: DateTime.parse('2026-05-19T00:00:00Z'),
    kdf: KdfDescriptor.argon2idRecovery(
      saltBytes: List<int>.filled(16, 1),
    ),
  );

  test('buildRestoreConfirmBulletPoints 無 recovery 時提示重新建立', () {
    const RestorePrecheck precheck = RestorePrecheck(
      preview: BackupRecoveryPreview(hasRecovery: false),
      localVaultId: 'vlt_local',
      localHasTrustedDevice: true,
      willOverwriteLocalVault: true,
    );

    final List<String> bullets = buildRestoreConfirmBulletPoints(precheck);
    expect(bullets.any((String line) => line.contains('尚未建立復原金鑰')), isTrue);
  });

  test('buildRestoreConfirmBulletPoints 同 vault 且有 trusted 時提示自動解鎖', () {
    final RestorePrecheck precheck = RestorePrecheck(
      preview: BackupRecoveryPreview(
        hasRecovery: true,
        metadata: backupMetadata,
      ),
      localVaultId: 'vlt_backup',
      localRecoverySaltBase64: backupMetadata.kdf.saltBase64,
      localHasTrustedDevice: true,
      willOverwriteLocalVault: true,
    );

    final List<String> bullets = buildRestoreConfirmBulletPoints(precheck);
    expect(precheck.expectsTrustedUnlockAfterRestore, isTrue);
    expect(bullets.any((String line) => line.contains('受信任裝置')), isTrue);
  });

  test('buildRestoreConfirmBulletPoints 同 vault 但復原金鑰已輪替時提示舊金鑰', () {
    final RestorePrecheck precheck = RestorePrecheck(
      preview: BackupRecoveryPreview(
        hasRecovery: true,
        metadata: backupMetadata,
      ),
      localVaultId: 'vlt_backup',
      localRecoverySaltBase64: base64Encode(List<int>.filled(16, 9)),
      localHasTrustedDevice: true,
      willOverwriteLocalVault: true,
    );

    final List<String> bullets = buildRestoreConfirmBulletPoints(precheck);
    expect(precheck.recoveryKeyRotatedSinceBackup, isTrue);
    expect(precheck.expectsTrustedUnlockAfterRestore, isFalse);
    expect(bullets.any((String line) => line.contains('更新復原金鑰')), isTrue);
  });

  test('buildRestoreConfirmBulletPoints 不同 vault 時提示備份來源復原金鑰', () {
    final RestorePrecheck precheck = RestorePrecheck(
      preview: BackupRecoveryPreview(
        hasRecovery: true,
        metadata: backupMetadata,
      ),
      localVaultId: 'vlt_other',
      localRecoverySaltBase64: backupMetadata.kdf.saltBase64,
      localHasTrustedDevice: true,
      willOverwriteLocalVault: true,
    );

    final List<String> bullets = buildRestoreConfirmBulletPoints(precheck);
    expect(precheck.expectsRecoveryKeyAfterRestore, isTrue);
    expect(bullets.any((String line) => line.contains('建立此備份時保存')), isTrue);
    expect(bullets.any((String line) => line.contains('WXYZ')), isTrue);
  });
}
