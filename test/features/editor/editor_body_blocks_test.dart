import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/editor/application/editor_body_blocks.dart';

void main() {
  test('parseEditorBodyLines splits each markdown line into a line block', () {
    const String markdown =
        '今天心情不錯\n\n- [ ] 買牛奶\n- [x] 回覆信件\n\n明天再整理';

    final List<EditorBodyLine> lines = parseEditorBodyLines(markdown);
    expect(lines, hasLength(6));
    expect(lines[0], isA<EditorTextLine>());
    expect((lines[0] as EditorTextLine).text, '今天心情不錯');
    expect(lines[1], isA<EditorTextLine>());
    expect((lines[1] as EditorTextLine).text, isEmpty);
    expect(lines[2], isA<EditorCheckboxLine>());
    expect((lines[2] as EditorCheckboxLine).text, '買牛奶');
    expect((lines[2] as EditorCheckboxLine).checked, isFalse);
    expect(lines[3], isA<EditorCheckboxLine>());
    expect((lines[3] as EditorCheckboxLine).text, '回覆信件');
    expect((lines[3] as EditorCheckboxLine).checked, isTrue);
    expect(lines[5], isA<EditorTextLine>());
    expect((lines[5] as EditorTextLine).text, '明天再整理');
  });

  test('serializeEditorBodyLines round-trips line markdown', () {
    final List<EditorBodyLine> lines = <EditorBodyLine>[
      EditorTextLine(id: 't1', text: '前言'),
      EditorCheckboxLine(id: 'c1', text: '任務一', checked: false),
      EditorCheckboxLine(id: 'c2', text: '任務二', checked: true),
      EditorTextLine(id: 't2', text: '結尾'),
    ];

    final String markdown = serializeEditorBodyLines(lines);
    expect(
      markdown,
      '前言\n'
      '- [ ] 任務一\n'
      '- [x] 任務二\n'
      '結尾',
    );

    final List<EditorBodyLine> reparsed = parseEditorBodyLines(markdown);
    expect(reparsed.whereType<EditorCheckboxLine>(), hasLength(2));
    expect((reparsed[0] as EditorTextLine).text, '前言');
    expect((reparsed.last as EditorTextLine).text, '結尾');
  });

  group('insertCheckboxAtLineIndex', () {
    test('在游標處切分文字行', () {
      final ({List<EditorBodyLine> lines, String checkboxId}) result =
          insertCheckboxAtLineIndex(
        lines: <EditorBodyLine>[
          EditorTextLine(id: 't1', text: '15651'),
          EditorCheckboxLine(id: 'c1', text: '111', checked: true),
          EditorTextLine(id: 't2', text: '456456'),
        ],
        lineIndex: 2,
        textOffset: 3,
      );

      expect(result.lines, hasLength(5));
      expect((result.lines[2] as EditorTextLine).text, '456');
      expect(result.lines[3], isA<EditorCheckboxLine>());
      expect((result.lines[4] as EditorTextLine).text, '456');
    });

    test('插入 checkbox 後保留可輸入的尾端空白文字行', () {
      final ({List<EditorBodyLine> lines, String checkboxId}) result =
          insertCheckboxAtLineIndex(
        lines: <EditorBodyLine>[
          EditorTextLine(id: 't1', text: '前言'),
        ],
        lineIndex: 0,
        textOffset: 2,
      );

      expect(result.lines, hasLength(3));
      expect((result.lines[0] as EditorTextLine).text, '前言');
      expect(result.lines[1], isA<EditorCheckboxLine>());
      expect((result.lines[2] as EditorTextLine).text, isEmpty);
      expect(serializeEditorBodyLines(result.lines), '前言\n- [ ]\n');
    });
  });

  test('reorderEditorBodyLines can swap checkbox and text lines', () {
    final List<EditorBodyLine> lines = <EditorBodyLine>[
      EditorTextLine(id: 't1', text: '文字'),
      EditorCheckboxLine(id: 'c1', text: '待辦', checked: false),
      EditorTextLine(id: 't2', text: '結尾'),
    ];

    final List<EditorBodyLine> reordered = reorderEditorBodyLines(
      lines: lines,
      oldIndex: 0,
      newIndex: 1,
      newIndexAlreadyAdjusted: true,
    );

    expect(reordered[0], isA<EditorCheckboxLine>());
    expect((reordered[1] as EditorTextLine).text, '文字');
    expect((reordered[2] as EditorTextLine).text, '結尾');
  });

  test('normalizeEditorBodyMarkdownForSave keeps trailing blank line', () {
    const String markdown = '前言\n- [ ] 待辦';
    final String normalized = normalizeEditorBodyMarkdownForSave(markdown);
    expect(normalized, '前言\n- [ ] 待辦\n');
    expect(parseEditorBodyLines(normalized).last, isA<EditorTextLine>());
    expect((parseEditorBodyLines(normalized).last as EditorTextLine).text, isEmpty);
  });
}
