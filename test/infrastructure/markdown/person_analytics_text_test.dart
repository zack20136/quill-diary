import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/markdown/visible_text_from_markdown.dart';

void main() {
  group('EntryIndexText.visibleText', () {
    test('保留連結可見文字並丟棄 destination', () {
      expect(
        EntryIndexText.fromMarkdown('見 [小明](https://example.com)').visibleText,
        '見 小明',
      );
    });

    test('忽略 fenced code 與 inline code', () {
      expect(
        EntryIndexText.fromMarkdown('前\n```\n小明\n```\n後 `小華` 完').visibleText,
        '前 後 完',
      );
    });
  });
}
