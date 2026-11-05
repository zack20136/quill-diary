import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/presentation/ai/ai_message_view.dart';
import 'package:quill_diary/shared/presentation/widgets/private_text.dart';

import '../../helpers/shared/widget_test_app.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('${brightness.name} 字級 $scale 共用泡泡支援窄版、圖片及兩種文字模式', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const text = '**QA小明🙂** 說這段文字會自然換行，保留閱讀順序。';
        await tester.pumpWidget(
          widgetTestApp(
            brightness: brightness,
            overrides: [],
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final format in AiMessageFormat.values)
                      AiMessageView(
                        text: text,
                        isUser: format == AiMessageFormat.plainText,
                        format: format,
                        bodyKey: ValueKey(format),
                        privateRanges: const [PrivateTextRange(2, 8)],
                        images: const [SizedBox(width: 80, height: 50)],
                        header: const Text('角色'),
                        footer: const Text('操作'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        final texts = tester
            .widgetList<PrivateText>(find.byType(PrivateText))
            .toList();
        expect(texts.first.text, text);
        expect(texts.last.text, text.replaceAll('**', ''));
        for (final highlighted in texts) {
          expect(
            highlighted.ranges
                .map(
                  (range) => highlighted.text.substring(range.start, range.end),
                )
                .join(),
            'QA小明🙂',
          );
        }
        for (final format in AiMessageFormat.values) {
          final body = find.byKey(ValueKey(format));
          expect(tester.getSize(body).width, lessThanOrEqualTo(320 * 0.88));
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: body, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          final container = tester.widget<Container>(body);
          final colors = Theme.of(tester.element(body)).colorScheme;
          expect(
            (container.decoration as BoxDecoration).color,
            format == AiMessageFormat.plainText
                ? colors.primaryContainer
                : colors.surfaceContainerHigh,
          );
        }
        expect(find.text('角色'), findsNWidgets(2));
        expect(find.text('操作'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
