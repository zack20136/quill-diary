import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../config/app_identifiers.dart';

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
      occurredAt: DateTime.tryParse((json['occurred_at'] ?? '').toString()) ??
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
    this.lastFailure,
  });

  final DateTime? lastLocalBackupAt;
  final DateTime? lastExternalExportAt;
  final DateTime? lastDriveUploadAt;
  final String? lastDriveAccountLabel;
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
      if (lastFailure != null) 'last_failure': lastFailure!.toJson(),
    };
  }

  factory BackupStatusSnapshot.fromJson(Map<String, Object?> json) {
    return BackupStatusSnapshot(
      lastLocalBackupAt: _parseDateTime(json['last_local_backup_at']),
      lastExternalExportAt: _parseDateTime(json['last_external_export_at']),
      lastDriveUploadAt: _parseDateTime(json['last_drive_upload_at']),
      lastDriveAccountLabel: json['last_drive_account_label']?.toString(),
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

  Future<BackupStatusSnapshot> read() async {
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
    } else {
      _cache = const BackupStatusSnapshot();
    }
    return _cache!;
  }

  Future<void> recordLocalBackupSuccess({DateTime? at}) async {
    final BackupStatusSnapshot current = await read();
    await _persist(
      BackupStatusSnapshot(
        lastLocalBackupAt: at ?? DateTime.now(),
        lastExternalExportAt: current.lastExternalExportAt,
        lastDriveUploadAt: current.lastDriveUploadAt,
        lastDriveAccountLabel: current.lastDriveAccountLabel,
        lastFailure: current.lastFailure,
      ),
    );
  }

  Future<void> recordExternalExportSuccess({DateTime? at}) async {
    final BackupStatusSnapshot current = await read();
    await _persist(
      BackupStatusSnapshot(
        lastLocalBackupAt: current.lastLocalBackupAt,
        lastExternalExportAt: at ?? DateTime.now(),
        lastDriveUploadAt: current.lastDriveUploadAt,
        lastDriveAccountLabel: current.lastDriveAccountLabel,
        lastFailure: current.lastFailure,
      ),
    );
  }

  Future<void> recordDriveUploadSuccess({
    String? accountLabel,
    DateTime? at,
  }) async {
    final BackupStatusSnapshot current = await read();
    final String? trimmedAccount = accountLabel?.trim();
    await _persist(
      BackupStatusSnapshot(
        lastLocalBackupAt: current.lastLocalBackupAt,
        lastExternalExportAt: current.lastExternalExportAt,
        lastDriveUploadAt: at ?? DateTime.now(),
        lastDriveAccountLabel: trimmedAccount != null && trimmedAccount.isNotEmpty
            ? trimmedAccount
            : null,
        lastFailure: current.lastFailure,
      ),
    );
  }

  Future<void> recordFailure({
    required BackupStatusAction action,
    required String message,
    DateTime? at,
  }) async {
    final BackupStatusSnapshot current = await read();
    await _persist(
      BackupStatusSnapshot(
        lastLocalBackupAt: current.lastLocalBackupAt,
        lastExternalExportAt: current.lastExternalExportAt,
        lastDriveUploadAt: current.lastDriveUploadAt,
        lastDriveAccountLabel: current.lastDriveAccountLabel,
        lastFailure: BackupFailureRecord(
          action: action,
          message: message.trim(),
          occurredAt: at ?? DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _persist(BackupStatusSnapshot snapshot) async {
    final File file = await _storageFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
      flush: true,
    );
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
