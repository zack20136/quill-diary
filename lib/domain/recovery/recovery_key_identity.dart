import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';

final class RecoveryKeyIdentity {
  const RecoveryKeyIdentity({
    required this.vaultId,
    required this.kdfFingerprint,
  });
  final String vaultId;
  final String kdfFingerprint;

  static Future<RecoveryKeyIdentity> fromMetadata(
    RecoveryMetadata metadata,
  ) async {
    final kdf = metadata.kdf;
    final canonical = jsonEncode([
      kdf.name,
      base64Encode(kdf.validate()),
      kdf.memory,
      kdf.parallelism,
      kdf.iterations,
      kdf.hashLength,
    ]);
    final hash = await Sha256().hash(utf8.encode(canonical));
    return RecoveryKeyIdentity(
      vaultId: metadata.vaultId,
      kdfFingerprint: hash.bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join(),
    );
  }

  Map<String, Object?> toJson() => {
    'vault_id': vaultId,
    'kdf_fingerprint': kdfFingerprint,
  };

  factory RecoveryKeyIdentity.fromJson(Map<Object?, Object?> json) {
    final vault = json['vault_id'];
    final fingerprint = json['kdf_fingerprint'];
    if (vault is! String ||
        vault.isEmpty ||
        fingerprint is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint)) {
      throw const FormatException('備份的金鑰世代資料不正確');
    }
    return RecoveryKeyIdentity(vaultId: vault, kdfFingerprint: fingerprint);
  }

  @override
  bool operator ==(Object other) =>
      other is RecoveryKeyIdentity &&
      vaultId == other.vaultId &&
      kdfFingerprint == other.kdfFingerprint;
  @override
  int get hashCode => Object.hash(vaultId, kdfFingerprint);
}

enum VaultBackupPurpose { normal, preservation }

final class RecoveryBackupRotation {
  const RecoveryBackupRotation({
    required this.oldIdentity,
    required this.newIdentity,
    this.previousRequirement,
  });
  final RecoveryKeyIdentity oldIdentity;
  final RecoveryKeyIdentity newIdentity;
  final RecoveryKeyIdentity? previousRequirement;
  Map<String, Object?> toJson() => {
    'old': oldIdentity.toJson(),
    'new': newIdentity.toJson(),
    'previous_requirement': previousRequirement?.toJson(),
  };
  factory RecoveryBackupRotation.fromJson(Map<Object?, Object?> json) {
    if (json['old'] is! Map ||
        json['new'] is! Map ||
        !json.containsKey('previous_requirement') ||
        json['previous_requirement'] != null &&
            json['previous_requirement'] is! Map) {
      throw const FormatException('金鑰輪替的備份提醒紀錄損壞');
    }
    return RecoveryBackupRotation(
      oldIdentity: RecoveryKeyIdentity.fromJson(json['old'] as Map),
      newIdentity: RecoveryKeyIdentity.fromJson(json['new'] as Map),
      previousRequirement: json['previous_requirement'] is Map
          ? RecoveryKeyIdentity.fromJson(json['previous_requirement'] as Map)
          : null,
    );
  }
}
