import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:quill_diary/app/app_identifiers.dart';

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
  });

  final DateTime? lastLocalBackupAt;
  final DateTime? lastExternalExportAt;
  final DateTime? lastDriveUploadAt;
  final String? lastDriveAccountLabel;
  final String? lastDriveUploadJobId;
  final BackupFailureRecord? lastFailure;

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
    };
  }

  factory BackupStatusSnapshot.fromJson(Map<String, Object?> json) {
    return BackupStatusSnapshot(
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
  BackupStatusStore({File? storageFile}) : _storageFileOverride = storageFile;

  final File? _storageFileOverride;
  BackupStatusSnapshot? _cache;
  Future<void> _mutationQueue = Future<void>.value();

  Future<BackupStatusSnapshot> read() {
    return _enqueue(() async {
      return _readUnlocked();
    });
  }

  Future<void> recordLocalBackupSuccess({DateTime? at}) {
    return _enqueue(() async {
      final BackupStatusSnapshot current = await _readUnlocked();
      await _persistUnlocked(
        BackupStatusSnapshot(
          lastLocalBackupAt: at ?? DateTime.now(),
          lastExternalExportAt: current.lastExternalExportAt,
          lastDriveUploadAt: current.lastDriveUploadAt,
          lastDriveAccountLabel: current.lastDriveAccountLabel,
          lastDriveUploadJobId: current.lastDriveUploadJobId,
          lastFailure: current.lastFailure,
        ),
      );
    });
  }

  Future<void> recordExternalExportSuccess({DateTime? at}) {
    return _enqueue(() async {
      final BackupStatusSnapshot current = await _readUnlocked();
      await _persistUnlocked(
        BackupStatusSnapshot(
          lastLocalBackupAt: current.lastLocalBackupAt,
          lastExternalExportAt: at ?? DateTime.now(),
          lastDriveUploadAt: current.lastDriveUploadAt,
          lastDriveAccountLabel: current.lastDriveAccountLabel,
          lastDriveUploadJobId: current.lastDriveUploadJobId,
          lastFailure: current.lastFailure,
        ),
      );
    });
  }

  Future<void> recordDriveUploadSuccess({
    String? accountLabel,
    DateTime? at,
    String? jobId,
  }) {
    return _enqueue(() async {
      final BackupStatusSnapshot current = await _readUnlocked();
      final String? trimmedJobId = jobId?.trim();
      final bool sameJob =
          trimmedJobId != null &&
          trimmedJobId.isNotEmpty &&
          current.lastDriveUploadJobId == trimmedJobId;
      // 同 jobId 已記過：僅在仍有失敗紀錄時清掉後返回。
      if (sameJob && current.lastFailure == null) {
        return;
      }
      final String? trimmedAccount = accountLabel?.trim();
      await _persistUnlocked(
        BackupStatusSnapshot(
          lastLocalBackupAt: current.lastLocalBackupAt,
          lastExternalExportAt: current.lastExternalExportAt,
          lastDriveUploadAt: sameJob
              ? current.lastDriveUploadAt
              : (at ?? DateTime.now()),
          lastDriveAccountLabel:
              trimmedAccount != null && trimmedAccount.isNotEmpty
              ? trimmedAccount
              : current.lastDriveAccountLabel,
          lastDriveUploadJobId: trimmedJobId?.isNotEmpty == true
              ? trimmedJobId
              : current.lastDriveUploadJobId,
          lastFailure: null,
        ),
      );
    });
  }

  Future<void> recordFailure({
    required BackupStatusAction action,
    required String message,
    DateTime? at,
  }) {
    return _enqueue(() async {
      final BackupStatusSnapshot current = await _readUnlocked();
      await _persistUnlocked(
        BackupStatusSnapshot(
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

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final Completer<T> completer = Completer<T>();
    _mutationQueue = _mutationQueue
        .catchError((Object _) {})
        .then((_) async {
          try {
            final T value = await action();
            if (!completer.isCompleted) {
              completer.complete(value);
            }
          } catch (error, stack) {
            if (!completer.isCompleted) {
              completer.completeError(error, stack);
            }
          }
        });
    return completer.future;
  }

  Future<BackupStatusSnapshot> _readUnlocked() async {
    if (_cache != null) {
      return _cache!;
    }
    final File file = await _storageFile();
    if (!file.existsSync()) {
      _cache = const BackupStatusSnapshot();
      return _cache!;
    }
    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, Object?>) {
      _cache = BackupStatusSnapshot.fromJson(decoded);
    } else if (decoded is Map) {
      _cache = BackupStatusSnapshot.fromJson(
        Map<String, Object?>.from(decoded),
      );
    } else {
      _cache = const BackupStatusSnapshot();
    }
    return _cache!;
  }

  Future<void> _persistUnlocked(BackupStatusSnapshot snapshot) async {
    final File file = await _storageFile();
    await file.parent.create(recursive: true);
    final File temp = File('${file.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
      flush: true,
    );
    if (file.existsSync()) {
      await file.delete();
    }
    await temp.rename(file.path);
    _cache = snapshot;
  }

  Future<File> _storageFile() async {
    final File? override = _storageFileOverride;
    if (override != null) {
      return override;
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
