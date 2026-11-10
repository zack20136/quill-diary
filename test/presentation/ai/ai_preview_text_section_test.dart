import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/presentation/ai/ai_preview_text_section.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';

import '../../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('長文展開後可拖曳位置提示，短文沒有可捲範圍', (tester) async {
    await tester.pumpWidget(
      widgetTestApp(
        overrides: [
          personalizationPreferencesProvider.overrideWith(
            _FixedPersonalization.new,
          ),
        ],
        viewport: const Size(320, 640),
        child: Column(
          children: [
            AiPreviewTextSection(
              key: ValueKey('long'),
              title: '生成日記系統提示詞',
              text: '今天走了很久，想把這段留下。\n' * 40,
              initiallyExpanded: true,
            ),
            SizedBox(height: 12),
            AiPreviewTextSection(
              key: ValueKey('short'),
              title: '聊天系統提示詞',
              text: '短短一句。',
              initiallyExpanded: true,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RawScrollbar), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('long')),
        matching: find.byKey(const ValueKey('app-scrollbar-thumb')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('short')),
        matching: find.byKey(const ValueKey('app-scrollbar-thumb')),
      ),
      findsNothing,
    );

    final long = find.byKey(const ValueKey('long'));
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: long, matching: find.byType(Scrollable)),
        )
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    final before = position.pixels;
    final rect = tester.getRect(
      find.descendant(of: long, matching: find.byType(AppScrollbar)),
    );
    final gesture = await tester.startGesture(
      Offset(rect.left + 4, rect.bottom - 4),
    );
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    final delta = position.pixels - before;
    await gesture.up();
    expect(delta, greaterThan(20));
    expect(delta, lessThan(160));

    final double beforeThumb = position.pixels;
    await tester.drag(
      find.descendant(
        of: long,
        matching: find.byKey(const ValueKey('app-scrollbar-thumb')),
      ),
      const Offset(0, 40),
    );
    await tester.pump();
    expect(position.pixels, greaterThan(beforeThumb));

    final short = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey('short')),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(short.maxScrollExtent, 0);
  });
}

class _FixedPersonalization extends PersonalizationPreferencesController {
  @override
  Future<PersonalizationPreferences> build() async =>
      PersonalizationPreferences.defaults;
}
