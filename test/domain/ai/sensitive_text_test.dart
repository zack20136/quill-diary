import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/privacy_text_processor.dart';
import 'package:quill_diary/domain/ai/sensitive_text.dart';

void main() {
  test('台灣電話與電子郵件支援國碼、分隔符、分機及加號', () {
    const text =
        '😀 0912-345-678、+886 912 345 678、02-2345-6789 分機 123、a+b@sub.example.org';
    final spans = detectSensitiveText(text);
    expect(spans.map((span) => text.substring(span.start, span.end)), [
      '0912-345-678',
      '+886 912 345 678',
      '02-2345-6789 分機 123',
      'a+b@sub.example.org',
    ]);
  });

  test('身分證與信用卡驗證檢查碼，無效編號及單一重複數字不遮罩', () {
    const text =
        'A123456789 A123456788 4111-1111-1111-1111 4111-1111-1111-1112 0000000000000000';
    final spans = detectSensitiveText(text);
    expect(spans.map((span) => text.substring(span.start, span.end)), [
      'A123456789',
      '4111-1111-1111-1111',
    ]);
  });

  test('憑證、跨行私鑰與重疊電子郵件只替換完整命中', () {
    const text =
        'api_key: sk-abcdefghijklmnop1234\n-----BEGIN PRIVATE KEY-----\n合成資料\n-----END PRIVATE KEY-----\npassword: foo@example.org';
    final spans = detectSensitiveText(text);
    expect(spans, hasLength(3));
    final originals = <String, String>{};
    final hidden = PrivacyTextProcessor(originals).protect(text).text;
    expect(hidden, isNot(contains('abcdefghijklmnop')));
    expect(hidden, isNot(contains('foo@example.org')));
    expect(originals.values, contains('foo@example.org'));
  });

  test('一般短訊息、表情與既有代號不因隱私處理被刪除', () {
    const text = '好 ❤️\n{{PER_01}} 產品 abc123';
    expect(PrivacyTextProcessor({}).protect(text).text, text);
  });
}
