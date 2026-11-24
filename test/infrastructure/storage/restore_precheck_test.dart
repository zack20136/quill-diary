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
    kdf: KdfDescriptor.argon2idRecovery(saltBytes: List<int>.filled(16, 252)),
  );
  final Map<String, Object?> metadataJson = backupMetadata.toJson();
  final Map<String, Object?> kdfJson = backupMetadata.kdf.toJson();
  final prior = UnlockedVaultSession(
    vaultId: backupMetadata.vaultId,
    trustedDevice: true,
    recoveryWrapKey: List<int>.filled(32, 1),
  );

  RestorePrecheck precheck({
    required RecoveryMetadata? localMetadata,
    bool trusted = true,
  }) => RestorePrecheck(
    preview: BackupRecoveryPreview(metadata: backupMetadata),
    localMetadata: localMetadata,
    localHasTrustedDevice: trusted,
    willOverwriteLocalVault: localMetadata != null,
  );

  test('完整復原參數相同且有裝置信任時可接續原會話', () {
    final local = RecoveryMetadata.fromJson({
      ...metadataJson,
      'kdf': {
        ...kdfJson,
        'salt': base64UrlEncode(backupMetadata.kdf.validate()),
      },
    });
    final check = precheck(localMetadata: local);
    expect(check.canResumeTrustedSession(prior), isTrue);
    expect(check.canResumeTrustedSession(null), isFalse);
    expect(
      check.canResumeTrustedSession(prior.copyWith(vaultId: 'vlt_other')),
      isFalse,
    );
    expect(
      check.canResumeTrustedSession(
        UnlockedVaultSession(
          vaultId: backupMetadata.vaultId,
          trustedDevice: true,
        ),
      ),
      isFalse,
    );
  });

  test('同一日記庫的 Salt 或迭代次數不同時要求備份金鑰', () {
    for (final change in [
      {'salt': base64Encode(List<int>.filled(16, 9))},
      {'iterations': 2},
    ]) {
      final check = precheck(
        localMetadata: RecoveryMetadata.fromJson({
          ...metadataJson,
          'kdf': {...kdfJson, ...change},
        }),
      );

      expect(check.recoveryKeyRotatedSinceBackup, isTrue);
      expect(check.canResumeTrustedSession(prior), isFalse);
    }
  });

  test('其他日記庫、首次還原或無裝置信任都要求備份金鑰', () {
    for (final check in [
      precheck(
        localMetadata: RecoveryMetadata.fromJson({
          ...metadataJson,
          'vault_id': 'vlt_other',
        }),
      ),
      precheck(localMetadata: null),
      precheck(localMetadata: backupMetadata, trusted: false),
    ]) {
      expect(check.recoveryKeyRotatedSinceBackup, isFalse);
      expect(check.canResumeTrustedSession(prior), isFalse);
    }
  });
}
