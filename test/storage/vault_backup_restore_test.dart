import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';

import '../helpers/vault_archive_io_test_harness.dart';

void main() {
  late VaultArchiveIoTestHarness harness;

  setUp(() async {
    harness = await VaultArchiveIoTestHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('peekBackupRecovery 可讀取備份內 recovery.json', () async {
    final setup = await harness.harness.setupRecoveryKey();
    await harness.harness.saveSimpleEntry(
      setup,
      title: 'Backup Entry',
      date: '2026-05-24',
      markdownBody: 'backup body',
    );

    final File backupFile = File(p.join(harness.tempDir.path, 'test.zip'));
    await harness.archiveIo.writeBackupZip(backupFile);

    final BackupRecoveryPreview preview = await harness.archiveIo.peekBackupRecovery(backupFile);
    expect(preview.hasRecovery, isTrue);
    expect(preview.metadata?.vaultId, setup.session.vaultId);
    expect(preview.metadata?.recoveryKeyHint, isNotEmpty);
  });

  test('inspectBackup accepts a readable vault backup', () async {
    final setup = await harness.harness.setupRecoveryKey();
    await harness.harness.saveSimpleEntry(
      setup,
      title: 'Healthy Backup',
      date: '2026-05-30',
      markdownBody: 'healthy backup body',
    );

    final File backupFile = File(p.join(harness.tempDir.path, 'healthy.zip'));
    await harness.archiveIo.writeBackupZip(backupFile);

    final BackupInspectResult report = await harness.archiveIo.inspectBackup(backupFile);

    expect(report.ok, isTrue);
    expect(report.layout.hasRecovery, isTrue);
    expect(report.layout.hasManifest || report.layout.entrySampleFound, isTrue);
  });

  test('inspectBackup rejects an invalid zip', () async {
    final File backupFile = File(p.join(harness.tempDir.path, 'invalid.zip'))
      ..writeAsBytesSync(const <int>[1, 2, 3, 4]);

    final BackupInspectResult report = await harness.archiveIo.inspectBackup(backupFile);

    expect(report.ok, isFalse);
    expect(report.message, contains('zip 備份'));
  });

  test('inspectBackup rejects portable markdown export zip', () async {
    final setup = await harness.harness.setupRecoveryKey();
    await harness.harness.saveSimpleEntry(
      setup,
      title: 'Export Entry',
      date: '2026-06-01',
      markdownBody: 'export body',
    );

    final File exportZip = File(
      p.join(harness.tempDir.path, 'markdown_2026-05-26_14-03-07.zip'),
    );
    await harness.archiveIo.writeMarkdownZip(
      session: setup.session,
      target: exportZip,
    );

    final BackupInspectResult report = await harness.archiveIo.inspectBackup(exportZip);

    expect(report.ok, isFalse);
    expect(report.message, contains('日記匯出檔'));
  });

  test('inspectBackup rejects corrupted recovery.json', () async {
    final File backupFile = File(p.join(harness.tempDir.path, 'bad_recovery.zip'));
    final Archive archive = Archive()
      ..addFile(ArchiveFile.string('recovery.json', 'not-json'))
      ..addFile(ArchiveFile.string('manifest.json.enc', 'enc'))
      ..addFile(ArchiveFile.string('entries/a.md.enc', 'body'));
    await backupFile.writeAsBytes(ZipEncoder().encode(archive));

    final BackupInspectResult report = await harness.archiveIo.inspectBackup(backupFile);

    expect(report.ok, isFalse);
    expect(report.message, contains('recovery.json'));
  });

  test('restoreBackupZip 會在覆寫前拒絕缺少加密資料的備份', () async {
    final setup = await harness.harness.setupRecoveryKey();
    final RecoveryMetadata metadata =
        await harness.harness.repository.readRecoveryMetadata() ??
            (throw StateError('測試前置失敗：缺少 recovery metadata。'));
    await harness.harness.saveSimpleEntry(
      setup,
      title: 'Keep Me',
      date: '2026-05-31',
      markdownBody: 'keep',
    );

    final File incompleteBackup = File(p.join(harness.tempDir.path, 'incomplete.zip'));
    final Archive archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'recovery.json',
          jsonEncode(metadata.toJson()),
        ),
      );
    await incompleteBackup.writeAsBytes(ZipEncoder().encode(archive));

    expect(
      () => harness.archiveIo.restoreBackupZip(incompleteBackup),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          contains('缺少加密資料'),
        ),
      ),
    );

    final List<EntryIndexRecord> entries = await harness.harness.repository.listEntries();
    expect(entries, hasLength(1));
  });

  test('restoreBackupZip 可還原日記並保留 recovery metadata', () async {
    final setup = await harness.harness.setupRecoveryKey();
    final String entryId = await harness.harness.saveSimpleEntry(
      setup,
      title: 'Restore Me',
      date: '2026-05-25',
      markdownBody: 'restore body',
      createdAt: DateTime.parse('2026-05-25T11:00:00Z'),
      updatedAt: DateTime.parse('2026-05-25T11:00:00Z'),
    );

    final File backupFile = File(p.join(harness.tempDir.path, 'restore.zip'));
    await harness.archiveIo.writeBackupZip(backupFile);

    await harness.harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        title: 'After Backup Noise',
        date: const DateOnly('2026-05-26'),
        createdAt: DateTime.parse('2026-05-26T12:00:00Z'),
        updatedAt: DateTime.parse('2026-05-26T12:00:00Z'),
        markdownBody: 'noise',
      ),
    );

    await harness.harness.repository.closeUnlockedResources();
    await harness.archiveIo.restoreBackupZip(backupFile);

    final RecoveryMetadata? metadataAfterRestore =
        await harness.harness.repository.readRecoveryMetadata();
    expect(metadataAfterRestore?.vaultId, setup.session.vaultId);

    final UnlockedVaultSession session =
        await harness.harness.repository.unlockWithRecoveryKey(setup.recoveryKey);
    await harness.harness.repository.rebuildIndex(session);
    final List<EntryIndexRecord> entries = await harness.harness.repository.listEntries();
    expect(entries, hasLength(1));
    final DiaryEntry? restored = await harness.harness.repository.loadEntry(session, entryId);
    expect(restored?.title, 'Restore Me');
  });

  test('損壞的備份 zip 不應清空現有 vault', () async {
    final setup = await harness.harness.setupRecoveryKey();
    await harness.harness.saveSimpleEntry(
      setup,
      title: 'Keep Me',
      date: '2026-05-27',
      markdownBody: 'keep',
    );

    final File badBackup = File(p.join(harness.tempDir.path, 'bad.zip'))
      ..writeAsBytesSync(const <int>[1, 2, 3, 4]);

    expect(
      () => harness.archiveIo.restoreBackupZip(badBackup),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          anyOf(
            contains('無法讀取備份檔'),
            contains('備份檔內容不完整'),
            contains('缺少復原金鑰資訊'),
            contains('缺少加密資料'),
          ),
        ),
      ),
    );

    final List<EntryIndexRecord> entries = await harness.harness.repository.listEntries();
    expect(entries, hasLength(1));
  });
}
