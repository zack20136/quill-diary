import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/domain/diary/diary_entry.dart';
import 'package:quill_lock_diary/domain/shared/value_objects.dart';
import 'package:quill_lock_diary/infrastructure/database/index_database.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_repository.dart';

import '../helpers/vault_test_harness.dart';

void main() {
  late VaultTestHarness harness;

  setUp(() async {
    harness = await VaultTestHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('save / list / search / load / delete / rebuildIndex 完整流程', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final session = setup.session;

    final DiaryEntry draft = DiaryEntry(
      id: generateEntryId(),
      vaultId: session.vaultId,
      title: '標題關鍵字測試',
      date: const DateOnly('2026-05-14'),
      createdAt: DateTime.parse('2026-05-14T10:00:00Z'),
      updatedAt: DateTime.parse('2026-05-14T10:00:00Z'),
      tags: const <String>['日記'],
      markdownBody: '# 關鍵字測試\n\n內文段落',
    );

    final DiaryEntry saved = await harness.repository.saveEntry(session, draft);
    final List<EntryIndexRecord> entries = await harness.repository.listEntries();
    expect(entries.any((EntryIndexRecord e) => e.id == saved.id), isTrue);

    final List<EntryIndexRecord> searchResults =
        await harness.repository.searchEntries('關鍵字');
    expect(searchResults.any((EntryIndexRecord e) => e.id == saved.id), isTrue);

    final DiaryEntry? loaded = await harness.repository.loadEntry(session, saved.id);
    expect(loaded?.markdownBody, draft.markdownBody);
    expect(loaded?.title, draft.title);
    expect(loaded?.tags, draft.tags);

    await harness.repository.deleteEntry(session, saved.id);
    final List<EntryIndexRecord> afterDelete = await harness.repository.listEntries();
    expect(afterDelete.any((EntryIndexRecord e) => e.id == saved.id), isFalse);

    await harness.repository.rebuildIndex(session);
    final DiaryEntry? afterRebuild = await harness.repository.loadEntry(session, saved.id);
    expect(afterRebuild?.markdownBody, draft.markdownBody);
  });
}
