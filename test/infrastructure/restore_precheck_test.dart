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
    bool includeMetadata = true,
    String? localVaultId = 'vlt_backup',
    String? localRecoverySaltBase64,
    bool localHasTrustedDevice = true,
  }) {
    return RestorePrecheck(
      preview: BackupRecoveryPreview(
        metadata: includeMetadata ? (metadata ?? backupMetadata) : null,
      ),
      localVaultId: localVaultId,
      localRecoverySaltBase64:
          localRecoverySaltBase64 ?? backupMetadata.kdf.saltBase64,
      localHasTrustedDevice: localHasTrustedDevice,
      willOverwriteLocalVault: true,
    );
  }

  test('metadata 為 null 時 backupHasRecovery 為 false 且 vault 欄位為空', () {
    const RestorePrecheck withoutMetadata = RestorePrecheck(
      preview: BackupRecoveryPreview(),
      localVaultId: 'vlt_local',
      localHasTrustedDevice: false,
      willOverwriteLocalVault: true,
    );
    expect(withoutMetadata.backupHasRecovery, isFalse);
    expect(withoutMetadata.backupVaultId, isNull);
    expect(withoutMetadata.backupRecoveryHint, isNull);
    expect(withoutMetadata.backupRecoverySaltBase64, isNull);

    final RestorePrecheck withMetadata = buildPrecheck();
    expect(withMetadata.backupHasRecovery, isTrue);
    expect(withMetadata.backupVaultId, 'vlt_backup');
    expect(withMetadata.backupRecoveryHint, 'WXYZ');
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
    expect(
      buildPrecheck(includeMetadata: false).recoveryKeyRotatedSinceBackup,
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
    expect(
      buildPrecheck(includeMetadata: false).expectsTrustedUnlockAfterRestore,
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
    expect(
      buildPrecheck(includeMetadata: false).expectsRecoveryKeyAfterRestore,
      isFalse,
    );
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

  test('backupRecoverySaltBase64 會取自 metadata kdf', () {
    expect(
      buildPrecheck().backupRecoverySaltBase64,
      backupMetadata.kdf.saltBase64,
    );
    expect(
      buildPrecheck(includeMetadata: false).backupRecoverySaltBase64,
      isNull,
    );
  });
}
