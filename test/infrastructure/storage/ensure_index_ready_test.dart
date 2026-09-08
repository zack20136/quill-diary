import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../../helpers/vault/vault_test_harness.dart';

void main() {
  late VaultTestHarness harness;

  setUp(() async {
    harness = await VaultTestHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('ensureIndexReady 不因缺少 last_rebuild_at 而全量重建', () async {
    final setup = await harness.repository.setupRecoveryKey();
    await harness.saveSimpleEntry(
      setup,
      title: 'Indexed Entry',
      date: '2026-06-10',
      markdownBody: 'keep in index',
    );

    expect(await harness.repository.listEntries(), hasLength(1));

    await harness.repository.closeUnlockedResources();
    await harness.repository.ensureIndexReady(setup.session);

    expect(await harness.repository.listEntries(), hasLength(1));
  });

  test('ensureIndexReady 在 schema 不符時從正式日記庫重建完整索引', () async {
    final setup = await harness.repository.setupRecoveryKey();
    final Person person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小明'),
    );
    final String entryId = generateEntryId();
    final String assetId = generateAssetId();
    final DateTime timestamp = DateTime.utc(2026, 6, 11, 10);
    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: entryId,
        vaultId: setup.session.vaultId,
        title: 'Will Rebuild',
        date: const DateOnly('2026-06-11'),
        createdAt: timestamp,
        updatedAt: timestamp,
        markdownBody: 'rebuild-body 提到小明',
        attachmentIds: <String>[assetId],
      ),
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          assetId: assetId,
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          mimeType: 'application/octet-stream',
          originalFilename: 'note.bin',
        ),
      ],
    );

    await harness.repository.closeUnlockedResources();

    final IndexDatabaseManager manager = IndexDatabaseManager(
      harness.pathStrategy,
    );
    final indexDb = await manager.openForSession(setup.session);
    await indexDb.customStatement(
      'ALTER TABLE entries_index ADD COLUMN mood TEXT;',
    );
    await manager.close();

    await harness.repository.ensureIndexReady(setup.session);

    final entries = await harness.repository.listEntries(
      searchQuery: 'rebuild-body',
    );
    final attachments = await harness.repository.loadAttachments(entryId);
    final stats = await harness.repository.allPersonMentionStats(setup.session);

    expect(entries.map((entry) => entry.id), <String>[entryId]);
    expect(attachments.map((attachment) => attachment.id), <String>[assetId]);
    expect(stats[person.id]?.mentionedEntryCount, 1);
  });

  test('還原後 resume session 並 rebuildIndex 可列出日記', () async {
    final setup = await harness.repository.setupRecoveryKey();
    await harness.saveSimpleEntry(
      setup,
      title: 'Restore Resume',
      date: '2026-06-12',
      markdownBody: 'resume path',
    );

    final archiveIo = harness.createArchiveIo();
    final File backupFile = File(p.join(harness.tempDir.path, 'resume.zip'));
    await archiveIo.writeBackupZip(backupFile);

    await harness.repository.closeUnlockedResources();
    await archiveIo.restoreBackupZip(backupFile);

    final session = await harness.repository.resumeUnlockedSessionAfterRestore(
      setup.session,
    );
    await harness.repository.ensureIndexReady(session);
    await harness.repository.rebuildIndex(session);

    final entries = await harness.repository.listEntries();
    expect(entries, hasLength(1));
    expect(entries.single.title, 'Restore Resume');
  });
}
