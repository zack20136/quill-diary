import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/shared/data_versions.dart';

/// 儲存於 `vault/recovery.json` 的明文復原描述子。
///
/// 刻意不含日記內容與未包裝的加密金鑰；
/// 僅描述使用者輸入的 Recovery Key 如何衍生包裝材料。
class RecoveryMetadata {
  const RecoveryMetadata({
    required this.vaultId,
    required this.recoveryEnabled,
    required this.recoveryKeyVersion,
    required this.recoveryKeyHint,
    required this.createdAt,
    required this.kdf,
  }) : assert(
         recoveryKeyVersion >= initialKeyVersion,
         'recovery_key_version must be >= 1.',
       );

  static const int initialKeyVersion = 1;

  final VaultId vaultId;
  final bool recoveryEnabled;

  /// 歷史保留欄位，沿用既有值；不能用來判斷是否已備份目前金鑰。
  final int recoveryKeyVersion;
  final String recoveryKeyHint;
  final DateTime createdAt;
  final KdfDescriptor kdf;

  bool hasSameRecoveryGenerationAs(RecoveryMetadata other) =>
      vaultId == other.vaultId && kdf.hasSameParametersAs(other.kdf);

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schema_version': DataVersions.recoveryMetadata,
      'vault_id': vaultId,
      'recovery_enabled': recoveryEnabled,
      'recovery_key_version': recoveryKeyVersion,
      'recovery_key_hint': recoveryKeyHint,
      'created_at': createdAt.toIso8601String(),
      'kdf': <String, Object?>{...kdf.toJson(), 'purpose': 'recovery_wrapping'},
    };
  }

  factory RecoveryMetadata.fromJson(Map<String, Object?> json) {
    final Map<String, Object?>? kdfMap = json['kdf'] is Map<String, Object?>
        ? json['kdf'] as Map<String, Object?>
        : null;
    if (kdfMap == null) {
      throw const FormatException('Recovery metadata missing kdf.');
    }
    final rawSchemaVersion = json.containsKey('schema_version')
        ? json['schema_version']
        : DataVersions.recoveryMetadata;
    final int? schemaVersion = int.tryParse('$rawSchemaVersion');
    if (schemaVersion != DataVersions.recoveryMetadata) {
      throw FormatException('不支援的 recovery metadata 版本：$schemaVersion。');
    }
    final int version =
        int.tryParse('${json['recovery_key_version'] ?? 0}') ?? 0;
    if (version < initialKeyVersion) {
      throw FormatException('不支援的復原金鑰版本：$version。');
    }
    return RecoveryMetadata(
      vaultId: (json['vault_id'] ?? 'vlt_UNKNOWN').toString(),
      recoveryEnabled: json['recovery_enabled'] == true,
      recoveryKeyVersion: version,
      recoveryKeyHint: (json['recovery_key_hint'] ?? '').toString(),
      createdAt:
          DateTime.tryParse('${json['created_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      kdf: KdfDescriptor.fromJson(kdfMap),
    );
  }
}
