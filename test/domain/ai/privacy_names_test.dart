import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/privacy_names.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/person_name_matcher.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';

void main() {
  Person named(String id, String name) => Person(
    id: id,
    name: name,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('可確定的人名換成人物代號，重名與手動選取換成私密代號', () {
    final ledger = PrivacyLedger(originals: {});
    final matcher = PersonNameMatcher([
      named('ming', '小明'),
      named('a', '阿嘉'),
      named('b', '阿嘉'),
    ]);
    const text = '小明見阿嘉，秘密';
    final hits = personNameRanges(text, matcher);
    expect(hits.people.single.personId, 'ming');
    expect(hits.ambiguous.map((range) => (range.start, range.end)), [(3, 5)]);

    final hidden = protectNamedText(
      ledger.processor(),
      text,
      manualRanges: [const PrivateTextRange(6, 8)],
      people: hits.people,
      ambiguous: hits.ambiguous,
      distinctSelections: true,
    );
    expect(hidden.text, '{{PER_01}}見{{PRI_02}}，{{PRI_01}}');
    expect(privacyTokenHasKind('{{PER_01}}', PrivacyTokenKind.person), isTrue);
    expect(ledger.personTokens['ming'], '{{PER_01}}');
  });

  test('關閉人名掃描時保留原文，只隱藏手動選取', () {
    final ledger = PrivacyLedger(originals: {});
    final hidden = protectNamedText(
      ledger.processor(),
      '小明的秘密',
      manualRanges: [const PrivateTextRange(3, 5)],
    );
    expect(hidden.text, '小明的{{PRI_01}}');
    expect(ledger.personTokens, isEmpty);
  });

  test('與姓名完全相同的手動選取仍是人物代號，包住其他文字時是私密代號', () {
    final matcher = PersonNameMatcher([named('ming', '小明')]);
    final exact = protectNamedText(
      PrivacyLedger(originals: {}).processor(),
      '小明',
      manualRanges: const [PrivateTextRange(0, 2)],
      nameMatcher: matcher,
    );
    expect(exact.text, '{{PER_01}}');

    final wrapped = protectNamedText(
      PrivacyLedger(originals: {}).processor(),
      '小明啊',
      manualRanges: const [PrivateTextRange(0, 3)],
      nameMatcher: matcher,
    );
    expect(wrapped.text, '{{PRI_01}}');
  });
}
