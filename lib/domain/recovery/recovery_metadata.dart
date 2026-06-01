import 'kdf_descriptor.dart';
import '../shared/value_objects.dart';

class RecoveryMetadata {
  const RecoveryMetadata({
    required this.vaultId,
    required this.recoveryEnabled,
    required this.recoveryKeyVersion,
    required this.recoveryKeyHint,
    required this.createdAt,
    required this.kdf,
  }) : assert(
          recoveryKeyVersion >= 1,
          'recovery_key_version must be >= 1.',
        );

  static const int kSchemaVersion = 1;

  final VaultId vaultId;
  final bool recoveryEnabled;
  final int recoveryKeyVersion;
  final String recoveryKeyHint;
  final DateTime createdAt;
  final KdfDescriptor kdf;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schema_version': kSchemaVersion,
      'vault_id': vaultId,
      'recovery_enabled': recoveryEnabled,
      'recovery_key_version': recoveryKeyVersion,
      'recovery_key_hint': recoveryKeyHint,
      'created_at': createdAt.toIso8601String(),
      'kdf': <String, Object?>{
        ...kdf.toJson(),
        'purpose': 'recovery_wrapping',
      },
    };
  }

  factory RecoveryMetadata.fromJson(Map<String, Object?> json) {
    final Map<String, Object?>? kdfMap =
        json['kdf'] is Map<String, Object?> ? json['kdf'] as Map<String, Object?> : null;
    if (kdfMap == null) {
      throw const FormatException('Recovery metadata missing kdf.');
    }
    final int schemaVersion =
        int.tryParse('${json['schema_version'] ?? kSchemaVersion}') ?? kSchemaVersion;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException('不支援的 recovery metadata 版本：$schemaVersion。');
    }
    final int version = int.tryParse('${json['recovery_key_version'] ?? 0}') ?? 0;
    if (version < 1) {
      throw FormatException('不支援的復原金鑰版本：$version。');
    }
    return RecoveryMetadata(
      vaultId: (json['vault_id'] ?? 'vlt_UNKNOWN').toString(),
      recoveryEnabled: json['recovery_enabled'] == true,
      recoveryKeyVersion: version,
      recoveryKeyHint: (json['recovery_key_hint'] ?? '').toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      kdf: KdfDescriptor.fromRecoveryMetadataKdf(kdfMap),
    );
  }
}
