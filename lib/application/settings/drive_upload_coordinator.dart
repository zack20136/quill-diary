import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/shared/vault_backup_policy.dart';
import 'package:quill_diary/infrastructure/drive/drive_upload_job.dart';
import 'package:quill_diary/infrastructure/drive/drive_upload_platform.dart';
import 'package:quill_diary/infrastructure/drive/google_drive_error.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_models.dart';
import 'package:quill_diary/l10n/l10n.dart';

/// 協調 App 端備份準備與原生背景上傳生命週期。
class DriveUploadCoordinator extends Notifier<DriveUploadState> {
  late final DriveUploadPlatform _platform;
  StreamSubscription<DriveUploadState>? _stateSubscription;
  Future<void> _queue = Future<void>.value();
  Future<void>? _automaticPrune;
  String? _completionKey;
  bool _appIsForeground = true;

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
    _queue = _queue.catchError((Object _) {}).then((_) async {
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

  /// 同步 App 是否可互動；背景事件只更新 persisted job，不啟動 Google 收尾。
  void setAppForeground(bool isForeground) {
    _appIsForeground = isForeground;
  }

  Future<void> syncLocale(AppLanguage language) {
    return _enqueue(() => _platform.setLocale(language.storageValue));
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
      throw const GoogleDriveException(
        GoogleDriveErrorCode.backgroundUploadUnsupported,
      );
    }
    final AppLanguage language = ref
        .read(personalizationPreferencesProvider)
        .maybeWhen(
          data: (PersonalizationPreferences value) => value.locale,
          orElse: () => AppLanguage.zh,
        );
    await _platform.setLocale(language.storageValue);
    await _refreshUnlocked();
    if (hasActiveJob) {
      throw const GoogleDriveException(
        GoogleDriveErrorCode.uploadAlreadyActive,
      );
    }

    // 補清先前收尾時留下的多餘舊檔；失敗或逾時不擋本次上傳。
    await _runAutomaticPrune();

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
        final String message = const GoogleDriveException(
          GoogleDriveErrorCode.backgroundStartNotAllowed,
        ).localizedMessage(_currentL10n());
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

  Future<void> abandonCancelCleanup(String jobId) {
    return _enqueue(() => _abandonCancelCleanupUnlocked(jobId));
  }

  Future<void> _abandonCancelCleanupUnlocked(String jobId) async {
    final DriveUploadState next = await _platform.abandonCancelCleanup(jobId);
    _completionKey = null;
    await _applyState(next);
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

  /// EventChannel 只喚醒：一律 getState，避免過期 payload 覆寫已收尾狀態。
  void _onStateEvent(DriveUploadState _) {
    unawaited(_enqueue(_refreshUnlocked));
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
    if (_appIsForeground && job.needsCompletionHandling) {
      await _completeCommittedJob(job);
    }
  }

  Future<void> _recordFailureStatus(DriveUploadFailureNotice failure) async {
    final String message = failure.message.trim().isNotEmpty
        ? failure.message.trim()
        : _currentL10n().driveUploadAbandonedFailureBody;
    await ref
        .read(backupStatusStoreProvider)
        .recordFailure(
          action: BackupStatusAction.driveUpload,
          message: message,
        );
    ref.invalidate(backupStatusProvider);
  }

  AppLocalizations _currentL10n() {
    final AppLanguage language = ref
        .read(personalizationPreferencesProvider)
        .maybeWhen(
          data: (PersonalizationPreferences value) => value.locale,
          orElse: () => AppLanguage.zh,
        );
    return lookupAppLocalizations(language.materialLocale);
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
      // STATUS／PRUNE 冷啟動都冪等寫成功紀錄，避免 store 與 native 脫節漏記。
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

      if (current.phase == DriveUploadPhase.statusPending) {
        final DriveUploadJobSnapshot? marked = await _platform
            .markStatusRecorded(current.jobId);
        // 必須確認已進 PRUNE_PENDING；失敗回 null 時可 refresh 重試。
        if (marked == null || marked.phase != DriveUploadPhase.prunePending) {
          _completionKey = null;
          return;
        }
        current = marked;
        state = DriveUploadState(job: current, failure: state.failure);
        _completionKey = _completionKeyFor(current);
      }

      if (current.phase == DriveUploadPhase.prunePending) {
        // 遠端備份已成功；prune 失敗或逾時仍 finalize。
        await _runAutomaticPrune(keepFileId: current.remoteFileId);
        await _platform.finalizeCommitted(current.jobId);
        _completionKey = null;
        // 以 getState 對帳；不可 _applyState（仍 needsCompletion 會遞迴收尾）。
        state = await _platform.getState();
      }
    } on Object {
      _completionKey = null;
      rethrow;
    }
  }

  String _completionKeyFor(DriveUploadJobSnapshot job) {
    return '${job.jobId}:${job.generation}:${job.phase.storageName}';
  }

  /// 自動 prune 為 single-flight；逾時只停止等待，底層完成前不重複啟動。
  Future<void> _runAutomaticPrune({String? keepFileId}) async {
    if (_automaticPrune != null) {
      return;
    }
    try {
      final Future<void> operation = ref
          .read(vaultBackupServiceProvider)
          .pruneDriveBackups(
            retainCount: VaultBackupPolicy.retainCount,
            keepFileId: keepFileId,
            interactive: false,
          );
      late final Future<void> tracked;
      tracked = operation.catchError((Object _) {}).whenComplete(() {
        if (identical(_automaticPrune, tracked)) {
          _automaticPrune = null;
        }
      });
      _automaticPrune = tracked;
      await tracked.timeout(
        ref.read(driveUploadCompletionPruneTimeoutProvider),
      );
    } on Object {
      // best-effort；多餘舊檔留給下一次可執行的自動 prune。
    }
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

final driveUploadCompletionPruneTimeoutProvider = Provider<Duration>(
  (Ref ref) => const Duration(seconds: 10),
);

final driveUploadCoordinatorProvider =
    NotifierProvider<DriveUploadCoordinator, DriveUploadState>(
      DriveUploadCoordinator.new,
    );
