import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/features/settings/settings_copy.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';

void main() {
  test('recoveryKeyHintLine 使用統一末四碼格式', () {
    expect(SettingsCopy.recoveryKeyHintLine('WXYZ'), '末四碼：WXYZ');
  });

  group('buildRestoreConfirmBulletPoints', () {
    final RecoveryMetadata backupMetadata = RecoveryMetadata(
      vaultId: 'vlt_backup',
      recoveryEnabled: true,
      recoveryKeyVersion: 1,
      recoveryKeyHint: 'WXYZ',
      createdAt: DateTime.parse('2026-05-19T00:00:00Z'),
      kdf: KdfDescriptor.argon2idRecovery(
        saltBytes: List<int>.filled(16, 1),
      ),
    );

    test('無 recovery 時提示重新建立', () {
      const RestorePrecheck precheck = RestorePrecheck(
        preview: BackupRecoveryPreview(hasRecovery: false),
        localVaultId: 'vlt_local',
        localHasTrustedDevice: true,
        willOverwriteLocalVault: true,
      );

      final List<String> bullets = buildRestoreConfirmBulletPoints(precheck);
      expect(bullets, contains(SettingsRestoreBulletCopy.backupWithoutRecovery));
      expect(bullets, isNot(contains(SettingsRestoreBulletCopy.rewrapNote)));
    });

    test('同 vault 且有 trusted 時提示自動解鎖', () {
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
      expect(bullets, contains(SettingsRestoreBulletCopy.trustedAutoUnlock));
      expect(bullets, contains(SettingsRestoreBulletCopy.rewrapNote));
    });

    test('同 vault 但復原金鑰已輪替時提示舊金鑰與末四碼', () {
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
      expect(bullets, contains(SettingsRestoreBulletCopy.rotatedBackup));
      expect(bullets, contains(SettingsCopy.recoveryKeyHintLine('WXYZ')));
    });

    test('不同 vault 時提示備份來源復原金鑰', () {
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
      expect(bullets, contains(SettingsRestoreBulletCopy.recoveryKeyAfterRestore));
      expect(bullets, contains(SettingsCopy.recoveryKeyHintLine('WXYZ')));
    });

    test('同 vault 且 trusted state 遺失時仍提示舊復原金鑰', () {
      final RestorePrecheck precheck = RestorePrecheck(
        preview: BackupRecoveryPreview(
          hasRecovery: true,
          metadata: backupMetadata,
        ),
        localVaultId: 'vlt_backup',
        localRecoverySaltBase64: base64Encode(List<int>.filled(16, 9)),
        localHasTrustedDevice: false,
        willOverwriteLocalVault: true,
      );

      final List<String> bullets = buildRestoreConfirmBulletPoints(precheck);
      expect(precheck.recoveryKeyRotatedSinceBackup, isTrue);
      expect(precheck.expectsTrustedUnlockAfterRestore, isFalse);
      expect(precheck.expectsRecoveryKeyAfterRestore, isTrue);
      expect(bullets, contains(SettingsRestoreBulletCopy.rotatedBackup));
      expect(bullets, contains(SettingsCopy.recoveryKeyHintLine('WXYZ')));
    });
  });

  test('restoreRecoveryKeyDialogSubtitle 不同 vault 時', () {
    const RestorePrecheck precheck = RestorePrecheck(
      preview: BackupRecoveryPreview(hasRecovery: true),
      localVaultId: 'vlt_local',
      localHasTrustedDevice: true,
      willOverwriteLocalVault: true,
    );
    expect(
      restoreRecoveryKeyDialogSubtitle(precheck),
      SettingsRestoreDialogCopy.subtitleOtherVault,
    );
  });
}
