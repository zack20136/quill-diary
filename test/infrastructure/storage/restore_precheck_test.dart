import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';

void main() {
  final RecoveryMetadata backupMetadata = RecoveryMetadata(
    vaultId: 'vlt_backup',
    recoveryEnabled: true,
    recoveryKeyVersion: 1,
    recoveryKeyHint: 'WXYZ',
    createdAt: DateTime.parse('2026-05-19T00:00:00Z'),
    kdf: KdfDescriptor.argon2idRecovery(saltBytes: List<int>.filled(16, 1)),
  );

  RestorePrecheck buildPrecheck({
    RecoveryMetadata? metadata,
    String? localVaultId = 'vlt_backup',
    String? localRecoverySaltBase64,
    bool localHasTrustedDevice = true,
  }) {
    return RestorePrecheck(
      preview: BackupRecoveryPreview(metadata: metadata ?? backupMetadata),
      localVaultId: localVaultId,
      localRecoverySaltBase64:
          localRecoverySaltBase64 ?? backupMetadata.kdf.saltBase64,
      localHasTrustedDevice: localHasTrustedDevice,
      willOverwriteLocalVault: true,
    );
  }

  test('備份 vault 欄位取自 metadata', () {
    final RestorePrecheck precheck = buildPrecheck();
    expect(precheck.backupVaultId, 'vlt_backup');
    expect(precheck.backupRecoveryHint, 'WXYZ');
    expect(precheck.backupRecoverySaltBase64, backupMetadata.kdf.saltBase64);
  });

  test('sameVaultId 需兩側 vaultId 皆存在且相等', () {
    expect(buildPrecheck(localVaultId: 'vlt_backup').sameVaultId, isTrue);
    expect(buildPrecheck(localVaultId: 'vlt_other').sameVaultId, isFalse);
    expect(buildPrecheck(localVaultId: null).sameVaultId, isFalse);
  });

  test('sameRecoveryGeneration 會比對備份與本機 salt', () {
    expect(buildPrecheck().sameRecoveryGeneration, isTrue);
    expect(
      buildPrecheck(
        localRecoverySaltBase64: base64Encode(List<int>.filled(16, 9)),
      ).sameRecoveryGeneration,
      isFalse,
    );
    final RestorePrecheck withoutLocalSalt = RestorePrecheck(
      preview: BackupRecoveryPreview(metadata: backupMetadata),
      localVaultId: 'vlt_backup',
      localRecoverySaltBase64: null,
      localHasTrustedDevice: true,
      willOverwriteLocalVault: true,
    );
    expect(withoutLocalSalt.sameRecoveryGeneration, isFalse);
  });

  test('recoveryKeyRotatedSinceBackup 僅在同 vault 且 salt 不同時為 true', () {
    expect(
      buildPrecheck(
        localRecoverySaltBase64: base64Encode(List<int>.filled(16, 9)),
      ).recoveryKeyRotatedSinceBackup,
      isTrue,
    );
    expect(buildPrecheck().recoveryKeyRotatedSinceBackup, isFalse);
    expect(
      buildPrecheck(
        localVaultId: 'vlt_other',
        localRecoverySaltBase64: base64Encode(List<int>.filled(16, 9)),
      ).recoveryKeyRotatedSinceBackup,
      isFalse,
    );
  });

  test('expectsTrustedUnlockAfterRestore 需同 vault、trusted 且同代金鑰', () {
    expect(buildPrecheck().expectsTrustedUnlockAfterRestore, isTrue);
    expect(
      buildPrecheck(
        localHasTrustedDevice: false,
      ).expectsTrustedUnlockAfterRestore,
      isFalse,
    );
    expect(
      buildPrecheck(
        localRecoverySaltBase64: base64Encode(List<int>.filled(16, 9)),
      ).expectsTrustedUnlockAfterRestore,
      isFalse,
    );
    expect(
      buildPrecheck(localVaultId: 'vlt_other').expectsTrustedUnlockAfterRestore,
      isFalse,
    );
  });

  test('canResumeTrustedSession 需 expectsTrustedUnlock 且前一個 session 有效', () {
    final UnlockedVaultSession priorSession = UnlockedVaultSession(
      vaultId: backupMetadata.vaultId,
      trustedDevice: true,
      recoveryWrapKey: List<int>.filled(32, 1),
    );
    expect(buildPrecheck().canResumeTrustedSession(priorSession), isTrue);
    expect(
      buildPrecheck(
        localHasTrustedDevice: false,
      ).canResumeTrustedSession(priorSession),
      isFalse,
    );
    expect(buildPrecheck().canResumeTrustedSession(null), isFalse);
    expect(
      buildPrecheck().canResumeTrustedSession(
        UnlockedVaultSession(
          vaultId: backupMetadata.vaultId,
          trustedDevice: true,
        ),
      ),
      isFalse,
    );
    expect(
      buildPrecheck().canResumeTrustedSession(
        priorSession.copyWith(vaultId: 'vlt_other'),
      ),
      isFalse,
    );
  });

  test('expectsRecoveryKeyAfterRestore 在需手動輸入金鑰時為 true', () {
    expect(
      buildPrecheck(localVaultId: 'vlt_other').expectsRecoveryKeyAfterRestore,
      isTrue,
    );
    expect(
      buildPrecheck(
        localRecoverySaltBase64: base64Encode(List<int>.filled(16, 9)),
      ).expectsRecoveryKeyAfterRestore,
      isTrue,
    );
    expect(buildPrecheck().expectsRecoveryKeyAfterRestore, isFalse);
  });

  test('trusted 遺失且金鑰已輪替時仍需輸入舊金鑰', () {
    final RestorePrecheck precheck = buildPrecheck(
      localRecoverySaltBase64: base64Encode(List<int>.filled(16, 9)),
      localHasTrustedDevice: false,
    );

    expect(precheck.recoveryKeyRotatedSinceBackup, isTrue);
    expect(precheck.expectsTrustedUnlockAfterRestore, isFalse);
    expect(precheck.expectsRecoveryKeyAfterRestore, isTrue);
  });
}
