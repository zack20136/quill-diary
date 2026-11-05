import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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

  test('舊草稿裡同一人物的多個代號會合併，並保留各自原文', () {
    final draft = _draft('小明與王小明');
    draft.protectedSource = '⟦P01⟧與⟦P02⟧';
    draft.originals.addAll({'⟦P01⟧': '小明', '⟦P02⟧': '王小明'});
    draft.appendTurn(
      OrganizationTurn(user: '提到⟦P02⟧', reply: '知道⟦P02⟧', interrupted: false),
    );
    draft.classifyPersonTokens(const [
      PersonTextRange(0, 2, 'ming'),
      PersonTextRange(3, 6, 'ming'),
    ]);
    expect(draft.protectedSource, '⟦P01⟧與⟦P01⟧');
    expect(draft.originals.containsKey('⟦P02⟧'), isFalse);
    expect(draft.restore(draft.protectedSource), '小明與王小明');
    expect(draft.turns.single.user, '提到⟦P01⟧');
    expect(draft.turns.single.reply, '知道⟦P01⟧');
    expect(
      organizationVisibleText(
        draft.turns.single.user,
        draft.originals,
        surfaces: draft.turns.single.surfaces,
      ).text,
      '提到王小明',
    );
  });

  test('日記原本含有代號文字時保留原文，避免與隱藏代號衝突', () {
    final draft = _draft('原文有⟦S01⟧')..prepare();
    expect(draft.protectedSource, '原文有⟦S02⟧');
    expect(draft.restore(draft.protectedSource), draft.source.markdownBody);
    draft.validateBody(draft.protectedSource);
  });

  test('既有長代號暫存讀取為短代號，保留聊天、目前稿及未送出文字', () {
    final draft = _draft('甲與乙')..hiddenRanges = [const PrivateTextRange(0, 1)];
    draft.prepare();
    draft.replaceBody('⟦S01⟧和乙');
    draft.appendTurn(
      OrganizationTurn(user: '保留⟦S01⟧', reply: '會保留⟦S01⟧', interrupted: false),
    );
    draft.composer = '尚未送出的甲';
    const longToken = '⟦QABC_0⟧';
    final json = jsonDecode(
      jsonEncode(draft.toJson()).replaceAll('⟦S01⟧', longToken),
    ) as Map<String, dynamic>;
    final loaded = DiaryOrganization.fromJson(json);
    expect(loaded.protectedSource, '⟦S01⟧與乙');
    expect(loaded.restoredBody, '甲和乙');
    expect(loaded.turns.single.user, '保留⟦S01⟧');
    expect(loaded.turns.single.reply, '會保留⟦S01⟧');
    expect(loaded.composer, '尚未送出的甲');
    expect(loaded.toJson()['version'], 1);
    expect(jsonEncode(loaded.toJson()), isNot(contains(longToken)));
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
