import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/infrastructure/storage/vault_state_keys.dart';

import '../helpers/vault_test_harness.dart';

void main() {
  late VaultTestHarness harness;

  setUp(() async {
    harness = await VaultTestHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('save list search load delete and rebuild index', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final session = setup.session;

    final DiaryEntry draft = DiaryEntry(
      id: generateEntryId(),
      vaultId: session.vaultId,
      title: 'trip checklist',
      date: const DateOnly('2026-05-14'),
      createdAt: DateTime.parse('2026-05-14T10:00:00Z'),
      updatedAt: DateTime.parse('2026-05-14T10:00:00Z'),
      tags: const <String>['travel'],
      markdownBody: '# trip checklist\n\npack camera',
    );

    final DiaryEntry saved = await harness.repository.saveEntry(session, draft);
    final List<EntryIndexRecord> entries = await harness.repository.listEntries();
    expect(entries.any((EntryIndexRecord e) => e.id == saved.id), isTrue);

    final List<EntryIndexRecord> searchResults =
        await harness.repository.searchEntries('trip');
    final List<EntryIndexRecord> tagResults =
        await harness.repository.searchEntries('trav');
    expect(searchResults.any((EntryIndexRecord e) => e.id == saved.id), isTrue);
    expect(tagResults.any((EntryIndexRecord e) => e.id == saved.id), isTrue);

    final DiaryEntry? loaded = await harness.repository.loadEntry(session, saved.id);
    expect(loaded?.markdownBody, draft.markdownBody);
    expect(loaded?.title, draft.title);
    expect(loaded?.tags, draft.tags);

    await harness.repository.deleteEntry(session, saved.id);
    final List<EntryIndexRecord> afterDelete = await harness.repository.listEntries();
    expect(afterDelete.any((EntryIndexRecord e) => e.id == saved.id), isFalse);

    await harness.repository.rebuildIndex(session);
    final List<EntryIndexRecord> afterRebuildList = await harness.repository.listEntries();
    expect(afterRebuildList.any((EntryIndexRecord e) => e.id == saved.id), isFalse);
    expect(await harness.repository.loadEntry(session, saved.id), isNull);
  });

  test('searchEntries matches substrings anywhere in the full body', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final session = setup.session;
    final String longTail = ' ending marker after the preview boundary';

    final DiaryEntry draft = DiaryEntry(
      id: generateEntryId(),
      vaultId: session.vaultId,
      title: 'spec note',
      date: const DateOnly('2026-05-15'),
      createdAt: DateTime.parse('2026-05-15T10:00:00Z'),
      updatedAt: DateTime.parse('2026-05-15T10:00:00Z'),
      tags: const <String>['size-lookup'],
      markdownBody:
          'panel size 60x30x3 ready for review with a very long body segment that keeps going past eighty characters$longTail',
    );

    final DiaryEntry saved = await harness.repository.saveEntry(session, draft);

    final List<EntryIndexRecord> midTokenResults =
        await harness.repository.searchEntries('x30');
    final List<EntryIndexRecord> numericResults =
        await harness.repository.searchEntries('30');
    final List<EntryIndexRecord> singleCharResults =
        await harness.repository.searchEntries('x');
    final List<EntryIndexRecord> longTailResults =
        await harness.repository.searchEntries('preview boundary');

    expect(midTokenResults.any((EntryIndexRecord e) => e.id == saved.id), isTrue);
    expect(numericResults.any((EntryIndexRecord e) => e.id == saved.id), isTrue);
    expect(singleCharResults.any((EntryIndexRecord e) => e.id == saved.id), isTrue);
    expect(longTailResults.any((EntryIndexRecord e) => e.id == saved.id), isTrue);
  });

  test('edited entry search reflects latest body immediately', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final session = setup.session;

    final DiaryEntry draft = DiaryEntry(
      id: generateEntryId(),
      vaultId: session.vaultId,
      title: 'spec note',
      date: const DateOnly('2026-05-16'),
      createdAt: DateTime.parse('2026-05-16T10:00:00Z'),
      updatedAt: DateTime.parse('2026-05-16T10:00:00Z'),
      markdownBody: 'first body has alpha token',
    );

    final DiaryEntry saved = await harness.repository.saveEntry(session, draft);
    final DiaryEntry updated = saved.copyWith(
      markdownBody: 'second body has beta token',
      updatedAt: DateTime.parse('2026-05-16T11:00:00Z'),
    );
    await harness.repository.saveEntry(session, updated);

    final List<EntryIndexRecord> oldResults =
        await harness.repository.searchEntries('alpha');
    final List<EntryIndexRecord> newResults =
        await harness.repository.searchEntries('beta');

    expect(oldResults.any((EntryIndexRecord e) => e.id == saved.id), isFalse);
    expect(newResults.any((EntryIndexRecord e) => e.id == saved.id), isTrue);
  });

  test('imported markdown entry is searchable immediately', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final session = setup.session;
    final VaultArchiveIo archiveIo = VaultArchiveIo(
      pathStrategy: harness.pathStrategy,
      repository: harness.repository,
      frontMatterCodec: const FrontMatterCodec(),
      indexDatabaseManager: IndexDatabaseManager(harness.pathStrategy),
    );
    final Directory importRoot = await Directory.systemTemp.createTemp('qld_import_search_');

    try {
      final File markdownFile = File('${importRoot.path}\\entry.md');
      await markdownFile.writeAsString(
        '# imported spec\n\nImported body with 60x30x3 marker inside.',
      );

      final PortableImportResult result = await archiveIo.importDocuments(
        session: session,
        rootDirectory: importRoot,
      );
      final List<EntryIndexRecord> results =
          await harness.repository.searchEntries('x30');

      expect(result.importedEntries, 1);
      expect(results, hasLength(1));
    } finally {
      if (importRoot.existsSync()) {
        await importRoot.delete(recursive: true);
      }
    }
  });

  test('ensureIndexReady rebuilds outdated search schema before searching', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final session = setup.session;

    final DiaryEntry draft = DiaryEntry(
      id: generateEntryId(),
      vaultId: session.vaultId,
      title: 'schema rebuild',
      date: const DateOnly('2026-05-17'),
      createdAt: DateTime.parse('2026-05-17T10:00:00Z'),
      updatedAt: DateTime.parse('2026-05-17T10:00:00Z'),
      markdownBody:
          'body text that pushes the target well past the preview limit before marker-x30 appears',
    );

    final DiaryEntry saved = await harness.repository.saveEntry(session, draft);
    await harness.repository.closeUnlockedResources();

    final IndexDatabaseManager manager = IndexDatabaseManager(harness.pathStrategy);
    await manager.openForSession(session);
    await manager.requireOpen().customStatement(
      "UPDATE entries_index SET body_search_text = '' WHERE id = ?;",
      <Object?>[saved.id],
    );
    await manager.requireOpen().setAppValue(kSearchSchemaVersionKey, '0');
    await manager.close();

    await harness.repository.ensureIndexReady(session);
    final List<EntryIndexRecord> dashedResults =
        await harness.repository.searchEntries('marker-x30');
    final List<EntryIndexRecord> spacedResults =
        await harness.repository.searchEntries('marker x30');

    expect(dashedResults.any((EntryIndexRecord e) => e.id == saved.id), isTrue);
    expect(spacedResults.any((EntryIndexRecord e) => e.id == saved.id), isTrue);
  });

  test('deleteEntry removes entry and attachment files from disk', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final session = setup.session;
    final File sourceAttachment = File('${harness.tempDir.path}/photo.jpg')
      ..writeAsBytesSync(const <int>[1, 2, 3, 4]);

    final DiaryEntry draft = DiaryEntry(
      id: generateEntryId(),
      vaultId: session.vaultId,
      title: 'with photo',
      date: const DateOnly('2026-05-18'),
      createdAt: DateTime.parse('2026-05-18T10:00:00Z'),
      updatedAt: DateTime.parse('2026-05-18T10:00:00Z'),
      markdownBody: 'entry with attachment',
    );

    final DiaryEntry saved = await harness.repository.saveEntry(
      session,
      draft,
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          sourcePath: sourceAttachment.path,
          mimeType: 'image/jpeg',
          originalFilename: 'photo.jpg',
        ),
      ],
    );
    final String entryPath = await harness.pathStrategy.entryAbsolutePath(
      date: saved.date,
      entryId: saved.id,
    );
    final List<AssetAttachment> attachments = await harness.repository.loadAttachments(saved.id);
    expect(attachments, hasLength(1));
    final String assetPath = await harness.pathStrategy.assetAbsolutePath(
      date: saved.date,
      assetId: attachments.single.id,
      extension: 'jpg',
    );
    expect(File(entryPath).existsSync(), isTrue);
    expect(File(assetPath).existsSync(), isTrue);

    await harness.repository.deleteEntry(session, saved.id);

    expect(File(entryPath).existsSync(), isFalse);
    expect(File(assetPath).existsSync(), isFalse);
  });

  test('saveEntry removes detached attachment files from disk', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final session = setup.session;
    final File sourceAttachment = File('${harness.tempDir.path}/detach.jpg')
      ..writeAsBytesSync(const <int>[5, 6, 7]);

    final DiaryEntry draft = DiaryEntry(
      id: generateEntryId(),
      vaultId: session.vaultId,
      date: const DateOnly('2026-05-19'),
      createdAt: DateTime.parse('2026-05-19T10:00:00Z'),
      updatedAt: DateTime.parse('2026-05-19T10:00:00Z'),
      markdownBody: 'keep then drop attachment',
    );

    final DiaryEntry saved = await harness.repository.saveEntry(
      session,
      draft,
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          sourcePath: sourceAttachment.path,
          mimeType: 'image/jpeg',
          originalFilename: 'detach.jpg',
        ),
      ],
    );
    final List<AssetAttachment> attachments = await harness.repository.loadAttachments(saved.id);
    expect(attachments, hasLength(1));
    final String assetPath = await harness.pathStrategy.assetAbsolutePath(
      date: saved.date,
      assetId: attachments.single.id,
      extension: 'jpg',
    );
    expect(File(assetPath).existsSync(), isTrue);

    await harness.repository.saveEntry(
      session,
      saved.copyWith(
        attachmentIds: const <AssetId>[],
        updatedAt: DateTime.parse('2026-05-19T11:00:00Z'),
      ),
    );

    expect(File(assetPath).existsSync(), isFalse);
  });

  test('saveEntry moves entry and attachments when date changes', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final session = setup.session;
    final File sourceAttachment = File('${harness.tempDir.path}/move.jpg')
      ..writeAsBytesSync(const <int>[8, 9, 10]);

    final DiaryEntry draft = DiaryEntry(
      id: generateEntryId(),
      vaultId: session.vaultId,
      date: const DateOnly('2026-05-20'),
      createdAt: DateTime.parse('2026-05-20T10:00:00Z'),
      updatedAt: DateTime.parse('2026-05-20T10:00:00Z'),
      markdownBody: 'move with attachment',
    );

    final DiaryEntry saved = await harness.repository.saveEntry(
      session,
      draft,
      pendingAttachments: <PendingAttachment>[
        PendingAttachment(
          sourcePath: sourceAttachment.path,
          mimeType: 'image/jpeg',
          originalFilename: 'move.jpg',
        ),
      ],
    );
    final List<AssetAttachment> attachments = await harness.repository.loadAttachments(saved.id);
    expect(attachments, hasLength(1));
    final AssetAttachment attachment = attachments.single;
    final String oldEntryPath = await harness.pathStrategy.entryAbsolutePath(
      date: const DateOnly('2026-05-20'),
      entryId: saved.id,
    );
    final String oldAssetPath = await harness.pathStrategy.assetAbsolutePath(
      date: const DateOnly('2026-05-20'),
      assetId: attachment.id,
      extension: 'jpg',
    );

    final DiaryEntry moved = await harness.repository.saveEntry(
      session,
      saved.copyWith(
        date: const DateOnly('2026-06-01'),
        updatedAt: DateTime.parse('2026-06-01T10:00:00Z'),
      ),
    );

    final String newEntryPath = await harness.pathStrategy.entryAbsolutePath(
      date: const DateOnly('2026-06-01'),
      entryId: saved.id,
    );
    final String newAssetPath = await harness.pathStrategy.assetAbsolutePath(
      date: const DateOnly('2026-06-01'),
      assetId: attachment.id,
      extension: 'jpg',
    );

    expect(File(oldEntryPath).existsSync(), isFalse);
    expect(File(oldAssetPath).existsSync(), isFalse);
    expect(File(newEntryPath).existsSync(), isTrue);
    expect(File(newAssetPath).existsSync(), isTrue);
    expect(moved.date, const DateOnly('2026-06-01'));
    expect(await harness.repository.loadEntry(session, saved.id), isNotNull);
  });
}
