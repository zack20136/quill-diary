import 'dart:io';

import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';

/// 測試用未實作的 DriveBackupService。
class UnusedDriveBackupService implements DriveBackupService {
  const UnusedDriveBackupService();

  @override
  Future<DriveConnectionState> connect() => throw UnimplementedError();

  @override
  Future<void> deleteBackup(String fileId, {bool interactive = true}) =>
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
  Future<DriveConnectionState> getConnectionState() =>
      throw UnimplementedError();

  @override
  Future<List<DriveBackupFile>> listBackups({bool interactive = true}) =>
      throw UnimplementedError();

  @override
  Future<List<DriveBackupFile>> pruneBackups({
    required int retainCount,
    String? keepFileId,
    bool interactive = true,
  }) => throw UnimplementedError();

  @override
  Future<DriveConnectionState> switchAccount() => throw UnimplementedError();

  @override
  Future<void> disconnect() => throw UnimplementedError();
}
