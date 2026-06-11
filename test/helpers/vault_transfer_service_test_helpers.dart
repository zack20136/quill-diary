import 'dart:io';

import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_service.dart';

/// 備份檢查固定失敗的 VaultTransferService 測試替身。
class InspectFailingTransferService extends VaultTransferService {
  InspectFailingTransferService({
    required super.archiveIo,
    required super.vaultRepository,
    required super.externalDirectoryStore,
    required super.pathStrategy,
  }) : super(driveBackupService: const UnusedDriveBackupService());

  @override
  Future<BackupInspectResult> inspectBackup(File backupFile) async {
    return const BackupInspectResult(
      ok: false,
      message: '測試用備份檢查失敗',
      layout: VaultBackupLayout.empty,
    );
  }
}

/// 測試用未實作的 DriveBackupService。
class UnusedDriveBackupService implements DriveBackupService {
  const UnusedDriveBackupService();

  @override
  Future<DriveConnectionState> connect() => throw UnimplementedError();

  @override
  Future<void> deleteBackup(String fileId) => throw UnimplementedError();

  @override
  Future<File> downloadBackupById({
    required String fileId,
    required String fileName,
    required Directory destinationDirectory,
  }) =>
      throw UnimplementedError();

  @override
  Future<DriveConnectionState> getConnectionState() => throw UnimplementedError();

  @override
  Future<List<DriveBackupFile>> listBackups() => throw UnimplementedError();

  @override
  Future<List<DriveBackupFile>> pruneBackups({required int retainCount}) =>
      throw UnimplementedError();

  @override
  Future<DriveConnectionState> switchAccount() => throw UnimplementedError();

  @override
  Future<void> disconnect() => throw UnimplementedError();

  @override
  Future<String> uploadBackup(File backupFile) => throw UnimplementedError();
}
