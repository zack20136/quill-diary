import '../shared/value_objects.dart';

class RecoveryMetadata {
  const RecoveryMetadata({
    required this.vaultId,
    required this.recoveryEnabled,
    required this.recoveryKeyVersion,
    required this.recoveryKeyHint,
    required this.createdAt,
    required this.kdfAlgorithm,
    required this.kdfSaltBase64,
  });

  final VaultId vaultId;
  final bool recoveryEnabled;
  final int recoveryKeyVersion;
  final String recoveryKeyHint;
  final DateTime createdAt;
  final String kdfAlgorithm;
  final String kdfSaltBase64;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schema_version': 1,
      'vault_id': vaultId,
      'recovery_enabled': recoveryEnabled,
      'recovery_key_version': recoveryKeyVersion,
      'recovery_key_hint': recoveryKeyHint,
      'created_at': createdAt.toIso8601String(),
      'kdf': <String, Object?>{
        'name': kdfAlgorithm,
        'salt': kdfSaltBase64,
        'purpose': 'recovery_wrapping',
      },
    };
  }

  factory RecoveryMetadata.fromJson(Map<String, Object?> json) {
    final Map<String, Object?>? kdf =
        json['kdf'] is Map<String, Object?> ? json['kdf'] as Map<String, Object?> : null;
    return RecoveryMetadata(
      vaultId: (json['vault_id'] ?? 'vlt_UNKNOWN').toString(),
      recoveryEnabled: json['recovery_enabled'] == true,
      recoveryKeyVersion: int.tryParse('${json['recovery_key_version'] ?? 1}') ?? 1,
      recoveryKeyHint: (json['recovery_key_hint'] ?? '').toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      kdfAlgorithm: (kdf?['name'] ?? 'pbkdf2-sha256').toString(),
      kdfSaltBase64: (kdf?['salt'] ?? '').toString(),
    );
  }
}
