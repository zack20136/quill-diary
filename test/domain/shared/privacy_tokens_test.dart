import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';

void main() {
  test('人物與私密片段分開編號，使用至少兩位的大寫十六進位', () {
    expect(nextPrivacyToken([]), '⟦S01⟧');
    expect(nextPrivacyToken(['⟦P09⟧', '⟦S09⟧']), '⟦S0A⟧');
    expect(nextPrivacyToken(['⟦P09⟧', '⟦SFF⟧'], prefix: 'P'), '⟦P0A⟧');
    expect(nextPrivacyToken(['⟦SFF⟧']), '⟦S100⟧');
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
      '⟦P01⟧',
    );
    expect(
      privacyTokenForPerson(
        personId: 'ming',
        surface: '小明',
        tokenByPersonId: tokens,
        originals: originals,
      ),
      '⟦P01⟧',
    );
    expect(originals, {'⟦P01⟧': '王小明'});
    expect(
      privacyTokenForPerson(
        personId: 'hua',
        surface: '小華',
        tokenByPersonId: tokens,
        originals: originals,
      ),
      '⟦P02⟧',
    );
  });

  test('避開原文中的代號，不重用已分配的編號', () {
    expect(nextPrivacyToken(['⟦S01⟧'], reservedText: '包含⟦S02⟧'), '⟦S03⟧');
  });
}
