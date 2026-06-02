import 'dart:io';

import 'package:quill_lock_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_lock_diary/infrastructure/storage/export_save_location_store.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_transfer_service.dart';
import 'package:quill_lock_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_lock_diary/infrastructure/markdown/front_matter_codec.dart';

import 'fake_vault_repository.dart';
import 'test_vault_path_strategy.dart';

class FakeVaultTransferService extends VaultTransferService {
  FakeVaultTransferService({
    this.isConnectedResult = false,
    this.isConnectedValues,
  }) : super(
          archiveIo: VaultArchiveIo(
            pathStrategy: DummyVaultPathStrategy(),
            repository: FakeVaultRepository(),
            frontMatterCodec: const FrontMatterCodec(),
            indexDatabaseManager: IndexDatabaseManager(DummyVaultPathStrategy()),
          ),
          driveBackupService: _UnusedDriveBackupService(),
          vaultRepository: FakeVaultRepository(),
          exportSaveLocationStore: ExportSaveLocationStore(DummyVaultPathStrategy()),
        );

  bool isConnectedResult;
  final List<bool>? isConnectedValues;
  int isConnectedCalls = 0;
  int connectCalls = 0;
  int reconnectCalls = 0;

  @override
  Future<bool> isGoogleDriveConnected() async {
    final int callIndex = isConnectedCalls++;
    final List<bool>? values = isConnectedValues;
    if (values != null && callIndex < values.length) {
      return values[callIndex];
    }
    return isConnectedResult;
  }

  @override
  Future<void> connectGoogleDrive({bool reconnect = false}) async {
    if (reconnect) {
      reconnectCalls++;
    } else {
      connectCalls++;
    }
  }
}

class _UnusedDriveBackupService implements DriveBackupService {
  @override
  Future<void> connect() => throw UnimplementedError();

  @override
  Future<File> downloadBackupById({
    required String fileId,
    required String fileName,
    required Directory destinationDirectory,
  }) => throw UnimplementedError();

  @override
  Future<bool> isConnected() => throw UnimplementedError();

  @override
  Future<List<DriveBackupFile>> listBackups() => throw UnimplementedError();

  @override
  Future<void> reconnect() => throw UnimplementedError();

  @override
  Future<String> uploadBackup(File backupFile) => throw UnimplementedError();
}
