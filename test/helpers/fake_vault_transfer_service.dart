import 'dart:io';

import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/storage/external_directory_store.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_service.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';

import 'fake_session_vault_repository.dart';
import 'test_vault_path_strategy.dart';

class FakeVaultTransferService extends VaultTransferService {
  FakeVaultTransferService({
    DriveConnectionState? connectionState,
    this.connectionStates,
    this.driveBackups = const <DriveBackupFile>[],
    this.downloadToTemp,
    this.precheckRestoreError,
    this.precheckRestoreResult,
  }) : super(
         archiveIo: VaultArchiveIo(
           pathStrategy: DummyVaultPathStrategy(),
           repository: FakeSessionVaultRepository(),
           frontMatterCodec: const FrontMatterCodec(),
           indexDatabaseManager: IndexDatabaseManager(DummyVaultPathStrategy()),
         ),
         driveBackupService: _UnusedDriveBackupService(),
         vaultRepository: FakeSessionVaultRepository(),
         externalDirectoryStore: ExternalDirectoryStore(
           DummyVaultPathStrategy(),
         ),
         pathStrategy: DummyVaultPathStrategy(),
       ) {
    _connectionState =
        connectionState ?? const DriveConnectionState.disconnected();
  }

  late DriveConnectionState _connectionState;
  final List<DriveConnectionState>? connectionStates;
  List<DriveBackupFile> driveBackups;
  File Function(DriveBackupFile backup)? downloadToTemp;
  Object? precheckRestoreError;
  RestorePrecheck? precheckRestoreResult;

  int isConnectedCalls = 0;
  int linkCalls = 0;
  int switchAccountCalls = 0;
  int disconnectCalls = 0;
  int saveBackupToAppLocalCalls = 0;
  int listAppLocalBackupsCalls = 0;
  int saveBackupToExternalDirectoryCalls = 0;
  int uploadBackupToDriveCalls = 0;
  int listDriveBackupsCalls = 0;
  int downloadDriveBackupToTempFileCalls = 0;
  int precheckRestoreCalls = 0;

  @override
  Future<BackupPersistResult> saveBackupToAppLocal({
    BackupTaskProgressListener? onProgress,
  }) {
    saveBackupToAppLocalCalls++;
    throw UnimplementedError();
  }

  @override
  Future<List<LocalBackupFile>> listAppLocalBackups() async {
    listAppLocalBackupsCalls++;
    return const <LocalBackupFile>[];
  }

  @override
  Future<BackupPersistResult> saveBackupToExternalDirectory({
    BackupTaskProgressListener? onProgress,
  }) {
    saveBackupToExternalDirectoryCalls++;
    throw UnimplementedError();
  }

  @override
  Future<BackupPersistResult> uploadBackupToDrive({
    BackupTaskProgressListener? onProgress,
  }) {
    uploadBackupToDriveCalls++;
    throw UnimplementedError();
  }

  @override
  Future<DriveConnectionState> getGoogleDriveConnectionState() async {
    final int callIndex = isConnectedCalls++;
    final List<DriveConnectionState>? values = connectionStates;
    if (values != null && callIndex < values.length) {
      _connectionState = values[callIndex];
      return _connectionState;
    }
    return _connectionState;
  }

  @override
  Future<DriveConnectionState> linkGoogleDrive() async {
    linkCalls++;
    return _connectionState;
  }

  @override
  Future<DriveConnectionState> switchGoogleDrive() async {
    switchAccountCalls++;
    return _connectionState;
  }

  @override
  Future<void> disconnectGoogleDrive() async {
    disconnectCalls++;
    _connectionState = const DriveConnectionState.disconnected();
  }

  @override
  Future<void> deleteDriveBackup(DriveBackupFile backup) async {}

  @override
  Future<List<DriveBackupFile>> listDriveBackups() async {
    listDriveBackupsCalls++;
    return driveBackups;
  }

  @override
  Future<File> downloadDriveBackupToTempFile(
    DriveBackupFile backup, {
    BackupTaskProgressListener? onProgress,
  }) async {
    downloadDriveBackupToTempFileCalls++;
    if (downloadToTemp != null) {
      return downloadToTemp!(backup);
    }
    throw UnimplementedError('downloadToTemp not configured');
  }

  @override
  Future<RestorePrecheck> precheckRestore(File backupFile) async {
    precheckRestoreCalls++;
    if (precheckRestoreError != null) {
      throw precheckRestoreError!;
    }
    return precheckRestoreResult ??
        const RestorePrecheck(
          preview: BackupRecoveryPreview(hasRecovery: false),
          localHasTrustedDevice: false,
          willOverwriteLocalVault: true,
        );
  }
}

class _UnusedDriveBackupService implements DriveBackupService {
  @override
  Future<DriveConnectionState> connect() => throw UnimplementedError();

  @override
  Future<DriveConnectionState> getConnectionState() =>
      throw UnimplementedError();

  @override
  Future<File> downloadBackupById({
    required String fileId,
    required String fileName,
    required Directory destinationDirectory,
    int? totalBytes,
    BackupTaskProgressListener? onProgress,
  }) => throw UnimplementedError();

  @override
  Future<List<DriveBackupFile>> listBackups() => throw UnimplementedError();

  @override
  Future<void> deleteBackup(String fileId) => throw UnimplementedError();

  @override
  Future<List<DriveBackupFile>> pruneBackups({required int retainCount}) =>
      throw UnimplementedError();

  @override
  Future<DriveConnectionState> switchAccount() => throw UnimplementedError();

  @override
  Future<void> disconnect() => throw UnimplementedError();

  @override
  Future<String> uploadBackup(
    File backupFile, {
    BackupTaskProgressListener? onProgress,
  }) => throw UnimplementedError();
}
