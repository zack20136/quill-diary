import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/transfer/vault_backup_service.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/external_directory_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_models.dart';

import '../../helpers/vault/vault_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('檢視超額備份不刪檔，交付成功後才保留新檔與最新四份', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    await harness.repository.setupRecoveryKey();
    final backups = VaultBackupService(
      backupIo: harness.createTransferIo().backup,
      driveBackupService: GoogleDriveBackupService(),
      externalDirectoryStore: ExternalDirectoryStore(harness.pathStrategy),
      pathStrategy: harness.pathStrategy,
    );
    final directory = await harness.pathStrategy.localBackupsDirectory();
    await directory.create(recursive: true);
    final names = List.generate(6, (index) => 'older_$index.zip');
    final now = DateTime.now();
    for (final (index, name) in names.indexed) {
      final file = await File('${directory.path}/$name').writeAsBytes([index]);
      await file.setLastModified(now.add(Duration(days: index + 1)));
    }

    expect(await backups.listAppLocalBackups(), hasLength(names.length));
    expect(await directory.list().length, names.length);

    final result = await backups.saveBackupToAppLocal();
    expect(result.status, BackupPersistStatus.success);
    final retained = await backups.listAppLocalBackups();
    final saved = retained.singleWhere((file) => file.path == result.savedPath);
    expect(
      retained.map((file) => file.name),
      unorderedEquals([saved.name, ...names.skip(2)]),
    );
  });

  test('本機備份同名時保留舊備份，複製中斷也不發布半成品', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    await harness.saveSimpleEntry(setup);
    final backups = VaultBackupService(
      backupIo: harness.createTransferIo().backup,
      driveBackupService: GoogleDriveBackupService(),
      externalDirectoryStore: ExternalDirectoryStore(harness.pathStrategy),
      pathStrategy: harness.pathStrategy,
    );
    const fileName = 'backup_same_time.zip';
    final first = await backups.saveBackupToAppLocal(fileName: fileName);
    expect(first.status, BackupPersistStatus.success);
    final original = File(first.savedPath!);
    final originalBytes = await original.readAsBytes();
    final interrupted = StateError('測試本機備份中斷');

    await expectLater(
      backups.saveBackupToAppLocal(
        fileName: fileName,
        onProgress: (progress) {
          if (progress.phase == BackupTaskPhase.copyingBackup &&
              progress.fraction! > backupPipelineZipEndFraction) {
            throw interrupted;
          }
        },
      ),
      throwsA(same(interrupted)),
    );
    expect(original.parent.listSync().map((file) => file.path), [
      original.path,
    ]);

    final second = await backups.saveBackupToAppLocal(fileName: fileName);
    expect(second.status, BackupPersistStatus.success);
    expect(second.savedPath, isNot(original.path));
    expect((await backups.inspectBackup(File(second.savedPath!))).ok, isTrue);
    expect(await original.readAsBytes(), originalBytes);
  });
}
