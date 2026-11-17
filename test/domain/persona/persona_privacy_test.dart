import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_privacy.dart';

import '../../helpers/persona/persona_fixtures.dart';

void main() {
  test('不同匯入來源的同名人物不共用匿名識別', () {
    final registry = PersonaTokenRegistry([], hideNames: true);
    registry.replaceImportNames(['小美'], scope: 'first');
    registry.replaceImportNames(['小美'], scope: 'second');
    final first = registry.protect(
      '小美來了',
      scope: 'first:message',
      maskImportNames: true,
    );
    final second = registry.protect(
      '小美來了',
      scope: 'second:message',
      maskImportNames: true,
    );
    expect(first, isNot(second));
    expect(first, isNot(contains('小美')));
    expect(second, isNot(contains('小美')));
  });

  test('模型不能省略人物代號大括號，原材料的產品代碼與假代號仍當文字', () {
    final person = personaPerson('小明');
    final registry = PersonaTokenRegistry([person], hideNames: true);
    final sent = registry.protect('小明去散步', scope: 'diary');
    registry.validateOutputTokens(sent, sent);
    expect(
      () => registry.validateOutputTokens('PER_01 去散步', sent),
      throwsFormatException,
    );
    expect(
      () => registry.validateOutputTokens('{PER_01} 去散步', sent),
      throwsFormatException,
    );
    final literal = registry.protect(
      '產品 P99 與 {{PER_88}} 字樣',
      scope: 'literal',
    );
    expect(literal, '產品 P99 與 ［PER_88］ 字樣');
    registry.validateOutputTokens(literal, literal);
  });
  test('不同內容的同名代號不混人，同一人物的姓名與代號共用外送識別', () {
    final a = personaPerson('小明');
    final b = personaPerson('小華');
    final registry = PersonaTokenRegistry([a, b], hideNames: true);
    final first = registry.protect(
      '和{{PER_01}}去旅行',
      scope: 'card:memory',
      tokens: {'{{PER_01}}': a.id},
    );
    final second = registry.protect(
      '{{PER_01}}喜歡聊天',
      scope: 'card:tone',
      tokens: {'{{PER_01}}': b.id},
    );
    expect(first, contains(registry.person(a.id)));
    expect(second, contains(registry.person(b.id)));
    expect(registry.person(a.id), isNot(registry.person(b.id)));
    expect(
      registry.protect('小明和小華', scope: 'diary'),
      '${registry.person(a.id)}和${registry.person(b.id)}',
    );
    expect(
      registry.protectEvidence('小明和${registry.person(b.id)}'),
      '${registry.person(a.id)}和${registry.person(b.id)}',
    );
    expect(
      () => registry.validateOutputTokens('{{PER_99}}', first),
      throwsFormatException,
    );
  });

  test('匿名人物不因兩個空對應而合併，候選仍保留原有對照', () {
    final registry = PersonaTokenRegistry([], hideNames: true);
    final a = registry.protect(
      '{{PER_01}}',
      scope: 'card:memory',
      tokens: {'{{PER_01}}': null},
    );
    final b = registry.protect(
      '{{PER_01}}',
      scope: 'card:tone',
      tokens: {'{{PER_01}}': null},
    );
    expect(a, isNot(b));
    final current = PersonaCard(
      text: '{{PER_01}}',
      tokens: {'{{PER_01}}': null},
      updatedAt: DateTime.now(),
      selectedDiaryIds: [],
    );
    expect(registry.candidate(a, PersonaCardKind.memory, current).tokens, {
      '{{PER_01}}': null,
    });
  });

  test('目前內容同樣套用手動圈選，不保存私密原文或允許未知輸出代號', () {
    final registry = PersonaTokenRegistry([], hideNames: true);
    final protected = registry.protect(
      '電話0900123456',
      scope: 'card:memory',
      ranges: [const PrivateTextRange(2, 12)],
    );
    expect(protected, '電話{{PRI_01}}');
    expect(
      registry.protect(
        '另一支0900123456',
        scope: 'again',
        ranges: [const PrivateTextRange(3, 13)],
      ),
      '另一支{{PRI_01}}',
    );
    expect(
      () => registry.validateOutputTokens('{{PER_99}}', protected),
      throwsFormatException,
    );
    expect(
      () => registry.validateOutputTokens('{{PRI_01}}', protected),
      throwsFormatException,
    );
    expect(
      () => PersonaCandidate(text: 'x' * 8001).validate(PersonaCardKind.memory),
      throwsFormatException,
    );
  });

  test('UTF16 圈選保留換行與組合字，拒絕切開 Emoji surrogate pair', () {
    const text = '甲😀\ne\u0301乙';
    validatePersonaRanges(text, [
      const PrivateTextRange(1, 3),
      const PrivateTextRange(4, 6),
    ]);
    expect(
      () => validatePersonaRanges(text, [const PrivateTextRange(1, 2)]),
      throwsFormatException,
    );
    expect(
      () => validatePersonaRanges(text, [const PrivateTextRange(4, 5)]),
      throwsFormatException,
    );
    final expanded = personaSelectionRange('甲👨‍👩‍👧‍👦乙', 2, 4);
    expect(expanded.start, 1);
    expect(expanded.end, 12);
    expect(
      () => validatePersonaRanges(text, [const PrivateTextRange(-1, 1)]),
      throwsFormatException,
    );
    final registry = PersonaTokenRegistry([], hideNames: true);
    expect(
      registry.protect(
        text,
        scope: 'diary',
        ranges: [const PrivateTextRange(1, 3)],
      ),
      '甲{{PRI_01}}\ne\u0301乙',
    );
  });

  test('匯入指定的名字會換成代號，沒有要求時不改原文', () {
    final registry = PersonaTokenRegistry([], hideNames: false);
    registry.replaceImportNames(['小美', '阿哲']);
    final sent = registry.protect(
      '小美說阿哲好',
      scope: 'chat',
      maskImportNames: true,
    );
    expect(sent.contains('小美'), isFalse);
    expect(sent.contains('阿哲'), isFalse);
    expect(sent, contains(registry.anonymous('import:小美')));
    expect(sent, contains(registry.anonymous('import:阿哲')));
    expect(registry.protect('小美說阿哲好', scope: 'diary'), '小美說阿哲好');
    registry.replaceImportNames(['Ann']);
    final partial = registry.protect(
      'Ann 與 Anne',
      scope: 'chat',
      maskImportNames: true,
    );
    expect(partial.contains('Ann '), isFalse);
    expect(partial, contains('Anne'));
    expect(partial, contains(registry.anonymous('import:Ann')));
  });

  test('原文匯入的目標對象名字換成人物代號，其他人名仍是匯入代號', () {
    final registry = PersonaTokenRegistry([], hideNames: false);
    const personId = 'per_subject';
    registry.bindSubjectImportNames(personId, ['小明']);
    registry.replaceImportNames(['小美']);
    final sent = registry.protect('小明約小美', scope: 'raw', maskImportNames: true);
    expect(sent.contains('小明'), isFalse);
    expect(sent.contains('小美'), isFalse);
    expect(sent, contains(registry.person(personId)));
    expect(sent, contains(registry.anonymous('import:小美')));
  });

  test('取消的人名保留原文，已登錄後模型回覆該名不再拒絕', () {
    final person = personaPerson('小明');
    final registry = PersonaTokenRegistry([person], hideNames: true);
    const text = '小明又見小明';
    final shown = registry.protect(
      text,
      scope: 'diary',
      revealedRanges: const [PrivateTextRange(0, 2)],
    );
    expect(shown, startsWith('小明'));
    expect(shown.substring(2), isNot(contains('小明')));
    expect(shown, contains(registry.person(person.id)));
    expect(registry.protectEvidence('小明回來'), '${registry.person(person.id)}回來');
    final fresh = PersonaTokenRegistry([person], hideNames: true);
    expect(
      fresh.protectEvidence(
        '小明回來',
        revealedRanges: const [PrivateTextRange(0, 2)],
      ),
      '小明回來',
    );
    expect(() => fresh.protectEvidence('小明回來'), throwsFormatException);
  });
}
