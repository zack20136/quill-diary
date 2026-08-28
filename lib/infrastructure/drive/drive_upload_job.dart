import 'package:flutter/foundation.dart';

/// Google Drive 背景上傳工作階段。
enum DriveUploadPhase {
  staged,
  uploading,
  waitingForNetwork,
  statusPending,
  prunePending,
  cancelCleanupPending;

  static DriveUploadPhase? fromName(String? raw) {
    final String normalized = (raw ?? '').trim().toUpperCase();
    return switch (normalized) {
      'STAGED' => DriveUploadPhase.staged,
      'UPLOADING' => DriveUploadPhase.uploading,
      'WAITING_FOR_NETWORK' => DriveUploadPhase.waitingForNetwork,
      'STATUS_PENDING' => DriveUploadPhase.statusPending,
      'PRUNE_PENDING' => DriveUploadPhase.prunePending,
      'CANCEL_CLEANUP_PENDING' => DriveUploadPhase.cancelCleanupPending,
      // 舊版 PREPARING／CLEANUP_PENDING 相容讀取。
      'PREPARING' => DriveUploadPhase.staged,
      'CLEANUP_PENDING' => DriveUploadPhase.prunePending,
      _ => null,
    };
  }

  String get storageName => switch (this) {
    DriveUploadPhase.staged => 'STAGED',
    DriveUploadPhase.uploading => 'UPLOADING',
    DriveUploadPhase.waitingForNetwork => 'WAITING_FOR_NETWORK',
    DriveUploadPhase.statusPending => 'STATUS_PENDING',
    DriveUploadPhase.prunePending => 'PRUNE_PENDING',
    DriveUploadPhase.cancelCleanupPending => 'CANCEL_CLEANUP_PENDING',
  };
}

@immutable
final class DriveUploadFailureNotice {
  const DriveUploadFailureNotice({
    required this.jobId,
    required this.message,
  });

  final String jobId;
  final String message;

  factory DriveUploadFailureNotice.fromMap(Map<Object?, Object?> raw) {
    return DriveUploadFailureNotice(
      jobId: '${raw['jobId'] ?? ''}'.trim(),
      message: '${raw['message'] ?? ''}'.trim(),
    );
  }
}

@immutable
final class DriveUploadState {
  const DriveUploadState({this.job, this.failure});

  final DriveUploadJobSnapshot? job;
  final DriveUploadFailureNotice? failure;

  factory DriveUploadState.fromMap(Map<Object?, Object?> raw) {
    final Object? jobRaw = raw['job'];
    final Object? failureRaw = raw['failure'];
    return DriveUploadState(
      job: jobRaw is Map
          ? DriveUploadJobSnapshot.fromMap(Map<Object?, Object?>.from(jobRaw))
          : null,
      failure: failureRaw is Map
          ? DriveUploadFailureNotice.fromMap(
              Map<Object?, Object?>.from(failureRaw),
            )
          : null,
    );
  }
}

@immutable
final class DriveUploadJobSnapshot {
  const DriveUploadJobSnapshot({
    required this.jobId,
    required this.phase,
    required this.accountId,
    required this.accountEmail,
    required this.stagingPath,
    required this.fileName,
    required this.sizeBytes,
    required this.md5,
    required this.remoteFileId,
    required this.confirmedOffset,
    required this.retryCount,
    required this.progressFraction,
    this.generation = 0,
    this.nextRetryAt,
    this.lastErrorCode,
    this.lastErrorMessage,
    this.updatedAt,
    this.createdAt,
  });

  final String jobId;
  final DriveUploadPhase phase;
  final String accountId;
  final String accountEmail;
  final String stagingPath;
  final String fileName;
  final int sizeBytes;
  final String md5;
  final String remoteFileId;
  final int confirmedOffset;
  final int retryCount;
  final double progressFraction;
  final int generation;
  final DateTime? nextRetryAt;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  bool get isActive => true;

  bool get blocksConflictingDriveActions => isActive;

  bool get isCancelCleanupPending =>
      phase == DriveUploadPhase.cancelCleanupPending;

  /// 取消清理因授權失效或帳號不符而卡住，允許重連原帳號或放棄。
  bool get needsCancelCleanupAccountRecovery {
    if (!isCancelCleanupPending) {
      return false;
    }
    final String? code = lastErrorCode;
    return code == 'cleanup_needs_reauth' || code == 'cleanup_account_mismatch';
  }

  bool get needsStatusRecording => phase == DriveUploadPhase.statusPending;

  /// 遠端已驗證，等待本機成功紀錄與 prune。
  bool get needsCompletionHandling =>
      phase == DriveUploadPhase.statusPending ||
      phase == DriveUploadPhase.prunePending;

  factory DriveUploadJobSnapshot.fromMap(Map<Object?, Object?> raw) {
    int readInt(String key, [int fallback = 0]) {
      final Object? value = raw[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      return int.tryParse('$value') ?? fallback;
    }

    double readDouble(String key, [double fallback = 0]) {
      final Object? value = raw[key];
      if (value is double) {
        return value;
      }
      if (value is num) {
        return value.toDouble();
      }
      return double.tryParse('$value') ?? fallback;
    }

    DateTime? readTime(String key) {
      final int? epoch = () {
        final Object? value = raw[key];
        if (value == null) {
          return null;
        }
        if (value is int) {
          return value;
        }
        if (value is num) {
          return value.toInt();
        }
        return int.tryParse('$value');
      }();
      if (epoch == null || epoch <= 0) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch(epoch);
    }

    final DriveUploadPhase? phase = DriveUploadPhase.fromName(
      '${raw['phase'] ?? ''}',
    );
    if (phase == null) {
      throw FormatException('未知的 Drive 上傳 phase：${raw['phase']}');
    }

    final double progress = raw.containsKey('progressFraction')
        ? readDouble('progressFraction')
        : () {
            final int size = readInt('sizeBytes');
            final int offset = readInt('confirmedOffset');
            if (size <= 0) {
              return 0.0;
            }
            return (offset / size).clamp(0.0, 1.0);
          }();

    final String md5 = () {
      final String value = '${raw['md5'] ?? ''}'.trim();
      if (value.isNotEmpty) {
        return value;
      }
      // 相容舊快照欄位。
      return '${raw['sha256'] ?? ''}'.trim();
    }();

    return DriveUploadJobSnapshot(
      jobId: '${raw['jobId'] ?? ''}'.trim(),
      phase: phase,
      accountId: '${raw['accountId'] ?? ''}'.trim(),
      accountEmail: '${raw['accountEmail'] ?? ''}'.trim(),
      stagingPath: '${raw['stagingPath'] ?? ''}'.trim(),
      fileName: '${raw['fileName'] ?? ''}'.trim(),
      sizeBytes: readInt('sizeBytes'),
      md5: md5,
      remoteFileId: '${raw['remoteFileId'] ?? ''}'.trim(),
      confirmedOffset: readInt('confirmedOffset'),
      retryCount: () {
        final int retry = readInt('retryCount', -1);
        if (retry >= 0) {
          return retry;
        }
        return readInt('attemptCount');
      }(),
      progressFraction: progress.clamp(0.0, 1.0),
      generation: readInt('generation'),
      nextRetryAt: readTime('nextRetryAtEpochMs'),
      lastErrorCode: () {
        final String value = '${raw['lastErrorCode'] ?? ''}'.trim();
        return value.isEmpty ? null : value;
      }(),
      lastErrorMessage: () {
        final String value = '${raw['lastErrorMessage'] ?? ''}'.trim();
        return value.isEmpty ? null : value;
      }(),
      updatedAt: readTime('updatedAtEpochMs'),
      createdAt: readTime('createdAtEpochMs'),
    );
  }
}
