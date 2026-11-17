import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';

void main() {
  test('人物與私密片段分開編號，使用至少兩位的大寫十六進位', () {
    expect(nextPrivacyToken([]), '{{PRI_01}}');
    expect(nextPrivacyToken(['{{PER_09}}', '{{PRI_09}}']), '{{PRI_0A}}');
    expect(
      nextPrivacyToken([
        '{{PER_09}}',
        '{{PRI_FF}}',
      ], kind: PrivacyTokenKind.person),
      '{{PER_0A}}',
    );
    expect(nextPrivacyToken(['{{PRI_FF}}']), '{{PRI_100}}');
  });

  test('同一人物的重複與別名共用代號，不覆蓋第一次的寫法', () {
    final tokens = <String, String>{};
    final originals = <String, String>{};
    expect(
      privacyTokenForPerson(
        personId: 'ming',
        surface: '王小明',
        tokenByPersonId: tokens,
        originals: originals,
      ),
      '{{PER_01}}',
    );
    expect(
      privacyTokenForPerson(
        personId: 'ming',
        surface: '小明',
        tokenByPersonId: tokens,
        originals: originals,
      ),
      '{{PER_01}}',
    );
    expect(originals, {'{{PER_01}}': '王小明'});
    expect(
      privacyTokenForPerson(
        personId: 'hua',
        surface: '小華',
        tokenByPersonId: tokens,
        originals: originals,
      ),
      '{{PER_02}}',
    );
  });

  test('避開原文中的代號，不重用已分配的編號', () {
    expect(
      nextPrivacyToken(['{{PRI_01}}'], reservedText: '包含{{PRI_02}}'),
      '{{PRI_03}}',
    );
  });

  test('外送代號與隱藏標記不會互相誤判', () {
    expect(privacyTokenPattern.hasMatch('{{已隱藏}}'), isFalse);
    expect(privacyTokenPattern.stringMatch('{{PER_0A}}'), '{{PER_0A}}');
    expect(privacyTokenPattern.stringMatch('{{PRI_0A}}'), '{{PRI_0A}}');
    expect(privacyTokenPattern.hasMatch('{{P0A}}'), isFalse);
    expect(privacyTokenPattern.hasMatch('{PER_0A}'), isFalse);
    expect(privacyTokenPattern.hasMatch('{{PER_0a}}'), isFalse);
    expect(privacyTokenPattern.hasMatch('⟦PER_0A⟧'), isFalse);
    expect(PrivacyToken.parse('{{PER_0A}}').number, 10);
    expect(PrivacyToken.parse('{{PRI_0A}}').kind, PrivacyTokenKind.private);
  });
}
