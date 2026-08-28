import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/domain/shared/vault_backup_policy.dart';
import 'package:quill_diary/infrastructure/drive/drive_upload_job.dart';
import 'package:quill_diary/infrastructure/drive/drive_upload_platform.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_models.dart';

/// 協調 App 端備份準備與原生背景上傳生命週期。
class DriveUploadCoordinator extends Notifier<DriveUploadState> {
  late final DriveUploadPlatform _platform;
  StreamSubscription<DriveUploadState>? _stateSubscription;
  Future<void> _queue = Future<void>.value();
  String? _completionKey;

  DriveUploadJobSnapshot? get job => state.job;

  DriveUploadFailureNotice? get failure => state.failure;

  bool get hasActiveJob => state.job?.blocksConflictingDriveActions ?? false;

  bool get isSupported => _platform.isSupported;

  @override
  DriveUploadState build() {
    _platform = ref.watch(driveUploadPlatformProvider);
    if (_platform.isSupported) {
      _stateSubscription = _platform.watchState().listen(_onStateEvent);
      ref.onDispose(() {
        unawaited(_stateSubscription?.cancel());
      });
      unawaited(_enqueue(_refreshUnlocked));
    }
    return const DriveUploadState();
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final Completer<T> completer = Completer<T>();
    _queue = _queue
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

  Future<void> refresh() {
    return _enqueue(_refreshUnlocked);
  }

  Future<void> _refreshUnlocked() async {
    if (!_platform.isSupported) {
      return;
    }
    await _applyState(await _platform.getState());
  }

  /// 建立備份檔並交給原生背景服務上傳；Service 接手後立即回傳。
  Future<BackupPersistResult> startBackgroundUpload({
    BackupTaskProgressListener? onProgress,
  }) {
    return _enqueue(
      () => _startBackgroundUploadUnlocked(onProgress: onProgress),
    );
  }

  Future<BackupPersistResult> _startBackgroundUploadUnlocked({
    BackupTaskProgressListener? onProgress,
  }) async {
    if (!_platform.isSupported) {
      throw UnsupportedError('Google Drive 背景上傳僅支援 Android。');
    }
    await _refreshUnlocked();
    if (hasActiveJob) {
      throw StateError('已有進行中的 Google Drive 上傳。');
    }

    final bool notificationsOk = await _platform
        .requestNotificationPermission();
    final BackupPersistResult prepared = await ref
        .read(appSessionProvider.notifier)
        .runBackgroundSafeTask(() async {
          return ref
              .read(vaultBackupServiceProvider)
              .prepareDriveUploadStaging(
                resolveStagingPath: (String fileName) {
                  return _platform.prepareStagingPath(fileName: fileName);
                },
                onProgress: onProgress,
              );
        });

    if (prepared.status != BackupPersistStatus.success ||
        prepared.savedPath == null) {
      return prepared;
    }

    final File staging = File(prepared.savedPath!);
    var nativeAccepted = false;
    try {
      final String fileName = prepared.message.trim().isNotEmpty
          ? prepared.message.trim()
          : staging.uri.pathSegments.last;
      final int sizeBytes = await staging.length();

      final DriveUploadJobSnapshot started = await _platform.startUpload(
        stagingPath: staging.path,
        fileName: fileName,
        sizeBytes: sizeBytes,
      );
      nativeAccepted = true;
      await _applyState(DriveUploadState(job: started, failure: state.failure));
      return BackupPersistResult(
        status: BackupPersistStatus.success,
        savedPath: 'background',
        message: notificationsOk ? 'background' : 'notifications_denied',
      );
    } on PlatformException catch (error) {
      if (error.code == 'fgs_start_not_allowed') {
        // 原生已 failAndCleanup（staging 已清）；failure 只經 getState → _applyState 寫入一次。
        nativeAccepted = true;
        await _applyState(await _platform.getState());
        final String message =
            error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : '無法在背景啟動上傳。請保持 App 顯示在畫面上後再試。';
        return BackupPersistResult(
          status: BackupPersistStatus.cancelled,
          message: message,
        );
      }
      final DriveUploadJobSnapshot? fromDetails = _jobFromPlatformDetails(
        error.details,
      );
      if (fromDetails != null) {
        // 原生已持久化工作；staging 改由原生持有，不可刪。
        nativeAccepted = true;
        await _applyState(
          DriveUploadState(job: fromDetails, failure: state.failure),
        );
      }
      rethrow;
    } catch (_) {
      rethrow;
    } finally {
      if (!nativeAccepted) {
        await _deleteIfExists(staging);
      }
    }
  }

  Future<void> cancelUpload() {
    return _enqueue(_cancelUploadUnlocked);
  }

  Future<void> _cancelUploadUnlocked() async {
    await _platform.cancelUpload();
    _completionKey = null;
    await _applyState(await _platform.getState());
  }

  Future<bool> notificationsAuthorized() {
    return _platform.notificationsAuthorized();
  }

  Future<bool> requestNotificationPermission() {
    return _platform.requestNotificationPermission();
  }

  Future<bool> consumeOpenDriveBackup() {
    return _platform.consumeOpenDriveBackup();
  }

  /// 使用者關閉失敗對話框後清除持久提示。
  Future<void> acknowledgeFailure(String jobId) {
    return _enqueue(() => _acknowledgeFailureUnlocked(jobId));
  }

  Future<void> _acknowledgeFailureUnlocked(String jobId) async {
    await _platform.ackFailure(jobId);
    final DriveUploadFailureNotice? current = state.failure;
    if (current != null && current.jobId == jobId) {
      await _applyState(DriveUploadState(job: state.job));
    } else {
      await _applyState(await _platform.getState());
    }
  }

  void _onStateEvent(DriveUploadState next) {
    unawaited(_enqueue(() => _applyState(next)));
  }

  Future<void> _applyState(DriveUploadState next) async {
    final DriveUploadFailureNotice? previousFailure = state.failure;
    final DriveUploadFailureNotice? nextFailure = next.failure;
    state = next;

    if (nextFailure != null &&
        (previousFailure == null ||
            previousFailure.jobId != nextFailure.jobId ||
            previousFailure.message != nextFailure.message)) {
      await _recordFailureStatus(nextFailure);
    }

    final DriveUploadJobSnapshot? job = next.job;
    if (job == null) {
      _completionKey = null;
      return;
    }
    if (job.needsCompletionHandling) {
      await _completeCommittedJob(job);
    }
  }

  Future<void> _recordFailureStatus(DriveUploadFailureNotice failure) async {
    final String message = failure.message.trim().isNotEmpty
        ? failure.message.trim()
        : '上次 Google Drive 備份未完成，已取消。請重新備份。';
    await ref
        .read(backupStatusStoreProvider)
        .recordFailure(
          action: BackupStatusAction.driveUpload,
          message: message,
        );
    ref.invalidate(backupStatusProvider);
  }

  Future<void> _completeCommittedJob(DriveUploadJobSnapshot job) async {
    final String key = _completionKeyFor(job);
    if (_completionKey == key) {
      return;
    }
    final DriveUploadState latestState = await _platform.getState();
    final DriveUploadJobSnapshot? latest = latestState.job;
    if (latest == null || latest.jobId != job.jobId) {
      state = latestState;
      return;
    }
    if (!latest.needsCompletionHandling) {
      state = latestState;
      return;
    }
    _completionKey = _completionKeyFor(latest);
    DriveUploadJobSnapshot current = latest;

    try {
      if (current.phase == DriveUploadPhase.statusPending) {
        String? accountLabel = current.accountEmail;
        try {
          final connection = await ref
              .read(vaultBackupServiceProvider)
              .getGoogleDriveConnectionState();
          accountLabel = connection.email ?? current.accountEmail;
        } on Object {
          accountLabel = current.accountEmail;
        }

        await ref
            .read(backupStatusStoreProvider)
            .recordDriveUploadSuccess(
              accountLabel: accountLabel,
              jobId: current.jobId,
            );
        ref.invalidate(backupStatusProvider);

        final DriveUploadJobSnapshot? marked = await _platform
            .markStatusRecorded(current.jobId);
        if (marked == null) {
          // 清 key 讓下次 refresh 可重試；勿 _applyState，否則持續 null 會遞迴收尾。
          _completionKey = null;
          return;
        }
        current = marked;
        state = DriveUploadState(job: current, failure: state.failure);
        _completionKey = _completionKeyFor(current);
      }

      if (current.phase == DriveUploadPhase.prunePending) {
        try {
          await ref
              .read(vaultBackupServiceProvider)
              .pruneDriveBackups(
                retainCount: VaultBackupPolicy.retainCount,
                keepFileId: current.remoteFileId,
                interactive: false,
              );
          await _platform.finalizeCommitted(current.jobId);
          _completionKey = null;
          state = DriveUploadState(failure: state.failure);
        } on Object {
          // silent：保留 PRUNE_PENDING，下次 refresh／回前景／進入設定可重試。
          _completionKey = null;
          return;
        }
      }
    } on Object {
      _completionKey = null;
      rethrow;
    }
  }

  String _completionKeyFor(DriveUploadJobSnapshot job) {
    return '${job.jobId}:${job.generation}:${job.phase.storageName}';
  }

  DriveUploadJobSnapshot? _jobFromPlatformDetails(Object? details) {
    if (details is! Map) {
      return null;
    }
    final Map<Object?, Object?> map = Map<Object?, Object?>.from(details);
    if (map.containsKey('job') || map.containsKey('failure')) {
      return DriveUploadState.fromMap(map).job;
    }
    return DriveUploadJobSnapshot.fromMap(map);
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      // 最佳努力清理。
    }
  }
}

final driveUploadPlatformProvider = Provider<DriveUploadPlatform>((Ref ref) {
  return DriveUploadPlatform();
});

final driveUploadCoordinatorProvider =
    NotifierProvider<DriveUploadCoordinator, DriveUploadState>(
      DriveUploadCoordinator.new,
    );
