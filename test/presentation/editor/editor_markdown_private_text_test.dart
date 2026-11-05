import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_markdown_preview.dart';
import 'package:quill_diary/shared/presentation/widgets/private_text.dart';

import '../../helpers/shared/widget_test_app.dart';

void main() {
  for (final example in [
    (source: '# 前QA小明🙂後', visible: '前QA小明🙂後'),
    (source: '> 前**QA小明🙂**後', visible: '前QA小明🙂後'),
    (source: '  - 前_QA小明🙂_後', visible: '前QA小明🙂後'),
    (source: '12. 前QA小明🙂後', visible: '前QA小明🙂後'),
    (source: '- [x] 前QA小明🙂後', visible: '前QA小明🙂後'),
    (source: '前__QA小明🙂__後', visible: '前QA小明🙂後'),
    (source: '前[QA小明🙂](example.com)後', visible: '前QA小明🙂 (example.com)後'),
    (source: '前[連結](QA小明🙂)後', visible: '前連結 (QA小明🙂)後'),
    (source: '前`QA小明🙂`後', visible: '前QA小明🙂後'),
    (source: '```txt\r\n前QA小明🙂後  \r\n```', visible: '前QA小明🙂後'),
  ]) {
    testWidgets('Markdown 語法移除後仍準確高亮：${example.source}', (tester) async {
      final start = example.source.indexOf('QA小明🙂');
      await tester.pumpWidget(
        widgetTestApp(
          child: EditorMarkdownPreview(
            markdown: example.source,
            typography: EditorTypographyPreferences.defaults,
            privateRanges: [PrivateTextRange(start, start + 'QA小明🙂'.length)],
          ),
        ),
      );
      final text = tester.widget<PrivateText>(find.byType(PrivateText));
      expect(text.text, example.visible);
      expect(
        text.ranges
            .map((range) => text.text.substring(range.start, range.end))
            .join(),
        'QA小明🙂',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('跨格式與 CRLF 的隱藏區間分配到各段可見文字，新增標點不被標記', (tester) async {
    const markdown = '# 小明**與**秘密\r\n> [標籤](example.com)\r\n- 後文';
    await tester.pumpWidget(
      widgetTestApp(
        child: EditorMarkdownPreview(
          markdown: markdown,
          typography: EditorTypographyPreferences.defaults,
          privateRanges: const [PrivateTextRange(0, markdown.length)],
        ),
      ),
    );
    final texts = tester.widgetList<PrivateText>(find.byType(PrivateText));
    expect(
      texts.map(
        (text) => text.ranges
            .map((range) => text.text.substring(range.start, range.end))
            .join(),
      ),
      ['小明與秘密', '標籤example.com', '後文'],
    );
  });

  testWidgets('行內程式碼保留字型，隱藏區間讓出底色，更新串流文字時不沿用舊區間', (tester) async {
    Future<void> pump(String source, List<PrivateTextRange> ranges) =>
        tester.pumpWidget(
          widgetTestApp(
            child: EditorMarkdownPreview(
              markdown: source,
              typography: EditorTypographyPreferences.defaults,
              privateRanges: ranges,
            ),
          ),
        );
    await pump('`前秘密後`', const [PrivateTextRange(2, 4)]);
    var text = tester.widget<PrivateText>(find.byType(PrivateText));
    final root =
        tester
                .widget<Text>(
                  find.descendant(
                    of: find.byType(PrivateText),
                    matching: find.byType(Text),
                  ),
                )
                .textSpan!
            as TextSpan;
    final spans = root.children!.cast<TextSpan>();
    expect(spans.map((span) => span.text), ['前', '秘密', '後']);
    expect(spans.elementAt(1).style!.backgroundColor, Colors.transparent);
    expect(spans.first.style!.backgroundColor, isNot(Colors.transparent));
    expect(spans.elementAt(1).style!.fontFamily, spans.first.style!.fontFamily);
    await pump('新增**秘密**完成', const [PrivateTextRange(4, 6)]);
    text = tester.widget<PrivateText>(find.byType(PrivateText));
    expect(text.text, '新增秘密完成');
    expect(text.ranges.map((range) => (range.start, range.end)), [(2, 4)]);
  });
}
