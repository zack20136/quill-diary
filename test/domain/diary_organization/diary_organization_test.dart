import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/ai_composer_snapshot.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/diary_organization/diary_organization.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

import '../../helpers/ai/ai_test_helpers.dart';

DiaryOrganization _draft(String body) => DiaryOrganization(
  source: DiaryEntry(
    id: generateEntryId(),
    vaultId: 'vault',
    date: const DateOnly('2026-11-03'),
    createdAt: DateTime(2026, 11, 3),
    updatedAt: DateTime(2026, 11, 3),
    markdownBody: body,
  ),
  connection: testChatDiarySession().connectionConfig,
);

void main() {
  test('其他分支的代號不還原也不能加入候選，目前分支補充仍可使用', () {
    final draft = _draft('公開原文')..prepare();
    draft.originals.addAll({'⟦S01⟧': '舊分支秘密', '⟦S02⟧': '目前補充'});
    draft.appendTurn(OrganizationTurn(user: '舊需求 ⟦S01⟧'));
    draft.appendTurn(OrganizationTurn(user: '新需求 ⟦S02⟧'));

    expect(draft.restore('⟦S01⟧／⟦S02⟧'), '⟦S01⟧／目前補充');
    expect(() => draft.replaceBody('公開原文 ⟦S01⟧'), throwsFormatException);
    draft.replaceBody('公開原文 ⟦S02⟧');
    expect(draft.restoredBody, '公開原文 目前補充');
  });

  test('回覆還原只使用該回合的祖先需求，不取後續代號或其他分支姓名寫法', () {
    final draft = _draft('公開原文')..prepare();
    draft.originals.addAll({'⟦P01⟧': '別的分支稱呼', '⟦S01⟧': '後續秘密'});
    draft.appendTurn(OrganizationTurn(user: '舊需求 ⟦P01⟧'));
    draft.appendTurn(
      OrganizationTurn(
        user: '新需求 ⟦P01⟧',
        surfaces: {
          '⟦P01⟧': ['目前稱呼'],
        },
      ),
    );
    draft.appendTurn(OrganizationTurn(user: '補充 ⟦S01⟧', parentIndex: 1));
    expect(draft.visibleText('⟦P01⟧ ⟦S01⟧', turn: 1).text, '目前稱呼 ⟦S01⟧');
    expect(draft.replyIsInScope(1, text: '⟦S01⟧'), isFalse);
    expect(draft.visibleText('⟦P01⟧', turn: 0).text, '別的分支稱呼');
  });

  test('舊候選範圍不符時保留對話可讀，但不得還原或套用', () {
    final draft = _draft('原文')..prepare();
    draft.originals['⟦S01⟧'] = '已離開分支的秘密';
    draft.appendTurn(OrganizationTurn(user: '舊需求 ⟦S01⟧'));
    draft.appendTurn(OrganizationTurn(user: '目前需求'));
    final loaded = DiaryOrganization.fromJson({
      ...draft.toJson(),
      'organized_body': '原文 ⟦S01⟧',
      'stage': 'review',
    });
    expect(loaded.hasUnsafeCandidate, isTrue);
    expect(loaded.turns, hasLength(2));
    expect(() => loaded.restoredBody, throwsFormatException);
    expect(loaded.restore('⟦S01⟧'), '⟦S01⟧');
  });

  test('上線版第一版整理保留原文與代號，不補歷史 Thinking 或人物對照', () {
    final draft = DiaryOrganization.fromJson({
      'version': 1,
      'source': {
        'id': generateEntryId(),
        'vault': 'vault',
        'title': null,
        'date': '2026-11-03',
        'created': '2026-11-03T09:00:00.000',
        'updated': '2026-11-03T09:00:00.000',
        'tags': [],
        'body': '原始日記',
        'attachments': [],
      },
      'connection': {'provider': 'openai', 'default_model': 'gpt-5'},
      'stage': 'chat',
      'ranges': [],
      'originals': {},
      'protected_source': '原始日記',
      'turns': [],
      'root_turn': null,
      'selected_children': {},
      'generation_interrupted': false,
      'composer': '',
      'composer_ranges': [],
    });
    expect(draft.source.markdownBody, '原始日記');
    expect(draft.protectedSource, '原始日記');
    expect(draft.personTokenById, isEmpty);
    expect(draft.tokenSurfaces, isEmpty);
    expect(draft.connection.hasCompleteRequestSnapshot, isFalse);
    final loaded = DiaryOrganization.fromJson(
      jsonDecode(jsonEncode(draft.toJson())) as Map<String, dynamic>,
    );
    expect(loaded.toJson(), draft.toJson());
  });

  test('已提供的編輯備份型別錯誤時拒讀，不當成缺省', () {
    final data =
        jsonDecode(jsonEncode(_draft('原文').toJson())) as Map<String, dynamic>;
    data['composer_backup'] = '損壞的備份';
    expect(() => DiaryOrganization.fromJson(data), throwsA(isA<TypeError>()));
  });

  test('隱私對照缺項與舊長代號拒讀，不修改代號或猜測缺失原文', () {
    final draft = _draft('私密原文')..hiddenRanges = [const PrivateTextRange(0, 2)];
    draft.prepare();
    final missing =
        jsonDecode(jsonEncode(draft.toJson())) as Map<String, dynamic>;
    missing['originals'] = <String, String>{};
    expect(() => DiaryOrganization.fromJson(missing), throwsFormatException);
    final long = jsonDecode(
      jsonEncode(draft.toJson()).replaceAll('⟦S01⟧', '⟦QABC_0⟧'),
    ) as Map<String, dynamic>;
    expect(() => DiaryOrganization.fromJson(long), throwsFormatException);
  });

  test('只隱藏選取的姓名位置，其他相同原文仍可見', () {
    final draft = _draft('小明與小明聊天')
      ..hiddenRanges = [const PrivateTextRange(0, 2)];
    draft.prepare();
    expect(draft.protectedSource, endsWith('與小明聊天'));
    expect(draft.restore(draft.protectedSource), draft.source.markdownBody);
  });

  test('隱藏片段漏掉、重複、換序或加入未知代號時拒絕整理稿', () {
    final draft = _draft('甲與乙')
      ..hiddenRanges = [
        const PrivateTextRange(0, 1),
        const PrivateTextRange(2, 3),
      ];
    draft.prepare();
    final tokens = draft.originals.keys.toList();
    draft.validateBody('${tokens[0]}和${tokens[1]}');
    for (final body in [
      tokens[0],
      '${tokens[0]}${tokens[0]}${tokens[1]}',
      '${tokens[1]}${tokens[0]}',
      '${tokens[0]}${tokens[1]}⟦SFF⟧',
    ]) {
      expect(() => draft.replaceBody(body), throwsFormatException);
    }
    expect(draft.organizedBody, isNull);
  });

  test('圖片網址只作為本機保護區段，不傳給 AI', () {
    final draft = _draft('看照片 ![私密名稱](https://example.com/private.png) 很開心');
    draft.prepare();
    expect(draft.protectedSource, isNot(contains('example.com')));
    expect(draft.restore(draft.protectedSource), draft.source.markdownBody);
  });

  test('重複原文的不同隱藏位置使用不同短代號，保持原有順序', () {
    final draft = _draft('甲與甲')
      ..hiddenRanges = [
        const PrivateTextRange(0, 1),
        const PrivateTextRange(2, 3),
      ];
    draft.prepare();
    expect(draft.protectedSource, '⟦S01⟧與⟦S02⟧');
    expect(draft.restore(draft.protectedSource), '甲與甲');
    expect(() => draft.validateBody('⟦S02⟧與⟦S01⟧'), throwsFormatException);
  });

  test('完整人物區間使用 P，選取包含其他文字時使用 S', () {
    final draft = _draft('甲與秘密')
      ..hiddenRanges = [
        const PrivateTextRange(0, 1),
        const PrivateTextRange(2, 4),
      ];
    draft.prepare(personRanges: [const PersonTextRange(0, 1, 'jia')]);
    expect(draft.protectedSource, '⟦P01⟧與⟦S01⟧');
    expect(draft.restore(draft.protectedSource), '甲與秘密');
    final merged = _draft('甲與秘密')
      ..hiddenRanges = [const PrivateTextRange(0, 4)];
    merged.prepare(personRanges: [const PersonTextRange(0, 1, 'jia')]);
    expect(merged.protectedSource, '⟦S01⟧');
  });

  test('同一人物共用一個 P 代號，姓名與別名仍依出現順序還原', () {
    final draft = _draft('小明與王小明')
      ..hiddenRanges = [
        const PrivateTextRange(0, 2),
        const PrivateTextRange(3, 6),
      ];
    draft.prepare(
      personRanges: const [
        PersonTextRange(0, 2, 'ming'),
        PersonTextRange(3, 6, 'ming'),
      ],
    );
    expect(draft.protectedSource, '⟦P01⟧與⟦P01⟧');
    expect(draft.restore(draft.protectedSource), '小明與王小明');
    expect(draft.personTokenById, {'ming': '⟦P01⟧'});
    expect(draft.toJson()['token_surfaces'], {
      '⟦P01⟧': ['小明', '王小明'],
    });
    expect(draft.toJson()['version'], 1);
    draft.validateBody('前⟦P01⟧後⟦P01⟧');
    for (final body in ['⟦P01⟧', '⟦P01⟧與⟦P01⟧⟦P01⟧', '⟦P01⟧與⟦P02⟧']) {
      expect(() => draft.replaceBody(body), throwsFormatException);
    }
    final loaded = DiaryOrganization.fromJson(
      jsonDecode(jsonEncode(draft.toJson())) as Map<String, dynamic>,
    );
    expect(loaded.restore(loaded.protectedSource), '小明與王小明');
    expect(loaded.personTokenById, draft.personTokenById);

    final sameText = _draft('王小明與王小明')
      ..hiddenRanges = [
        const PrivateTextRange(0, 3),
        const PrivateTextRange(4, 7),
      ];
    sameText.prepare(
      personRanges: const [
        PersonTextRange(0, 3, 'ming'),
        PersonTextRange(4, 7, 'ming'),
      ],
    );
    expect(sameText.protectedSource, '⟦P01⟧與⟦P01⟧');
    expect(sameText.toJson().containsKey('token_surfaces'), isFalse);
    expect(sameText.restore(sameText.protectedSource), '王小明與王小明');

    final others = _draft('甲與乙')
      ..hiddenRanges = [
        const PrivateTextRange(0, 1),
        const PrivateTextRange(2, 3),
      ];
    others.prepare(
      personRanges: const [
        PersonTextRange(0, 1, 'a'),
        PersonTextRange(2, 3, 'b'),
      ],
    );
    expect(others.protectedSource, '⟦P01⟧與⟦P02⟧');
  });

  test('日記原本含有代號文字時保留原文，避免與隱藏代號衝突', () {
    final draft = _draft('原文有⟦S01⟧')..prepare();
    expect(draft.protectedSource, '原文有⟦S02⟧');
    expect(draft.restore(draft.protectedSource), draft.source.markdownBody);
    draft.validateBody(draft.protectedSource);
  });

  test('只保存一份目前稿，空的隱藏清單與輸入可以完整還原', () {
    final draft = _draft('原文');
    draft.prepare();
    draft.replaceBody('第一版');
    draft.replaceBody('手動版');
    draft.stage = OrganizationStage.review;
    draft.composer = '再修改';
    final loaded = DiaryOrganization.fromJson(
      jsonDecode(jsonEncode(draft.toJson())) as Map<String, dynamic>,
    );
    expect(loaded.hiddenRanges, isEmpty);
    expect(loaded.currentBody, '手動版');
    expect(loaded.toJson().containsKey('revisions'), isFalse);
    expect(loaded.stage, OrganizationStage.review);
    expect(loaded.composer, '再修改');
  });

  test('切換聊天分支不改變目前稿，未支援格式拒絕讀取', () {
    final draft = _draft('原文')..prepare();
    draft.appendTurn(OrganizationTurn(user: '修順', interrupted: false));
    draft.appendTurn(OrganizationTurn(user: '精簡', interrupted: false));
    draft.replaceBody('目前稿');
    draft.selectTurn(0);
    expect(draft.currentBody, '目前稿');
    expect(draft.toJson()['version'], 1);
    expect(
      () => DiaryOrganization.fromJson({...draft.toJson(), 'version': 999}),
      throwsFormatException,
    );
  });

  test('第一版格式恢復聊天分支、編輯中的輸入與生成中斷狀態', () {
    final draft = _draft('原文')..prepare();
    draft.appendTurn(
      OrganizationTurn(user: '第一個需求', reply: '建議', interrupted: false),
    );
    draft.appendTurn(
      OrganizationTurn(user: '另一個需求', reply: '新建議', interrupted: false),
    );
    draft.replaceBody('唯一目前稿');
    draft.editingTurn = 1;
    draft.composer = '編輯中的需求';
    draft.composerRanges = [const PrivateTextRange(0, 2)];
    draft.composerBackup = AiComposerSnapshot(
      text: '原本未送出的文字',
      ranges: [const PrivateTextRange(0, 2)],
      imageIds: [],
    );
    draft.generationInterrupted = true;
    final encoded = jsonEncode(draft.toJson());
    final loaded = DiaryOrganization.fromJson(
      jsonDecode(encoded) as Map<String, dynamic>,
    );
    expect(loaded.toJson(), draft.toJson());
    expect(loaded.activeTurnIndices, [1]);
    expect(loaded.currentBody, '唯一目前稿');
    expect(loaded.composerBackup!.text, '原本未送出的文字');
    expect(loaded.composerBackup!.imageIds, isEmpty);
    expect(
      (loaded.toJson()['composer_backup'] as Map).containsKey('image_ids'),
      isFalse,
    );
    expect(loaded.generationInterrupted, isTrue);
  });
}
