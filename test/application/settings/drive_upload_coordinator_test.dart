import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/session/app_session_controller.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/settings/drive_upload_coordinator.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/drive/drive_upload_job.dart';
import 'package:quill_diary/infrastructure/drive/drive_upload_platform.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/external_directory_store.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_backup_service.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_models.dart';

import '../../helpers/session/fake_session_vault_repository.dart';
import '../../helpers/storage/vault_transfer_service_test_helpers.dart';
import '../../helpers/vault/test_vault_path_strategy.dart';

DriveUploadJobSnapshot _job({
  required String jobId,
  DriveUploadPhase phase = DriveUploadPhase.uploading,
  int generation = 1,
  String remoteFileId = 'remote-1',
  String stagingPath = '/tmp/a.zip',
}) {
  final bool committed =
      phase == DriveUploadPhase.statusPending ||
      phase == DriveUploadPhase.prunePending;
  return DriveUploadJobSnapshot(
    jobId: jobId,
    phase: phase,
    accountId: 'acc',
    accountEmail: 'user@example.com',
    stagingPath: stagingPath,
    fileName: 'a.zip',
    sizeBytes: 10,
    md5: 'abc',
    remoteFileId: remoteFileId,
    confirmedOffset: committed ? 10 : 4,
    retryCount: 0,
    progressFraction: committed ? 1 : 0.4,
    generation: generation,
  );
}

class _PassthroughSession extends AppSessionController {
  @override
  AppSessionState build() {
    return AppSessionState(
      status: AppLockStatus.unlocked,
      session: UnlockedVaultSession(
        vaultId: 'vault-drive-upload-test',
        trustedDevice: true,
        recoveryWrapKey: const <int>[1, 2, 3],
      ),
    );
  }

  @override
  Future<T> runBackgroundSafeTask<T>(Future<T> Function() action) => action();
}

class _FakeDriveUploadPlatform extends DriveUploadPlatform {
  final StreamController<DriveUploadState> _events =
      StreamController<DriveUploadState>.broadcast();
  DriveUploadJobSnapshot? active;
  DriveUploadFailureNotice? failure;
  Object? startError;
  int finalizeCalls = 0;
  int markStatusCalls = 0;
  int ackCalls = 0;
  /// 模擬 markStatusRecorded CAS 暫時失敗。
  bool rejectMarkStatus = false;

  DriveUploadState get envelope =>
      DriveUploadState(job: active, failure: failure);

  @override
  bool get isSupported => true;

  @override
  Stream<DriveUploadState> watchState() => _events.stream;

  @override
  Future<DriveUploadState> getState() async => envelope;

  @override
  Future<String> prepareStagingPath({required String fileName}) async {
    final Directory dir = await Directory.systemTemp.createTemp(
      'drive_upload_staging',
    );
    return '${dir.path}${Platform.pathSeparator}$fileName';
  }

  @override
  Future<DriveUploadJobSnapshot> startUpload({
    required String stagingPath,
    required String fileName,
    required int sizeBytes,
  }) async {
    final Object? error = startError;
    if (error != null) {
      if (error is PlatformException && error.details is Map) {
        final Map<Object?, Object?> details = Map<Object?, Object?>.from(
          error.details as Map,
        );
        details['stagingPath'] = stagingPath;
        details['fileName'] = fileName;
        details['sizeBytes'] = sizeBytes;
        throw PlatformException(
          code: error.code,
          message: error.message,
          details: details,
        );
      }
      throw error;
    }
    final DriveUploadJobSnapshot job = _job(
      jobId: 'job-started',
      phase: DriveUploadPhase.uploading,
      stagingPath: stagingPath,
    );
    active = job;
    return job;
  }

  @override
  Future<void> cancelUpload() async {
    active = null;
  }

  @override
  Future<DriveUploadState> abandonCancelCleanup(String jobId) async {
    if (active?.jobId == jobId) {
      active = null;
    }
    return envelope;
  }

  @override
  Future<void> ackFailure(String jobId) async {
    ackCalls++;
    if (failure?.jobId == jobId) {
      failure = null;
    }
  }

  @override
  Future<DriveUploadJobSnapshot?> markStatusRecorded(String jobId) async {
    markStatusCalls++;
    if (rejectMarkStatus) {
      return null;
    }
    final DriveUploadJobSnapshot? current = active;
    if (current == null || current.jobId != jobId) {
      return null;
    }
    active = _job(
      jobId: current.jobId,
      phase: DriveUploadPhase.prunePending,
      generation: current.generation + 1,
      remoteFileId: current.remoteFileId,
      stagingPath: current.stagingPath,
    );
    return active;
  }

  @override
  Future<void> finalizeCommitted(String jobId) async {
    finalizeCalls++;
    active = null;
  }

  @override
  Future<bool> notificationsAuthorized() async => true;

  @override
  Future<bool> requestNotificationPermission() async => true;

  void dispose() {
    unawaited(_events.close());
  }
}

class _FakeVaultBackupService extends VaultBackupService {
  _FakeVaultBackupService()
    : super(
        archiveIo: VaultArchiveIo(
          pathStrategy: DummyVaultPathStrategy(),
          repository: FakeSessionVaultRepository(),
          frontMatterCodec: const FrontMatterCodec(),
          indexDatabaseManager: IndexDatabaseManager(DummyVaultPathStrategy()),
          editorDraftStore: EditorDraftStore(
            pathStrategy: DummyVaultPathStrategy(),
            cryptoService: LocalCryptoService(),
          ),
        ),
        driveBackupService: const UnusedDriveBackupService(),
        externalDirectoryStore: ExternalDirectoryStore(
          DummyVaultPathStrategy(),
        ),
        pathStrategy: DummyVaultPathStrategy(),
      );

  Object? pruneError;
  int pruneCalls = 0;
  File? lastStaging;

  @override
  Future<BackupPersistResult> prepareDriveUploadStaging({
    required Future<String> Function(String fileName) resolveStagingPath,
    BackupTaskProgressListener? onProgress,
  }) async {
    final String path = await resolveStagingPath('backup_test.zip');
    final File staging = File(path);
    await staging.parent.create(recursive: true);
    await staging.writeAsString('zip-bytes');
    lastStaging = staging;
    return BackupPersistResult(
      status: BackupPersistStatus.success,
      savedPath: staging.path,
      message: 'backup_test.zip',
    );
  }

  @override
  Future<void> pruneDriveBackups({
    required int retainCount,
    String? keepFileId,
    bool interactive = true,
  }) async {
    pruneCalls++;
    final Object? error = pruneError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<DriveConnectionState> getGoogleDriveConnectionState() async {
    return const DriveConnectionState(
      isConnected: true,
      email: 'user@example.com',
      displayName: 'User',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory statusDir;
  late File statusFile;
  late _FakeDriveUploadPlatform platform;
  late _FakeVaultBackupService backupService;

  setUp(() async {
    statusDir = await Directory.systemTemp.createTemp('drive_coord_status');
    statusFile = File('${statusDir.path}/backup_status.json');
    platform = _FakeDriveUploadPlatform();
    backupService = _FakeVaultBackupService();
  });

  tearDown(() async {
    platform.dispose();
    if (statusDir.existsSync()) {
      await statusDir.delete(recursive: true);
    }
    final File? staging = backupService.lastStaging;
    if (staging != null && staging.parent.existsSync()) {
      await staging.parent.delete(recursive: true);
    }
  });

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        appSessionProvider.overrideWith(_PassthroughSession.new),
        driveUploadPlatformProvider.overrideWithValue(platform),
        vaultBackupServiceProvider.overrideWithValue(backupService),
        backupStatusStoreProvider.overrideWithValue(
          BackupStatusStore(storageFile: statusFile),
        ),
      ],
    );
  }

  test('build 時 refresh 不會因巢狀 enqueue 卡住', () async {
    final ProviderContainer container = buildContainer();
    addTearDown(container.dispose);
    final DriveUploadCoordinator coordinator = container.read(
      driveUploadCoordinatorProvider.notifier,
    );
    await coordinator.refresh();

    platform.active = _job(
      jobId: 'job-active',
      phase: DriveUploadPhase.uploading,
    );
    await coordinator.refresh().timeout(const Duration(seconds: 2));
    expect(coordinator.job?.phase, DriveUploadPhase.uploading);
    expect(coordinator.job?.jobId, 'job-active');
  });

  test('failure notice 會寫入備份失敗狀態，ack 後清除', () async {
    final ProviderContainer container = buildContainer();
    addTearDown(container.dispose);
    final DriveUploadCoordinator coordinator = container.read(
      driveUploadCoordinatorProvider.notifier,
    );
    await coordinator.refresh();

    platform.failure = const DriveUploadFailureNotice(
      jobId: 'job-abandoned',
      message: '上次 Google Drive 備份未完成，已取消。請重新備份。',
    );
    await coordinator.refresh().timeout(const Duration(seconds: 2));
    expect(coordinator.job, isNull);
    expect(coordinator.failure?.jobId, 'job-abandoned');
    final BackupStatusSnapshot status = await container
        .read(backupStatusStoreProvider)
        .read();
    expect(status.lastFailure?.action, BackupStatusAction.driveUpload);

    await coordinator.acknowledgeFailure('job-abandoned');
    expect(platform.ackCalls, 1);
    expect(coordinator.failure, isNull);
  });

  test('abandonCancelCleanup 會清除 CANCEL_CLEANUP_PENDING', () async {
    final ProviderContainer container = buildContainer();
    addTearDown(container.dispose);
    final DriveUploadCoordinator coordinator = container.read(
      driveUploadCoordinatorProvider.notifier,
    );
    await coordinator.refresh();

    platform.active = _job(
      jobId: 'job-cleanup',
      phase: DriveUploadPhase.cancelCleanupPending,
    );
    await coordinator.refresh().timeout(const Duration(seconds: 2));
    expect(coordinator.job?.phase, DriveUploadPhase.cancelCleanupPending);

    await coordinator.abandonCancelCleanup('job-cleanup');
    expect(coordinator.job, isNull);
  });

  test('FGS 啟動失敗會回傳取消並只經 failure notice 記一次', () async {
    const String fgsMessage = '無法在背景啟動上傳。請保持 App 顯示在畫面上後再試。';
    final ProviderContainer container = buildContainer();
    addTearDown(container.dispose);
    final DriveUploadCoordinator coordinator = container.read(
      driveUploadCoordinatorProvider.notifier,
    );
    await coordinator.refresh();

    // 模擬原生 failAndCleanup 後留下的 failure notice（唯一寫入 BackupStatusStore 的來源）。
    platform.active = null;
    platform.failure = const DriveUploadFailureNotice(
      jobId: 'job-fgs',
      message: fgsMessage,
    );
    platform.startError = PlatformException(
      code: 'fgs_start_not_allowed',
      message: fgsMessage,
    );

    final BackupPersistResult result = await coordinator
        .startBackgroundUpload();
    expect(result.status, BackupPersistStatus.cancelled);
    expect(result.message, fgsMessage);
    expect(coordinator.job, isNull);
    expect(coordinator.failure?.jobId, 'job-fgs');
    final BackupStatusSnapshot status = await container
        .read(backupStatusStoreProvider)
        .read();
    expect(status.lastFailure?.action, BackupStatusAction.driveUpload);
    expect(status.lastFailure?.message, fgsMessage);
  });

  test('markStatusRecorded 暫時失敗後 refresh 仍可完成收尾', () async {
    final ProviderContainer container = buildContainer();
    addTearDown(container.dispose);
    final DriveUploadCoordinator coordinator = container.read(
      driveUploadCoordinatorProvider.notifier,
    );
    await coordinator.refresh();

    platform.active = _job(
      jobId: 'job-retry-mark',
      phase: DriveUploadPhase.statusPending,
      generation: 2,
    );
    platform.rejectMarkStatus = true;
    platform.markStatusCalls = 0;
    platform.finalizeCalls = 0;
    backupService.pruneCalls = 0;

    await coordinator.refresh().timeout(const Duration(seconds: 2));
    expect(platform.markStatusCalls, 1);
    expect(platform.finalizeCalls, 0);
    expect(platform.active?.phase, DriveUploadPhase.statusPending);

    platform.rejectMarkStatus = false;
    await coordinator.refresh().timeout(const Duration(seconds: 2));
    expect(platform.markStatusCalls, 2);
    expect(backupService.pruneCalls, 1);
    expect(platform.finalizeCalls, 1);
    expect(coordinator.job, isNull);
  });

  test('prune 失敗不清 finalize，修正後可重試完成', () async {
    backupService.pruneError = StateError('prune failed');
    final ProviderContainer container = buildContainer();
    addTearDown(container.dispose);
    final DriveUploadCoordinator coordinator = container.read(
      driveUploadCoordinatorProvider.notifier,
    );
    await coordinator.refresh();

    platform.active = _job(
      jobId: 'job-done',
      phase: DriveUploadPhase.statusPending,
      generation: 3,
    );
    platform.markStatusCalls = 0;
    platform.finalizeCalls = 0;
    backupService.pruneCalls = 0;

    await coordinator.refresh().timeout(const Duration(seconds: 2));
    expect(platform.markStatusCalls, 1);
    expect(backupService.pruneCalls, 1);
    expect(platform.finalizeCalls, 0);
    expect(platform.active?.phase, DriveUploadPhase.prunePending);

    backupService.pruneError = null;
    await coordinator.refresh().timeout(const Duration(seconds: 2));
    expect(backupService.pruneCalls, 2);
    expect(platform.markStatusCalls, 1);
    expect(platform.finalizeCalls, 1);
    expect(coordinator.job, isNull);
  });

  test('STATUS_PENDING 會記錄成功、prune 並 finalize', () async {
    final ProviderContainer container = buildContainer();
    addTearDown(container.dispose);
    final DriveUploadCoordinator coordinator = container.read(
      driveUploadCoordinatorProvider.notifier,
    );
    await coordinator.refresh();

    platform.active = _job(
      jobId: 'job-finish',
      phase: DriveUploadPhase.statusPending,
      generation: 2,
    );
    platform.markStatusCalls = 0;
    platform.finalizeCalls = 0;
    backupService.pruneCalls = 0;

    await coordinator.refresh().timeout(const Duration(seconds: 2));
    expect(platform.markStatusCalls, 1);
    expect(backupService.pruneCalls, 1);
    expect(platform.finalizeCalls, 1);
    expect(coordinator.job, isNull);
  });

  test('Drive 上傳成功紀錄以 jobId 冪等，不會重寫時間戳', () async {
    final BackupStatusStore store = BackupStatusStore(storageFile: statusFile);
    await store.recordDriveUploadSuccess(
      accountLabel: 'user@example.com',
      jobId: 'job-1',
      at: DateTime.utc(2026, 1, 1),
    );
    final BackupStatusSnapshot first = await store.read();
    await store.recordDriveUploadSuccess(
      accountLabel: 'user@example.com',
      jobId: 'job-1',
      at: DateTime.utc(2026, 2, 1),
    );
    final BackupStatusSnapshot second = await store.read();

    expect(first.lastDriveUploadJobId, 'job-1');
    expect(second.lastDriveUploadAt, DateTime.utc(2026, 1, 1));
    expect(second.lastDriveUploadJobId, 'job-1');
  });

  test('BackupStatusStore 並發本機與 Drive 寫入不會互相覆蓋', () async {
    final BackupStatusStore store = BackupStatusStore(storageFile: statusFile);
    await Future.wait(<Future<void>>[
      store.recordLocalBackupSuccess(at: DateTime.utc(2026, 3, 1)),
      store.recordDriveUploadSuccess(
        accountLabel: 'user@example.com',
        jobId: 'job-parallel',
        at: DateTime.utc(2026, 3, 2),
      ),
    ]);
    final BackupStatusSnapshot snapshot = await store.read();
    expect(snapshot.lastLocalBackupAt, DateTime.utc(2026, 3, 1));
    expect(snapshot.lastDriveUploadAt, DateTime.utc(2026, 3, 2));
    expect(snapshot.lastDriveUploadJobId, 'job-parallel');
  });
}
