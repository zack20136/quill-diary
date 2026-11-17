import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/shared/presentation/private_text_spans.dart';
import 'package:quill_diary/shared/presentation/widgets/private_text.dart';

import '../../../helpers/shared/widget_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('大字級下中英與代號底色齊高，換行仍對齊原文字', (tester) async {
    const text = 'QA小明 {{PER_01}} Café 阿明🙂\n長段落的私密文字跨行時仍維持自然換行與閱讀順序。';
    final ranges = [
      const PrivateTextRange(0, 4),
      const PrivateTextRange(5, 15),
      PrivateTextRange(16, text.length),
    ];
    final span = TextSpan(
      children: [
        TextSpan(
          text: text.substring(0, 4),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        TextSpan(text: text.substring(4)),
      ],
    );
    await tester.pumpWidget(
      widgetTestApp(
        brightness: Brightness.light,
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: SizedBox(
            width: 420,
            child: SelectionArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PrivateText.rich(
                      span,
                      ranges: ranges,
                      style: const TextStyle(fontSize: 14, height: 1.8),
                    ),
                    Text.rich(
                      span,
                      style: const TextStyle(fontSize: 14, height: 1.8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final highlighted = find.byType(PrivateText);
    final paragraphFinder = find.descendant(
      of: highlighted,
      matching: find.byType(RichText),
    );
    final paragraph = tester.renderObject<RenderParagraph>(paragraphFinder);
    final plain = find.byType(RichText).last;
    expect(tester.getSize(paragraphFinder), tester.getSize(plain));

    final boxes = paragraph.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 15),
      boxHeightStyle: ui.BoxHeightStyle.max,
    );
    // 第一行同時包含英文、中文與表情符號。
    expect(boxes, isNotEmpty);
    expect(boxes.map((b) => b.top).toSet(), hasLength(1));
    expect(boxes.map((b) => b.bottom).toSet(), hasLength(1));
    final corners = <Offset>[];
    for (final range in ranges) {
      for (final box in paragraph.getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end),
        boxHeightStyle: ui.BoxHeightStyle.max,
      )) {
        final rect = box.toRect();
        if (rect.width > 1) {
          corners.addAll([
            rect.topLeft + const Offset(0.5, 0.5),
            rect.bottomRight - const Offset(0.5, 0.5),
          ]);
        }
      }
    }
    expect(
      tester.renderObject(highlighted),
      paints..path(
        color: privateTextHighlight(
          Theme.of(tester.element(highlighted)).colorScheme,
        ),
        includes: corners,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('高亮與底線只設定底色與裝飾，字型沿用父層', () {
    const highlight = Color(0x52FF0000);
    final span = privateTextSpan(
      text: 'ab小明',
      ranges: const [PrivateTextRange(0, 2)],
      highlight: highlight,
      underlineRanges: const [PrivateTextRange(2, 4)],
    );
    final children = span.children!.cast<TextSpan>();
    expect(children, hasLength(2));
    for (final child in children) {
      expect(child.style?.fontFamily, isNull);
      expect(child.style?.fontFamilyFallback, isNull);
    }
    expect(children.first.style?.backgroundColor, highlight);
    expect(children.last.style?.decoration, TextDecoration.underline);
  });
}
