import 'dart:convert';

import 'package:quill_diary/domain/recovery/recovery_key_identity.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';

class RecoveryRotationRecord {
  const RecoveryRotationRecord({
    required this.oldMetadata,
    required this.newMetadata,
    required this.newRecoveryKey,
    this.previousBackupRequirement,
    this.hasBackupRequirementSnapshot = false,
  });

  final RecoveryMetadata oldMetadata;
  final RecoveryMetadata newMetadata;
  final String newRecoveryKey;
  final RecoveryKeyIdentity? previousBackupRequirement;

  /// 歷史續跑檔未記錄提醒快照；須與明確沒有提醒的 null 分開。
  final bool hasBackupRequirementSnapshot;

  static const String documentId = 'recovery_rotation_pending';
  static const String contentType =
      'application/vnd.quill-diary.recovery-rotation';
  static const String _backupRequirementKey = 'previous_backup_requirement';

  List<int> encode() => utf8.encode(jsonEncode(_toJson()));

  Map<String, Object?> _toJson() => <String, Object?>{
    'old_metadata': oldMetadata.toJson(),
    'new_metadata': newMetadata.toJson(),
    'new_recovery_key': newRecoveryKey,
    if (hasBackupRequirementSnapshot)
      _backupRequirementKey: previousBackupRequirement?.toJson(),
  };

  factory RecoveryRotationRecord.decode(List<int> bytes) {
    final Object? decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('復原金鑰輪替續跑資料格式不正確。');
    }
    final Object? old = decoded['old_metadata'];
    final Object? next = decoded['new_metadata'];
    final Object? newKey = decoded['new_recovery_key'];
    final Object? requirement = decoded[_backupRequirementKey];
    final RecoveryKeyIdentity? identity = requirement is Map
        ? RecoveryKeyIdentity.fromJson(requirement)
        : null;
    if (old is! Map<String, Object?> ||
        next is! Map<String, Object?> ||
        newKey is! String ||
        newKey.trim().isEmpty ||
        (requirement != null && identity == null)) {
      throw const FormatException('復原金鑰輪替續跑資料格式不正確。');
    }
    return RecoveryRotationRecord(
      oldMetadata: RecoveryMetadata.fromJson(old),
      newMetadata: RecoveryMetadata.fromJson(next),
      newRecoveryKey: newKey,
      hasBackupRequirementSnapshot: decoded.containsKey(_backupRequirementKey),
      previousBackupRequirement: identity,
    );
  }
}
