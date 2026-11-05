import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/shared/presentation/private_text_spans.dart';
import 'package:quill_diary/shared/presentation/widgets/private_text.dart';

import '../../../helpers/shared/widget_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final font in ['Inter', 'NotoSansTC']) {
      await (FontLoader(
        font,
      )..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf'))).load();
    }
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('${brightness.name} 字級 $scale 中英與代號底色齊高，換行仍對齊原文字', (
        tester,
      ) async {
        const text = 'QA小明 ⟦P01⟧ Café 阿明🙂\n長段落的私密文字跨行時仍維持自然換行與閱讀順序。';
        final ranges = [
          const PrivateTextRange(0, 4),
          const PrivateTextRange(5, 10),
          PrivateTextRange(11, text.length),
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
            brightness: brightness,
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SizedBox(
                width: 220,
                child: SelectionArea(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PrivateText.rich(
                          span,
                          ranges: ranges,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontFamilyFallback: ['NotoSansTC'],
                            fontSize: 14,
                            height: 1.8,
                          ),
                        ),
                        Text.rich(
                          span,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontFamilyFallback: ['NotoSansTC'],
                            fontSize: 14,
                            height: 1.8,
                          ),
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
          const TextSelection(baseOffset: 0, extentOffset: 10),
          boxHeightStyle: ui.BoxHeightStyle.max,
        );
        // 第一行同時包含 Inter、中文及代號括號的替補字型。
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
    }
  }
}
