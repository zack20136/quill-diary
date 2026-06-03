import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_lock_diary/domain/diary/diary_entry.dart';
import 'package:quill_lock_diary/domain/shared/value_objects.dart';
import 'package:quill_lock_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_lock_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_lock_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_lock_diary/infrastructure/storage/export_save_location_store.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_transfer_service.dart';

import '../helpers/vault_test_harness.dart';

void main() {
  late VaultTestHarness harness;
  late VaultTransferService transferService;

  setUp(() async {
    harness = await VaultTestHarness.create();
    final archiveIo = VaultArchiveIo(
      pathStrategy: harness.pathStrategy,
      repository: harness.repository,
      frontMatterCodec: const FrontMatterCodec(),
      indexDatabaseManager: IndexDatabaseManager(harness.pathStrategy),
    );
    transferService = VaultTransferService(
      archiveIo: archiveIo,
      driveBackupService: const _UnusedDriveBackupService(),
      vaultRepository: harness.repository,
      exportSaveLocationStore: ExportSaveLocationStore(harness.pathStrategy),
      pathStrategy: harness.pathStrategy,
    );
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('createAppLocalBackup writes a healthy backup under app backups directory', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'Local Backup',
        date: const DateOnly('2026-06-03'),
        createdAt: DateTime.parse('2026-06-03T08:00:00Z'),
        updatedAt: DateTime.parse('2026-06-03T08:00:00Z'),
        markdownBody: 'local backup body',
      ),
    );

    final BackupCreationResult result = await transferService.createAppLocalBackup();
    final Directory backupsDirectory = await harness.pathStrategy.localBackupsDirectory();

    expect(result.healthReport.ok, isTrue);
    expect(p.isWithin(backupsDirectory.path, result.path), isTrue);
    expect(File(result.path).existsSync(), isTrue);
  });

  test('listAppLocalBackups sorts newest first and deleteAppLocalBackup removes the file', () async {
    final Directory backupsDirectory = await harness.pathStrategy.localBackupsDirectory();
    await backupsDirectory.create(recursive: true);
    final File older = File(p.join(backupsDirectory.path, 'backup_older.jbackup'))
      ..writeAsBytesSync(const <int>[1]);
    final File newer = File(p.join(backupsDirectory.path, 'backup_newer.jbackup'))
      ..writeAsBytesSync(const <int>[2]);
    await older.setLastModified(DateTime.parse('2026-06-01T00:00:00Z'));
    await newer.setLastModified(DateTime.parse('2026-06-02T00:00:00Z'));

    final List<LocalBackupFile> backups = await transferService.listAppLocalBackups();

    expect(backups.map((LocalBackupFile backup) => backup.name), <String>[
      'backup_newer.jbackup',
      'backup_older.jbackup',
    ]);

    await transferService.deleteAppLocalBackup(backups.first);

    expect(newer.existsSync(), isFalse);
    expect(older.existsSync(), isTrue);
  });
}

class _UnusedDriveBackupService implements DriveBackupService {
  const _UnusedDriveBackupService();

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
  Future<DriveConnectionState> reconnect() => throw UnimplementedError();

  @override
  Future<String> uploadBackup(File backupFile) => throw UnimplementedError();
}
