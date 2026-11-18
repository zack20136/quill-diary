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
