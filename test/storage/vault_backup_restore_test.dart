import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/features/editor/application/editor_draft_models.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';

import '../helpers/vault/vault_test_harness.dart';

void main() {
  late VaultTestHarness harness;
  late VaultArchiveIo archiveIo;

  setUp(() async {
    harness = await VaultTestHarness.create();
    archiveIo = harness.createArchiveIo();
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('peekBackupRecovery 可讀取備份內 recovery.json', () async {
    final setup = await harness.repository.setupRecoveryKey();
    await harness.saveSimpleEntry(
      setup,
      title: 'Backup Entry',
      date: '2026-05-24',
      markdownBody: 'backup body',
    );

    final File backupFile = File(p.join(harness.tempDir.path, 'test.zip'));
    await archiveIo.writeBackupZip(backupFile);

    final BackupRecoveryPreview preview = await archiveIo.peekBackupRecovery(
      backupFile,
    );
    expect(preview.metadata?.vaultId, setup.session.vaultId);
    expect(preview.metadata?.recoveryKeyHint, isNotEmpty);
  });

  test('inspectBackup 可接受可讀取的 vault 備份', () async {
    final setup = await harness.repository.setupRecoveryKey();
    await harness.saveSimpleEntry(
      setup,
      title: 'Healthy Backup',
      date: '2026-05-30',
      markdownBody: 'healthy backup body',
    );

    final File backupFile = File(p.join(harness.tempDir.path, 'healthy.zip'));
    await archiveIo.writeBackupZip(backupFile);

    final BackupInspectResult report = await archiveIo.inspectBackup(
      backupFile,
    );

    expect(report.ok, isTrue);
    expect(report.layout.hasRecovery, isTrue);
  });

  test('inspectBackup 會拒絕無效的 zip', () async {
    final File backupFile = File(p.join(harness.tempDir.path, 'invalid.zip'))
      ..writeAsBytesSync(const <int>[1, 2, 3, 4]);

    final BackupInspectResult report = await archiveIo.inspectBackup(
      backupFile,
    );

    expect(report.ok, isFalse);
    expect(report.message, contains('zip 備份'));
  });

  test('inspectBackup 會拒絕可攜式 markdown 匯出 zip', () async {
    final setup = await harness.repository.setupRecoveryKey();
    await harness.saveSimpleEntry(
      setup,
      title: 'Export Entry',
      date: '2026-06-01',
      markdownBody: 'export body',
    );

    final File exportZip = File(
      p.join(harness.tempDir.path, 'markdown_2026-05-26_14-03-07.zip'),
    );
    await archiveIo.writeMarkdownZip(session: setup.session, target: exportZip);

    final BackupInspectResult report = await archiveIo.inspectBackup(exportZip);

    expect(report.ok, isFalse);
    expect(report.message, contains('日記匯出檔'));
  });

  test('inspectBackup 會拒絕損壞的 recovery.json', () async {
    final File backupFile = File(
      p.join(harness.tempDir.path, 'bad_recovery.zip'),
    );
    final Archive archive = Archive()
      ..addFile(ArchiveFile.string('recovery.json', 'not-json'))
      ..addFile(ArchiveFile.string('manifest.json.enc', 'enc'))
      ..addFile(ArchiveFile.string('entries/a.md.enc', 'body'));
    await backupFile.writeAsBytes(ZipEncoder().encode(archive));

    final BackupInspectResult report = await archiveIo.inspectBackup(
      backupFile,
    );

    expect(report.ok, isFalse);
    expect(report.message, contains('recovery.json'));
  });

  test('inspectBackup 會拒絕缺少 recovery.json 的 zip', () async {
    final File backupFile = File(
      p.join(harness.tempDir.path, 'no_recovery.zip'),
    );
    final Archive archive = Archive()
      ..addFile(ArchiveFile.string('manifest.json.enc', 'enc'))
      ..addFile(ArchiveFile.string('entries/a.md.enc', 'body'));
    await backupFile.writeAsBytes(ZipEncoder().encode(archive));

    final BackupInspectResult report = await archiveIo.inspectBackup(
      backupFile,
    );

    expect(report.ok, isFalse);
    expect(report.layout.hasRecovery, isFalse);
    expect(report.message, contains('缺少復原金鑰資訊'));
  });

  test('restoreBackupZip 會在覆寫前拒絕缺少加密資料的備份', () async {
    final setup = await harness.repository.setupRecoveryKey();
    final RecoveryMetadata metadata =
        await harness.repository.readRecoveryMetadata() ??
        (throw StateError('測試前置失敗：缺少 recovery metadata。'));
    await harness.saveSimpleEntry(
      setup,
      title: 'Keep Me',
      date: '2026-05-31',
      markdownBody: 'keep',
    );

    final File incompleteBackup = File(
      p.join(harness.tempDir.path, 'incomplete.zip'),
    );
    final Archive archive = Archive()
      ..addFile(
        ArchiveFile.string('recovery.json', jsonEncode(metadata.toJson())),
      );
    await incompleteBackup.writeAsBytes(ZipEncoder().encode(archive));

    expect(
      () => archiveIo.restoreBackupZip(incompleteBackup),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          contains('缺少加密資料'),
        ),
      ),
    );

    final List<EntryIndexRecord> entries = await harness.repository
        .listEntries();
    expect(entries, hasLength(1));
  });

  test('restoreBackupZip 可還原日記並保留 recovery metadata', () async {
    final setup = await harness.repository.setupRecoveryKey();
    final String entryId = await harness.saveSimpleEntry(
      setup,
      title: 'Restore Me',
      date: '2026-05-25',
      markdownBody: 'restore body',
      createdAt: DateTime.parse('2026-05-25T11:00:00Z'),
      updatedAt: DateTime.parse('2026-05-25T11:00:00Z'),
    );

    final File backupFile = File(p.join(harness.tempDir.path, 'restore.zip'));
    await archiveIo.writeBackupZip(backupFile);

    await harness.repository.saveEntry(
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

    await harness.repository.closeUnlockedResources();
    await archiveIo.restoreBackupZip(backupFile);

    final RecoveryMetadata? metadataAfterRestore = await harness.repository
        .readRecoveryMetadata();
    expect(metadataAfterRestore?.vaultId, setup.session.vaultId);

    final UnlockedVaultSession session = await harness.repository
        .unlockWithRecoveryKey(setup.recoveryKey);
    final List<EntryIndexRecord> entries = await harness.repository
        .listEntries();
    expect(entries, hasLength(1));
    final DiaryEntry? restored = await harness.repository.loadEntry(
      session,
      entryId,
    );
    expect(restored?.title, 'Restore Me');
  });

  test('restoreBackupZip 會清除所有本地草稿', () async {
    final setup = await harness.repository.setupRecoveryKey();
    await harness.saveSimpleEntry(
      setup,
      title: 'Restore Me',
      date: '2026-05-25',
      markdownBody: 'restore body',
    );

    final EditorDraftStore draftStore = EditorDraftStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: LocalCryptoService(),
    );
    await draftStore.write(
      '__new__',
      EditorDraftRecord(
        title: '未儲存草稿',
        dateValue: '2026-05-25',
        entryHour: 10,
        entryMinute: 0,
        tags: const <String>['草稿標籤'],
        markdownBody: 'draft body',
        keptAttachmentIds: const <String>[],
        pendingAttachments: const <EditorDraftPendingAttachment>[],
        provisionalEntryId: generateEntryId(),
        createdAt: DateTime.parse('2026-05-25T10:00:00Z'),
        updatedAt: DateTime.parse('2026-05-25T10:00:00Z'),
      ),
      setup.session,
    );
    expect(await draftStore.listDraftKeys(), isNotEmpty);

    final File backupFile = File(
      p.join(harness.tempDir.path, 'draft_clear.zip'),
    );
    await archiveIo.writeBackupZip(backupFile);

    await harness.repository.closeUnlockedResources();
    await archiveIo.restoreBackupZip(backupFile);

    expect(await draftStore.listDraftKeys(), isEmpty);
  });

  test('損壞的備份 zip 不應清空現有 vault', () async {
    final setup = await harness.repository.setupRecoveryKey();
    await harness.saveSimpleEntry(
      setup,
      title: 'Keep Me',
      date: '2026-05-27',
      markdownBody: 'keep',
    );

    final File badBackup = File(p.join(harness.tempDir.path, 'bad.zip'))
      ..writeAsBytesSync(const <int>[1, 2, 3, 4]);

    expect(
      () => archiveIo.restoreBackupZip(badBackup),
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

    final List<EntryIndexRecord> entries = await harness.repository
        .listEntries();
    expect(entries, hasLength(1));
  });
}
