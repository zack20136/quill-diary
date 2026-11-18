import 'package:flutter/foundation.dart';
import 'package:quill_diary/domain/recovery/recovery_key_identity.dart';

/// 原生背景上傳服務回報的上傳階段。
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
  const DriveUploadFailureNotice({required this.jobId, required this.message});

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
    this.backupIdentity,
    this.backupPurpose,
    this.nextRetryAt,
    this.lastErrorCode,
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
  final RecoveryKeyIdentity? backupIdentity;
  final VaultBackupPurpose? backupPurpose;
  final DateTime? nextRetryAt;
  final String? lastErrorCode;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  /// 與 Android 通知一致採無條件捨去，未完成時不提早顯示 100%。
  int get progressPercent {
    if (sizeBytes <= 0) {
      return 0;
    }
    final int boundedOffset = confirmedOffset.clamp(0, sizeBytes);
    return (boundedOffset * 100) ~/ sizeBytes;
  }

  bool get isCancelCleanupPending =>
      phase == DriveUploadPhase.cancelCleanupPending;

  /// 取消清理因授權失效或帳戶不符而卡住，允許重連原帳戶或放棄。
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
    String readString(String key) => '${raw[key] ?? ''}'.trim();

    int? parseInt(String key) {
      final Object? value = raw[key];
      return switch (value) {
        int() => value,
        num() when value.isFinite => value.toInt(),
        String() => int.tryParse(value),
        _ => null,
      };
    }

    DateTime? readTime(String key) {
      final int? epoch = parseInt(key);
      if (epoch == null || epoch <= 0 || epoch > 8640000000000000) {
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

    final int sizeBytes = parseInt('sizeBytes') ?? 0;
    final int confirmedOffset = parseInt('confirmedOffset') ?? 0;
    final Object? rawProgress = raw['progressFraction'];
    final double? platformProgress = rawProgress is num
        ? rawProgress.toDouble()
        : double.tryParse('$rawProgress');
    final double progress =
        platformProgress != null && platformProgress.isFinite
        ? platformProgress
        : (sizeBytes > 0 ? confirmedOffset / sizeBytes : 0.0);
    final String md5 = readString('md5');
    final int retries = parseInt('retryCount') ?? -1;
    final String errorCode = readString('lastErrorCode');

    return DriveUploadJobSnapshot(
      jobId: readString('jobId'),
      phase: phase,
      accountId: readString('accountId'),
      accountEmail: readString('accountEmail'),
      stagingPath: readString('stagingPath'),
      fileName: readString('fileName'),
      sizeBytes: sizeBytes,
      md5: md5.isNotEmpty ? md5 : readString('sha256'),
      remoteFileId: readString('remoteFileId'),
      confirmedOffset: confirmedOffset,
      retryCount: retries >= 0 ? retries : (parseInt('attemptCount') ?? 0),
      progressFraction: progress.clamp(0.0, 1.0),
      generation: parseInt('generation') ?? 0,
      backupIdentity: raw['backupIdentity'] is Map
          ? RecoveryKeyIdentity.fromJson(raw['backupIdentity'] as Map)
          : null,
      backupPurpose: switch (raw['backupPurpose']) {
        'normal' => VaultBackupPurpose.normal,
        'preservation' => VaultBackupPurpose.preservation,
        _ => null,
      },
      nextRetryAt: readTime('nextRetryAtEpochMs'),
      lastErrorCode: errorCode.isEmpty ? null : errorCode,
      updatedAt: readTime('updatedAtEpochMs'),
      createdAt: readTime('createdAtEpochMs'),
    );
  }
}
