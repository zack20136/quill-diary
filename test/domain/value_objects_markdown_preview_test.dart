import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

void main() {
  test('searchableTextFromMarkdown strips checkbox markers but keeps item text', () {
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

  test('previewLinesFromMarkdown keeps checkbox checked state', () {
    const String markdown =
        '前言\n'
        '- [x] 已完成\n'
        '- [ ] 待辦';

    final List<MarkdownPreviewLine> lines = previewLinesFromMarkdown(markdown);

    expect(lines, hasLength(3));
    expect(lines[0], isA<MarkdownPreviewTextLine>());
    expect(lines[1], isA<MarkdownPreviewCheckboxLine>());
    expect((lines[1] as MarkdownPreviewCheckboxLine).checked, isTrue);
    expect((lines[2] as MarkdownPreviewCheckboxLine).checked, isFalse);
  });
}
