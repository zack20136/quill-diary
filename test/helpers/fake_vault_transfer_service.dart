import 'dart:io';

import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/storage/external_directory_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_service.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';

import 'fake_vault_repository.dart';
import 'test_vault_path_strategy.dart';

class FakeVaultTransferService extends VaultTransferService {
  FakeVaultTransferService({
    DriveConnectionState? connectionState,
    this.connectionStates,
  }) : super(
          archiveIo: VaultArchiveIo(
            pathStrategy: DummyVaultPathStrategy(),
            repository: FakeVaultRepository(),
            frontMatterCodec: const FrontMatterCodec(),
            indexDatabaseManager: IndexDatabaseManager(DummyVaultPathStrategy()),
          ),
          driveBackupService: _UnusedDriveBackupService(),
          vaultRepository: FakeVaultRepository(),
          externalDirectoryStore: ExternalDirectoryStore(DummyVaultPathStrategy()),
          pathStrategy: DummyVaultPathStrategy(),
        ) {
    _connectionState = connectionState ?? const DriveConnectionState.disconnected();
  }

  late DriveConnectionState _connectionState;
  final List<DriveConnectionState>? connectionStates;
  int isConnectedCalls = 0;
  int connectCalls = 0;
  int reconnectCalls = 0;
  int saveBackupToAppLocalCalls = 0;
  int listAppLocalBackupsCalls = 0;
  int saveBackupToExternalDirectoryCalls = 0;
  int uploadBackupToDriveCalls = 0;

  @override
  Future<BackupPersistResult> saveBackupToAppLocal() {
    saveBackupToAppLocalCalls++;
    throw UnimplementedError();
  }

  @override
  Future<List<LocalBackupFile>> listAppLocalBackups() async {
    listAppLocalBackupsCalls++;
    return const <LocalBackupFile>[];
  }

  @override
  Future<BackupPersistResult> saveBackupToExternalDirectory() {
    saveBackupToExternalDirectoryCalls++;
    throw UnimplementedError();
  }

  @override
  Future<BackupPersistResult> uploadBackupToDrive() {
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
  Future<DriveConnectionState> connectGoogleDrive({bool reconnect = false}) async {
    if (reconnect) {
      reconnectCalls++;
      return _connectionState;
    }
    connectCalls++;
    return _connectionState;
  }
}

class _UnusedDriveBackupService implements DriveBackupService {
  @override
  Future<DriveConnectionState> connect() => throw UnimplementedError();

  @override
  Future<DriveConnectionState> getConnectionState() => throw UnimplementedError();

  @override
  Future<File> downloadBackupById({
    required String fileId,
    required String fileName,
    required Directory destinationDirectory,
  }) => throw UnimplementedError();

  @override
  Future<List<DriveBackupFile>> listBackups() => throw UnimplementedError();

  @override
  Future<void> deleteBackup(String fileId) => throw UnimplementedError();

  @override
  Future<List<DriveBackupFile>> pruneBackups({required int retainCount}) =>
      throw UnimplementedError();

  @override
  Future<DriveConnectionState> reconnect() => throw UnimplementedError();

  @override
  Future<String> uploadBackup(File backupFile) => throw UnimplementedError();
}
