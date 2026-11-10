import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_content.dart';

void main() {
  test('草稿文字允許尚未完成，但已保存的人物對照不能含無效代號', () {
    expect(
      () => PersonaCandidate.fromJson({
        'text': '⟦PXY⟧',
        'person_tokens': {'⟦PXY⟧': null},
      }),
      throwsFormatException,
    );
    final literal = PersonaCandidate.fromJson({
      'text': '尚未完成 ⟦PXY⟧',
      'person_tokens': <String, String?>{},
    });
    expect(literal.text, '尚未完成 ⟦PXY⟧');
  });

  test('本機姓名呈現保留原文，重複代號與不同匿名人物不混淆', () {
    final card = PersonaCandidate(
      text: '⟦P01⟧與⟦P02⟧、⟦P03⟧又遇到⟦P01⟧。',
      tokens: {'⟦P01⟧': 'a', '⟦P02⟧': null, '⟦P03⟧': null},
    );
    final visible = PersonaContent(card, {
      'a': '王小明',
    }, unknownPerson: (n) => '其他人物$n');
    expect(visible.text, '王小明與其他人物2、其他人物3又遇到王小明。');
    expect(visible.source, card.text);
    expect(visible.hasUnresolvedReferences, isFalse);
    final legacy = PersonaContent(
      PersonaCandidate(text: '與 P01 散步'),
      {},
      unknownPerson: (n) => '其他人物$n',
    );
    expect(legacy.text, '與 P01 散步');
    expect(legacy.hasUnresolvedReferences, isTrue);
  });

  test('姓名與代號長度不同仍能雙向轉換隱藏座標，部分姓名會涵蓋完整人物', () {
    final content = PersonaContent(
      PersonaCandidate(text: '甲😀⟦P01⟧\ne\u0301乙', tokens: {'⟦P01⟧': 'a'}),
      {'a': '小明'},
      unknownPerson: (n) => '其他人物$n',
    );
    expect(content.text, '甲😀小明\ne\u0301乙');
    final visible = content.visibleRanges([
      const PrivateTextRange(3, 8),
      const PrivateTextRange(9, 11),
    ]);
    expect(visible.map((r) => [r.start, r.end]).toList(), [
      [3, 5],
      [6, 8],
    ]);
    final source = content.sourceRanges(visible);
    expect(source.map((r) => [r.start, r.end]).toList(), [
      [3, 8],
      [9, 11],
    ]);
    final partial = content.sourceRanges([const PrivateTextRange(4, 5)]).single;
    expect([partial.start, partial.end], [3, 8]);
  });
}
