import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/privacy_text_processor.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/person_name_matcher.dart';

Person _person(String id, String name) => Person(
  id: id,
  name: name,
  createdAt: DateTime.utc(2026, 11, 16),
  updatedAt: DateTime.utc(2026, 11, 16),
);

void main() {
  test('已取消的自動區間不再遮罩 email，人名與手動區間仍照舊', () {
    const text = '寫給 a+b@example.org';
    final email = PrivateTextRange(3, 3 + 'a+b@example.org'.length);
    final processor = PrivacyTextProcessor({});
    final hidden = processor.protect(text);
    expect(hidden.text, isNot(contains('a+b@example.org')));

    final shown = processor.protect(text, revealedRanges: [email]);
    expect(shown.text, text);
    expect(shown.revealedSecrets, {'a+b@example.org'});
    expect(privacyHighlightRanges(text, revealedRanges: [email]), isEmpty);

    final manual = processor.protect(
      text,
      manualRanges: const [PrivateTextRange(0, 2)],
      revealedRanges: [email],
    );
    expect(manual.text, startsWith('{{PRI_'));
    expect(manual.text, contains('a+b@example.org'));
  });

  test('取消的人名只保留這一處，同名其他出現與明確人物仍會遮罩', () {
    const text = '王小明找王小明';
    const first = PrivateTextRange(0, 3);
    final matcher = PersonNameMatcher([_person('p1', '王小明')]);
    final processor = PrivacyTextProcessor({});
    final shown = processor.protect(
      text,
      nameMatcher: matcher,
      revealedRanges: const [first],
    );
    expect(shown.text, startsWith('王小明'));
    expect(shown.text.substring(3), isNot(contains('王小明')));
    expect(
      shown.personRanges.map(
        (range) => (range.start, range.end, range.personId),
      ),
      [(4, 7, 'p1')],
    );
    expect(
      privacyHighlightRanges(
        text,
        revealedRanges: const [first],
        nameMatcher: matcher,
      ).map((range) => (range.start, range.end)),
      [(4, 7)],
    );

    final explicit = processor.protect(
      '王小明',
      people: const [PersonTextRange(0, 3, 'p1')],
      revealedRanges: const [first],
    );
    expect(explicit.text, '王小明');
    expect(explicit.personRanges, isEmpty);
  });
}
