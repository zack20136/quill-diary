import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/storage/external_directory_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/domain/shared/vault_backup_policy.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_service.dart';

import '../helpers/path_provider_test_binding.dart';
import '../helpers/vault_test_harness.dart';
import '../helpers/vault_transfer_service_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VaultTestHarness harness;
  late VaultTransferService transferService;

  setUp(() async {
    harness = await VaultTestHarness.create();
    installPathProviderTestBinding(harness.tempDir);
    final archiveIo = VaultArchiveIo(
      pathStrategy: harness.pathStrategy,
      repository: harness.repository,
      frontMatterCodec: const FrontMatterCodec(),
      indexDatabaseManager: IndexDatabaseManager(harness.pathStrategy),
    );
    transferService = VaultTransferService(
      archiveIo: archiveIo,
      driveBackupService: const UnusedDriveBackupService(),
      vaultRepository: harness.repository,
      externalDirectoryStore: ExternalDirectoryStore(harness.pathStrategy),
      pathStrategy: harness.pathStrategy,
    );
  });

  tearDown(() async {
    clearPathProviderTestBinding();
    await harness.dispose();
  });

  test('saveBackupToAppLocal writes a healthy backup under app backups directory', () async {
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

    final BackupPersistResult result = await transferService.saveBackupToAppLocal();
    final Directory backupsDirectory = await harness.pathStrategy.localBackupsDirectory();

    expect(result.status, BackupPersistStatus.success);
    expect(result.savedPath, isNotNull);
    expect(p.isWithin(backupsDirectory.path, result.savedPath!), isTrue);
    expect(File(result.savedPath!).existsSync(), isTrue);
  });

  test('saveBackupToAppLocal does not persist when inspect fails', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'Inspect Fail Backup',
        date: const DateOnly('2026-06-03'),
        createdAt: DateTime.parse('2026-06-03T08:00:00Z'),
        updatedAt: DateTime.parse('2026-06-03T08:00:00Z'),
        markdownBody: 'inspect fail body',
      ),
    );

    final Directory backupsDirectory = await harness.pathStrategy.localBackupsDirectory();
    await backupsDirectory.create(recursive: true);
    final int beforeCount = backupsDirectory.listSync().whereType<File>().length;

    final InspectFailingTransferService failingService = InspectFailingTransferService(
      archiveIo: VaultArchiveIo(
        pathStrategy: harness.pathStrategy,
        repository: harness.repository,
        frontMatterCodec: const FrontMatterCodec(),
        indexDatabaseManager: IndexDatabaseManager(harness.pathStrategy),
      ),
      vaultRepository: harness.repository,
      externalDirectoryStore: ExternalDirectoryStore(harness.pathStrategy),
      pathStrategy: harness.pathStrategy,
    );

    final BackupPersistResult result = await failingService.saveBackupToAppLocal();
    final int afterCount = backupsDirectory.listSync().whereType<File>().length;

    expect(result.status, BackupPersistStatus.inspectFailed);
    expect(result.savedPath, isNull);
    expect(afterCount, beforeCount);
  });

  test('listAppLocalBackups sorts newest first and deleteAppLocalBackup removes the file', () async {
    final Directory backupsDirectory = await harness.pathStrategy.localBackupsDirectory();
    await backupsDirectory.create(recursive: true);
    final File older = File(p.join(backupsDirectory.path, 'backup_older.zip'))
      ..writeAsBytesSync(const <int>[1]);
    final File newer = File(p.join(backupsDirectory.path, 'backup_newer.zip'))
      ..writeAsBytesSync(const <int>[2]);
    await older.setLastModified(DateTime.parse('2026-06-01T00:00:00Z'));
    await newer.setLastModified(DateTime.parse('2026-06-02T00:00:00Z'));

    final List<LocalBackupFile> backups = await transferService.listAppLocalBackups();

    expect(backups.map((LocalBackupFile backup) => backup.name), <String>[
      'backup_newer.zip',
      'backup_older.zip',
    ]);

    await transferService.deleteAppLocalBackup(backups.first);

    expect(newer.existsSync(), isFalse);
    expect(older.existsSync(), isTrue);
  });

  test('listAppLocalBackups includes zip files without backup_ prefix', () async {
    final Directory backupsDirectory = await harness.pathStrategy.localBackupsDirectory();
    await backupsDirectory.create(recursive: true);
    File(p.join(backupsDirectory.path, 'my_diary_backup.zip'))
        .writeAsBytesSync(const <int>[1]);

    final List<LocalBackupFile> backups = await transferService.listAppLocalBackups();

    expect(
      backups.map((LocalBackupFile backup) => backup.name),
      contains('my_diary_backup.zip'),
    );
  });

  test('listAppLocalBackups keeps only the newest five backups', () async {
    final Directory backupsDirectory = await harness.pathStrategy.localBackupsDirectory();
    await backupsDirectory.create(recursive: true);
    for (int index = 0; index < 6; index++) {
      final File backup = File(p.join(backupsDirectory.path, 'backup_$index.zip'))
        ..writeAsBytesSync(<int>[index]);
      await backup.setLastModified(
        DateTime.parse('2026-06-0${index + 1}T00:00:00Z'),
      );
    }

    final List<LocalBackupFile> backups = await transferService.listAppLocalBackups();

    expect(backups, hasLength(VaultBackupPolicy.retainCount));
    expect(
      backups.map((LocalBackupFile backup) => backup.name),
      <String>[
        'backup_5.zip',
        'backup_4.zip',
        'backup_3.zip',
        'backup_2.zip',
        'backup_1.zip',
      ],
    );
    expect(File(p.join(backupsDirectory.path, 'backup_0.zip')).existsSync(), isFalse);
  });
}
