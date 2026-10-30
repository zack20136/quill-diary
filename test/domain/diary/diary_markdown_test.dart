import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/diary/diary_markdown.dart';

void main() {
  test('任務偵測支援各種換行與大小寫勾選，普通清單保持純文字', () {
    for (final lineBreak in ['\n', '\r\n', '\r']) {
      expect(markdownHasCheckboxLines('前言$lineBreak  - [X] 已完成'), isTrue);
      expect(markdownHasCheckboxLines('前言$lineBreak- [ ] 未完成'), isTrue);
      expect(markdownHasCheckboxLines('前言$lineBreak- 買鉛筆'), isFalse);
    }
  });

  test('searchableTextFromMarkdown 會移除任務清單標記但保留項目文字', () {
    const String markdown =
        '莉莉絲之毯\n'
        '- [x] 5446456\n'
        '- [x] 564\n'
        '- [ ] 545645645\n'
        '- [x] 456454';

    expect(
      searchableTextFromMarkdown(markdown),
      '莉莉絲之毯 5446456 564 545645645 456454',
    );
  });

  test('previewLinesFromMarkdown 會保留任務項目勾選狀態', () {
    const String markdown =
        '前言\n'
        '- [x] 已完成\n'
        '- [ ] 任務三';

    final List<MarkdownPreviewLine> lines = previewLinesFromMarkdown(markdown);

    expect(lines, hasLength(3));
    expect(lines[0], isA<MarkdownPreviewTextLine>());
    expect(lines[1], isA<MarkdownPreviewCheckboxLine>());
    expect((lines[1] as MarkdownPreviewCheckboxLine).checked, isTrue);
    expect((lines[2] as MarkdownPreviewCheckboxLine).checked, isFalse);
  });
}
