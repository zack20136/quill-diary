import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';

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

  test('ensureIndexReady 在 schema 不符時重置為空索引', () async {
    final setup = await harness.repository.setupRecoveryKey();
    await harness.saveSimpleEntry(
      setup,
      title: 'Will Reset',
      date: '2026-06-11',
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

    expect(await harness.repository.listEntries(), isEmpty);
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
