import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../helpers/vault_test_harness.dart';

void main() {
  late VaultTestHarness harness;
  late VaultArchiveIo archiveIo;

  setUp(() async {
    harness = await VaultTestHarness.create();
    archiveIo = VaultArchiveIo(
      pathStrategy: harness.pathStrategy,
      repository: harness.repository,
      frontMatterCodec: const FrontMatterCodec(),
      indexDatabaseManager: IndexDatabaseManager(harness.pathStrategy),
    );
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('正確復原金鑰可通過驗證', () async {
    final RecoverySetupResult setup = await harness.setupRecoveryKey();
    await harness.saveSimpleEntry(setup, title: 'Verify Entry');
    final File backupFile = File(p.join(harness.tempDir.path, 'valid.zip'));
    await archiveIo.writeBackupZip(backupFile);

    await expectLater(
      archiveIo.verifyBackupRecoveryKey(backupFile, setup.recoveryKey),
      completes,
    );
  });

  test('錯誤復原金鑰拋出 mismatch', () async {
    final RecoverySetupResult setup = await harness.setupRecoveryKey();
    await harness.saveSimpleEntry(setup, title: 'Verify Entry');
    final File backupFile = File(p.join(harness.tempDir.path, 'valid.zip'));
    await archiveIo.writeBackupZip(backupFile);

    await expectLater(
      archiveIo.verifyBackupRecoveryKey(backupFile, 'WRONG-KEY-XXXX'),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          kBackupRecoveryKeyMismatchMessage,
        ),
      ),
    );
  });

  test('無 recovery metadata 的備份無法驗證', () async {
    final File backupFile = File(p.join(harness.tempDir.path, 'no_recovery.zip'));
    final Archive archive = Archive()
      ..addFile(ArchiveFile('manifest.json.enc', 4, const <int>[1, 2, 3, 4]));
    await backupFile.writeAsBytes(ZipEncoder().encode(archive));

    await expectLater(
      archiveIo.verifyBackupRecoveryKey(backupFile, 'ANY-KEY'),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          '此備份沒有復原金鑰資訊，無法驗證。',
        ),
      ),
    );
  });

  test('無加密樣本的備份無法驗證復原金鑰', () async {
    final RecoverySetupResult setup = await harness.setupRecoveryKey();
    final File backupFile = File(p.join(harness.tempDir.path, 'no_sample.zip'));
    final RecoveryMetadata metadata =
        await harness.repository.readRecoveryMetadata() ??
            (throw StateError('測試前置失敗：缺少 recovery metadata。'));
    final Archive archive = Archive()
      ..addFile(
        ArchiveFile.string('recovery.json', jsonEncode(metadata.toJson())),
      );
    await backupFile.writeAsBytes(ZipEncoder().encode(archive));

    await expectLater(
      archiveIo.verifyBackupRecoveryKey(backupFile, setup.recoveryKey),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          kBackupNoEncryptedSampleMessage,
        ),
      ),
    );
  });
}
