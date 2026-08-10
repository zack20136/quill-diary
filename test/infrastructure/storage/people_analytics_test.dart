import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../../helpers/vault/vault_test_harness.dart';

void main() {
  late VaultTestHarness harness;
  late RecoverySetupResult setup;

  setUp(() async {
    harness = await VaultTestHarness.create();
    setup = await harness.repository.setupRecoveryKey();
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('新增人物後延遲分析既有日記', () async {
    await harness.saveSimpleEntry(
      setup,
      title: '與小明見面',
      markdownBody: '今天一起喝咖啡。',
    );
    final Person person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小明'),
    );

    final Map<String, PersonMentionStats> stats = await harness.repository
        .allPersonMentionStats(setup.session);

    expect(stats[person.id]?.mentionCount, 1);
  });

  test('修改單篇日記後由內容 hash 增量更新分析', () async {
    final Person person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小明'),
    );
    final String entryId = await harness.saveSimpleEntry(
      setup,
      markdownBody: '今天沒有約人。',
    );
    expect(
      (await harness.repository.allPersonMentionStats(
        setup.session,
      ))[person.id],
      isNull,
    );
    expect(
      await harness.repository.pendingPeopleAnalysisDocumentCountForTest(
        setup.session,
      ),
      0,
    );

    await harness.saveSimpleEntry(setup, id: entryId, markdownBody: '後來遇見小明。');
    expect(
      await harness.repository.pendingPeopleAnalysisDocumentCountForTest(
        setup.session,
      ),
      1,
    );
    final Map<String, PersonMentionStats> stats = await harness.repository
        .allPersonMentionStats(setup.session);

    expect(stats[person.id]?.mentionCount, 1);
  });

  test('人物名冊異動不會改寫日記檔', () async {
    await harness.saveSimpleEntry(setup, markdownBody: '原始日記內容');
    final EntryIndexRecord entry =
        (await harness.repository.listEntries()).single;
    final File entryFile = File(entry.filePath);
    final List<int> before = await entryFile.readAsBytes();

    final Person person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小明'),
    );
    await harness.repository.updatePerson(
      setup.session,
      person.id,
      PersonDraft(name: '王小明'),
    );
    await harness.repository.deletePerson(setup.session, person.id);

    expect(await entryFile.readAsBytes(), before);
  });

  test('程式碼與連結目的地中的姓名不列入分析', () async {
    final Person person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小明'),
    );
    await harness.saveSimpleEntry(
      setup,
      markdownBody: '```\n小明\n```\n[網站](https://example.com/小明)',
    );

    final Map<String, PersonMentionStats> stats = await harness.repository
        .allPersonMentionStats(setup.session);

    expect(stats[person.id], isNull);
  });

  test('首次查詢會補建舊索引可見正文且不使用搜尋文字替代', () async {
    final Person person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小明'),
    );
    await harness.saveSimpleEntry(
      setup,
      markdownBody: '```\n小明\n```\n[網站](https://example.com/小明)',
    );
    await harness.repository.closeUnlockedResources();
    final IndexDatabaseManager manager = IndexDatabaseManager(
      harness.pathStrategy,
    );
    final IndexDatabase database = await manager.openForSession(setup.session);
    await database.customStatement(
      'UPDATE entries_index SET body_visible_text = NULL;',
    );
    await manager.close();

    final Map<String, PersonMentionStats> stats = await harness.repository
        .allPersonMentionStats(setup.session);

    expect(stats[person.id], isNull);
    expect(harness.repository.peopleAnalyticsDebugMetrics.workerStarts, 1);
  });

  test('零命中日記不重掃且姓名異動會重新分析全部索引', () async {
    final Person person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: 'Alice'),
    );
    await harness.saveSimpleEntry(setup, markdownBody: 'Met Bob today.');

    expect(
      (await harness.repository.allPersonMentionStats(
        setup.session,
      ))[person.id],
      isNull,
    );
    expect(
      await harness.repository.pendingPeopleAnalysisDocumentCountForTest(
        setup.session,
      ),
      0,
    );

    await harness.repository.updatePerson(
      setup.session,
      person.id,
      PersonDraft(name: 'Bob'),
    );

    expect(
      (await harness.repository.allPersonMentionStats(
        setup.session,
      ))[person.id]?.mentionCount,
      1,
    );
  });

  test('刪除日記會同步清除衍生文件狀態與分析結果', () async {
    final Person person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小明'),
    );
    final String entryId = await harness.saveSimpleEntry(
      setup,
      markdownBody: '今天遇見小明。',
    );
    expect(
      (await harness.repository.allPersonMentionStats(
        setup.session,
      ))[person.id]?.mentionCount,
      1,
    );

    await harness.repository.deleteEntry(setup.session, entryId);

    expect(
      (await harness.repository.allPersonMentionStats(
        setup.session,
      ))[person.id],
      isNull,
    );
    expect(
      await harness.repository.pendingPeopleAnalysisDocumentCountForTest(
        setup.session,
      ),
      0,
    );
  });

  test('分析批次不會把已刪除或已修改日記的結果寫回', () async {
    final Person person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小明'),
    );
    final String entryId = await harness.saveSimpleEntry(
      setup,
      markdownBody: '小明',
    );
    await harness.repository.closeUnlockedResources();
    final IndexDatabaseManager manager = IndexDatabaseManager(
      harness.pathStrategy,
    );
    final IndexDatabase database = await manager.openForSession(setup.session);
    final PeopleAnalysisSourceDocument source =
        (await database.changedPeopleAnalysisDocuments()).single;
    await database.customStatement(
      "UPDATE entries_index SET content_hash = 'new-hash' WHERE id = ?;",
      <Object?>[entryId],
    );

    expect(
      await database.replacePeopleAnalyticsForDocuments(
        <PeopleAnalysisDocumentResult>[
          PeopleAnalysisDocumentResult(
            document: source,
            personIds: <String>{person.id},
          ),
        ],
      ),
      0,
    );
    expect(await database.allPersonMentionStats(), isEmpty);
    expect(await database.countChangedPeopleAnalysisDocuments(), 1);

    await database.removeEntry(entryId);
    expect(
      await database.replacePeopleAnalyticsForDocuments(
        <PeopleAnalysisDocumentResult>[
          PeopleAnalysisDocumentResult(
            document: source,
            personIds: <String>{person.id},
          ),
        ],
      ),
      0,
    );
    expect(await database.allPersonMentionStats(), isEmpty);
    await manager.close();
  });

  test('統計同篇只計一次並支援近三十天、月份與相關日記聚合', () async {
    final Person first = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小明'),
    );
    final Person second = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小華'),
    );
    await harness.saveSimpleEntry(
      setup,
      date: '2026-07-15',
      markdownBody: '小明、小明，今天見了兩次。',
    );
    await harness.saveSimpleEntry(
      setup,
      date: '2026-08-01',
      markdownBody: '小明與小華一起吃飯。',
    );
    await harness.saveSimpleEntry(
      setup,
      date: '2025-08-01',
      markdownBody: '去年也遇過小明。',
    );

    final Map<String, PersonMentionStats> stats = await harness.repository
        .allPersonMentionStats(setup.session, now: DateTime(2026, 8, 10));
    final List<PersonScopedMentionRank> august = await harness.repository
        .topMentionedPeople(setup.session, limit: 5, monthPrefix: '2026-08');
    final List<EntryIndexRecord> related = await harness.repository
        .relatedEntriesForPerson(setup.session, first.id);

    expect(stats[first.id]?.mentionCount, 3);
    expect(stats[first.id]?.recentMentionCount, 2);
    expect(stats[first.id]?.lastMentionDate?.value, '2026-08-01');
    expect(stats[second.id]?.mentionCount, 1);
    expect(
      august.map((PersonScopedMentionRank rank) => rank.personId),
      <String>[first.id, second.id],
    );
    expect(related, hasLength(3));
  });

  test('來源未變時不掃描正文也不寫入分析批次', () async {
    await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小明'),
    );
    await harness.saveSimpleEntry(setup, markdownBody: '今天遇見小明。');
    await harness.repository.allPersonMentionStats(setup.session);

    await harness.repository.allPersonMentionStats(setup.session);
    final PeopleAnalyticsDebugMetrics metrics =
        harness.repository.peopleAnalyticsDebugMetrics;

    expect(metrics.scannedDocuments, 0);
    expect(metrics.batchWrites, 0);
    expect(metrics.workerStarts, 0);
  });

  test('只修改人物關係或顏色不會重新掃描正文', () async {
    final Person person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小明'),
    );
    await harness.saveSimpleEntry(setup, markdownBody: '今天遇見小明。');
    await harness.repository.allPersonMentionStats(setup.session);

    await harness.repository.updatePerson(
      setup.session,
      person.id,
      PersonDraft(
        name: person.name,
        relationships: const <PersonRelationship>{
          PersonRelationship.collaborator,
        },
        accentArgb: 0xFF5480B0,
      ),
    );
    await harness.repository.allPersonMentionStats(setup.session);
    final PeopleAnalyticsDebugMetrics metrics =
        harness.repository.peopleAnalyticsDebugMetrics;

    expect(metrics.scannedDocuments, 0);
    expect(metrics.batchWrites, 0);
    expect(metrics.workerStarts, 0);
  });

  test('大量異動只啟動一個 worker 並以單一批次寫入', () async {
    final Person person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小明'),
    );
    for (int index = 0; index < 9; index++) {
      await harness.saveSimpleEntry(setup, markdownBody: '第 $index 篇提到小明。');
    }

    final Map<String, PersonMentionStats> stats = await harness.repository
        .allPersonMentionStats(setup.session);
    final PeopleAnalyticsDebugMetrics metrics =
        harness.repository.peopleAnalyticsDebugMetrics;

    expect(stats[person.id]?.mentionCount, 9);
    expect(metrics.scannedDocuments, 9);
    expect(metrics.batchWrites, 1);
    expect(metrics.workerStarts, 1);
  });

  test('同一 vault 的並行統計請求會共用分析工作', () async {
    final Person person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小明'),
    );
    for (var index = 0; index < 9; index++) {
      await harness.saveSimpleEntry(setup, markdownBody: '第 $index 篇遇到小明');
    }

    final List<Object> results = await Future.wait<Object>(<Future<Object>>[
      harness.repository.allPersonMentionStats(setup.session),
      harness.repository.relatedEntriesForPerson(setup.session, person.id),
      harness.repository.topMentionedPeople(setup.session, limit: 5),
    ]);

    expect(
      (results[0] as Map<String, PersonMentionStats>)[person.id]?.mentionCount,
      9,
    );
    expect(harness.repository.peopleAnalyticsDebugMetrics.workerStarts, 1);
  });

  test('單篇超長正文也會交由 worker 分析', () async {
    final Person person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小明'),
    );
    await harness.saveSimpleEntry(
      setup,
      markdownBody: '${List<String>.filled(7000, '很長的內容').join()} 小明',
    );

    final Map<String, PersonMentionStats> stats = await harness.repository
        .allPersonMentionStats(setup.session);
    final PeopleAnalyticsDebugMetrics metrics =
        harness.repository.peopleAnalyticsDebugMetrics;

    expect(stats[person.id]?.mentionCount, 1);
    expect(metrics.scannedDocuments, 1);
    expect(metrics.batchWrites, 1);
    expect(metrics.workerStarts, 1);
  });

  test('鎖定會等待分析工作停止且重新解鎖後可安全接續', () async {
    final Person person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小明'),
    );
    await harness.saveSimpleEntry(
      setup,
      markdownBody: '${List<String>.filled(12000, '很長的內容').join()}小明',
    );
    final Future<void> analysis = harness.repository
        .allPersonMentionStats(setup.session)
        .then<void>((_) {}, onError: (_, _) {});
    await Future<void>.delayed(Duration.zero);

    await harness.repository.closeUnlockedResources();
    await analysis;

    final Map<String, PersonMentionStats> resumed = await harness.repository
        .allPersonMentionStats(setup.session);
    expect(resumed[person.id]?.mentionCount, 1);
  });

  test('超過兩批資料仍只啟動一個 worker 且每批一個 transaction', () async {
    final Person person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小明'),
    );
    await harness.repository.closeUnlockedResources();
    final IndexDatabaseManager manager = IndexDatabaseManager(
      harness.pathStrategy,
    );
    addTearDown(manager.close);
    final IndexDatabase database = await manager.openForSession(setup.session);
    await database.transaction(() async {
      for (var index = 0; index < 513; index++) {
        final String id = 'ent_${index.toString().padLeft(4, '0')}';
        await database.customStatement(
          '''
            INSERT INTO entries_index (
              id, vault_id, file_path, title_search_text, body_search_text,
              body_visible_text, date, created_at, updated_at, word_count,
              char_count, attachment_count, has_attachments, content_hash
            ) VALUES (?, ?, ?, '', ?, ?, '2026-08-10', ?, ?, 1, 2, 0, 0, ?);
          ''',
          <Object?>[
            id,
            setup.session.vaultId,
            'C:/unused/$id.md.enc',
            '小明',
            '小明',
            DateTime.utc(2026, 8, 10).toIso8601String(),
            DateTime.utc(2026, 8, 10).toIso8601String(),
            'hash_$id',
          ],
        );
      }
    });
    await manager.close();

    final Map<String, PersonMentionStats> stats = await harness.repository
        .allPersonMentionStats(setup.session);
    final PeopleAnalyticsDebugMetrics metrics =
        harness.repository.peopleAnalyticsDebugMetrics;

    expect(stats[person.id]?.mentionCount, 513);
    expect(metrics.scannedDocuments, 513);
    expect(metrics.batchWrites, 3);
    expect(metrics.workerStarts, 1);
  });
}
