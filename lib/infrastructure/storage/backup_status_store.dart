import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:quill_diary/domain/recovery/recovery_key_identity.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/shared/app_identifiers.dart';

/// 備份健康度門檻（本機與 Drive 各自比對最後成功時間）。
abstract final class BackupStatusPolicy {
  static const Duration staleThreshold = Duration(days: 30);
}

enum BackupStatusAction {
  localBackup,
  externalExport,
  driveUpload;

  String get storageValue => name;

  static BackupStatusAction? fromStorage(String? raw) {
    return switch (raw?.trim()) {
      'localBackup' => BackupStatusAction.localBackup,
      'externalExport' => BackupStatusAction.externalExport,
      'driveUpload' => BackupStatusAction.driveUpload,
      _ => null,
    };
  }
}

final class BackupFailureRecord {
  const BackupFailureRecord({
    required this.action,
    required this.message,
    required this.occurredAt,
  });

  final BackupStatusAction action;
  final String message;
  final DateTime occurredAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'action': action.storageValue,
      'message': message,
      'occurred_at': occurredAt.toIso8601String(),
    };
  }

  factory BackupFailureRecord.fromJson(Map<String, Object?> json) {
    return BackupFailureRecord(
      action:
          BackupStatusAction.fromStorage(json['action']?.toString()) ??
          BackupStatusAction.localBackup,
      message: (json['message'] ?? '').toString(),
      occurredAt:
          DateTime.tryParse((json['occurred_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

final class BackupStatusSnapshot {
  const BackupStatusSnapshot({
    this.lastLocalBackupAt,
    this.lastExternalExportAt,
    this.lastDriveUploadAt,
    this.lastDriveAccountLabel,
    this.lastDriveUploadJobId,
    this.lastFailure,
    this.requiredBackupIdentity,
    this.pendingRecoveryRotation,
    this.lastSuccessfulIdentity,
  });

  final DateTime? lastLocalBackupAt;
  final DateTime? lastExternalExportAt;
  final DateTime? lastDriveUploadAt;
  final String? lastDriveAccountLabel;
  final String? lastDriveUploadJobId;
  final BackupFailureRecord? lastFailure;
  final RecoveryKeyIdentity? requiredBackupIdentity;
  final RecoveryBackupRotation? pendingRecoveryRotation;
  final RecoveryKeyIdentity? lastSuccessfulIdentity;

  bool get hasAnySuccess =>
      lastLocalBackupAt != null ||
      lastExternalExportAt != null ||
      lastDriveUploadAt != null;

  /// 本機建立與匯出到資料夾中較新的一筆成功時間。
  DateTime? get lastLocalRelatedBackupAt {
    final DateTime? local = lastLocalBackupAt;
    final DateTime? external = lastExternalExportAt;
    if (local == null) {
      return external;
    }
    if (external == null) {
      return local;
    }
    return local.isAfter(external) ? local : external;
  }

  /// 與 [lastLocalRelatedBackupAt] 對應的備份方式。
  BackupStatusAction? get lastLocalRelatedBackupAction {
    final DateTime? local = lastLocalBackupAt;
    final DateTime? external = lastExternalExportAt;
    if (local == null && external == null) {
      return null;
    }
    if (local == null) {
      return BackupStatusAction.externalExport;
    }
    if (external == null) {
      return BackupStatusAction.localBackup;
    }
    return local.isAfter(external)
        ? BackupStatusAction.localBackup
        : BackupStatusAction.externalExport;
  }

  bool isLocalBackupStale(DateTime now) =>
      _isStale(lastLocalRelatedBackupAt, now);

  bool isDriveUploadStale(DateTime now) => _isStale(lastDriveUploadAt, now);

  bool _isStale(DateTime? lastSuccess, DateTime now) {
    if (lastSuccess == null) {
      return false;
    }
    return now.difference(lastSuccess) > BackupStatusPolicy.staleThreshold;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (lastLocalBackupAt != null)
        'last_local_backup_at': lastLocalBackupAt!.toIso8601String(),
      if (lastExternalExportAt != null)
        'last_external_export_at': lastExternalExportAt!.toIso8601String(),
      if (lastDriveUploadAt != null)
        'last_drive_upload_at': lastDriveUploadAt!.toIso8601String(),
      if (lastDriveAccountLabel != null)
        'last_drive_account_label': lastDriveAccountLabel,
      if (lastDriveUploadJobId != null)
        'last_drive_upload_job_id': lastDriveUploadJobId,
      if (lastFailure != null) 'last_failure': lastFailure!.toJson(),
      'recovery_backup': {
        'required_identity': requiredBackupIdentity?.toJson(),
        'pending_rotation': pendingRecoveryRotation?.toJson(),
        'last_successful_identity': lastSuccessfulIdentity?.toJson(),
      },
    };
  }

  factory BackupStatusSnapshot.fromJson(Map<String, Object?> json) {
    final requirement = json['recovery_backup'];
    if (requirement != null && requirement is! Map) {
      throw const FormatException('重新備份提醒損壞');
    }
    if (requirement is Map &&
        (!requirement.containsKey('required_identity') ||
            ['pending_rotation', 'last_successful_identity'].any(
              (key) => requirement[key] != null && requirement[key] is! Map,
            ))) {
      throw const FormatException('重新備份提醒損壞');
    }
    final identity = requirement is Map
        ? requirement['required_identity']
        : null;
    if (identity != null && identity is! Map) {
      throw const FormatException('重新備份提醒損壞');
    }
    return BackupStatusSnapshot(
      requiredBackupIdentity: identity is Map
          ? RecoveryKeyIdentity.fromJson(identity)
          : null,
      pendingRecoveryRotation:
          requirement is Map && requirement['pending_rotation'] is Map
          ? RecoveryBackupRotation.fromJson(
              requirement['pending_rotation'] as Map,
            )
          : null,
      lastSuccessfulIdentity:
          requirement is Map && requirement['last_successful_identity'] is Map
          ? RecoveryKeyIdentity.fromJson(
              requirement['last_successful_identity'] as Map,
            )
          : null,
      lastLocalBackupAt: _parseDateTime(json['last_local_backup_at']),
      lastExternalExportAt: _parseDateTime(json['last_external_export_at']),
      lastDriveUploadAt: _parseDateTime(json['last_drive_upload_at']),
      lastDriveAccountLabel: json['last_drive_account_label']?.toString(),
      lastDriveUploadJobId: json['last_drive_upload_job_id']?.toString(),
      lastFailure: json['last_failure'] is Map<String, Object?>
          ? BackupFailureRecord.fromJson(
              json['last_failure'] as Map<String, Object?>,
            )
          : null,
    );
  }

  static DateTime? _parseDateTime(Object? raw) {
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw.toString());
  }
}

/// 非敏感備份操作健康度 metadata。
class BackupStatusStore {
  BackupStatusStore({File? storageFile, this._pathStrategy})
    : _storageFileOverride = storageFile;

  final VaultPathStrategy? _pathStrategy;

  final File? _storageFileOverride;
  Future<void> _mutationQueue = Future<void>.value();

  Future<BackupStatusSnapshot> read() {
    return _enqueue(() async {
      return _readUnlocked();
    });
  }

  Future<void> recordLocalBackupSuccess({
    DateTime? at,
    RecoveryKeyIdentity? identity,
    VaultBackupPurpose? purpose,
  }) => _recordSuccess(
    BackupStatusAction.localBackup,
    at: at,
    identity: identity,
    purpose: purpose,
  );

  Future<void> recordExternalExportSuccess({
    DateTime? at,
    RecoveryKeyIdentity? identity,
    VaultBackupPurpose? purpose,
  }) => _recordSuccess(
    BackupStatusAction.externalExport,
    at: at,
    identity: identity,
    purpose: purpose,
  );

  Future<void> recordDriveUploadSuccess({
    RecoveryKeyIdentity? identity,
    VaultBackupPurpose? purpose,
    String? accountLabel,
    DateTime? at,
    String? jobId,
  }) => _recordSuccess(
    BackupStatusAction.driveUpload,
    at: at,
    identity: identity,
    purpose: purpose,
    accountLabel: accountLabel,
    jobId: jobId,
  );

  Future<void> _recordSuccess(
    BackupStatusAction action, {
    DateTime? at,
    RecoveryKeyIdentity? identity,
    VaultBackupPurpose? purpose,
    String? accountLabel,
    String? jobId,
  }) => _enqueue(() async {
    final current = await _readUnlocked();
    final isDrive = action == BackupStatusAction.driveUpload;
    final trimmedJobId = jobId?.trim();
    final sameJob =
        isDrive &&
        trimmedJobId != null &&
        trimmedJobId.isNotEmpty &&
        current.lastDriveUploadJobId == trimmedJobId;
    final isNormal = purpose == VaultBackupPurpose.normal && identity != null;
    final clearsRequirement =
        isNormal && identity == current.requiredBackupIdentity;
    if (sameJob && current.lastFailure == null && !clearsRequirement) return;
    final completedAt = at ?? DateTime.now();
    final trimmedAccount = accountLabel?.trim();
    await _persistUnlocked(
      BackupStatusSnapshot(
        pendingRecoveryRotation: current.pendingRecoveryRotation,
        lastSuccessfulIdentity: isNormal
            ? identity
            : current.lastSuccessfulIdentity,
        requiredBackupIdentity: clearsRequirement
            ? null
            : current.requiredBackupIdentity,
        lastLocalBackupAt: action == BackupStatusAction.localBackup
            ? completedAt
            : current.lastLocalBackupAt,
        lastExternalExportAt: action == BackupStatusAction.externalExport
            ? completedAt
            : current.lastExternalExportAt,
        lastDriveUploadAt: isDrive && !sameJob
            ? completedAt
            : current.lastDriveUploadAt,
        lastDriveAccountLabel:
            isDrive && trimmedAccount != null && trimmedAccount.isNotEmpty
            ? trimmedAccount
            : current.lastDriveAccountLabel,
        lastDriveUploadJobId:
            isDrive && trimmedJobId != null && trimmedJobId.isNotEmpty
            ? trimmedJobId
            : current.lastDriveUploadJobId,
        lastFailure: isDrive ? null : current.lastFailure,
      ),
    );
  });

  Future<void> recordFailure({
    required BackupStatusAction action,
    required String message,
    DateTime? at,
  }) {
    return _enqueue(() async {
      final BackupStatusSnapshot current = await _readUnlocked();
      await _persistUnlocked(
        BackupStatusSnapshot(
          pendingRecoveryRotation: current.pendingRecoveryRotation,
          lastSuccessfulIdentity: current.lastSuccessfulIdentity,
          requiredBackupIdentity: current.requiredBackupIdentity,
          lastLocalBackupAt: current.lastLocalBackupAt,
          lastExternalExportAt: current.lastExternalExportAt,
          lastDriveUploadAt: current.lastDriveUploadAt,
          lastDriveAccountLabel: current.lastDriveAccountLabel,
          lastDriveUploadJobId: current.lastDriveUploadJobId,
          lastFailure: BackupFailureRecord(
            action: action,
            message: message.trim(),
            occurredAt: at ?? DateTime.now(),
          ),
        ),
      );
    });
  }

  BackupStatusSnapshot _withRequirement(
    BackupStatusSnapshot current,
    RecoveryKeyIdentity? identity, {
    RecoveryBackupRotation? rotation,
  }) => BackupStatusSnapshot(
    requiredBackupIdentity: identity,
    pendingRecoveryRotation: rotation,
    lastSuccessfulIdentity: current.lastSuccessfulIdentity,
    lastLocalBackupAt: current.lastLocalBackupAt,
    lastExternalExportAt: current.lastExternalExportAt,
    lastDriveUploadAt: current.lastDriveUploadAt,
    lastDriveAccountLabel: current.lastDriveAccountLabel,
    lastDriveUploadJobId: current.lastDriveUploadJobId,
    lastFailure: current.lastFailure,
  );

  Future<void> setBackupRequirement(RecoveryKeyIdentity? identity) =>
      _enqueue(() async {
        final current = await _readUnlocked();
        await _persistUnlocked(
          _withRequirement(
            current,
            identity == current.lastSuccessfulIdentity ? null : identity,
          ),
        );
      });

  Future<RecoveryKeyIdentity?> beginRecoveryRotation(
    RecoveryKeyIdentity oldIdentity,
    RecoveryKeyIdentity newIdentity,
  ) => _enqueue(() async {
    final current = await _readUnlocked();
    if (current.pendingRecoveryRotation != null) {
      throw const FormatException('前次金鑰更新尚未恢復');
    }
    await _persistUnlocked(
      _withRequirement(
        current,
        current.requiredBackupIdentity,
        rotation: RecoveryBackupRotation(
          oldIdentity: oldIdentity,
          newIdentity: newIdentity,
          previousRequirement: current.requiredBackupIdentity,
        ),
      ),
    );
    return current.requiredBackupIdentity;
  });

  Future<void> reconcileRecoveryRotation(RecoveryKeyIdentity active) =>
      _enqueue(() async {
        final current = await _readUnlocked();
        final rotation = current.pendingRecoveryRotation;
        if (rotation == null) return;
        if (active != rotation.oldIdentity && active != rotation.newIdentity) {
          throw const FormatException('重新備份提醒與輪替資料不一致');
        }
        final requirement = active == rotation.newIdentity
            ? active
            : rotation.previousRequirement;
        await _persistUnlocked(
          _withRequirement(
            current,
            requirement == current.lastSuccessfulIdentity ? null : requirement,
          ),
        );
      });

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final Completer<T> completer = Completer<T>();
    _mutationQueue = _mutationQueue.catchError((Object _) {}).then((_) async {
      try {
        final T value = await action();
        completer.complete(value);
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<BackupStatusSnapshot> _readUnlocked() async {
    final file = await _storageFile();
    BackupStatusSnapshot parse(String raw) {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('備份狀態紀錄損壞');
      }
      return BackupStatusSnapshot.fromJson(decoded);
    }

    BackupStatusSnapshot? snapshot;
    await recoverFileReplacement(
      file,
      validate: (candidate) async {
        snapshot = parse(await candidate.readAsString());
      },
    );
    return snapshot ?? const BackupStatusSnapshot();
  }

  Future<void> _persistUnlocked(BackupStatusSnapshot snapshot) async {
    final File file = await _storageFile();
    await file.parent.create(recursive: true);
    await atomicWriteString(
      file,
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
    );
  }

  Future<File> _storageFile() async {
    final File? override = _storageFileOverride;
    if (override != null) {
      return override;
    }
    if (_pathStrategy != null) {
      return File(
        p.join(
          (await _pathStrategy.appRootDirectory()).path,
          'backup_status.json',
        ),
      );
    }
    final Directory supportDir = await getApplicationSupportDirectory();
    return File(
      p.join(
        supportDir.path,
        AppIdentifiers.appStorageDirectory,
        'backup_status.json',
      ),
    );
  }
}
