import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/widgets/app_option_field.dart';

import '../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('空選取可開啟定寬選單，選取與鍵盤關閉維持同步', (tester) async {
    int? value;
    await tester.pumpWidget(
      widgetTestApp(
        child: StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 260,
            child: AppOptionField<int>(
              key: const ValueKey('field'),
              label: '選項',
              value: value,
              options: const [(1, '第一項'), (2, '第二項')],
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );
    final field = find.byKey(const ValueKey('field'));
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsNothing);
    expect(
      tester.getSize(find.widgetWithText(MenuItemButton, '第二項')).width,
      closeTo(tester.getSize(field).width - 12, 1),
    );
    await tester.tap(find.widgetWithText(MenuItemButton, '第二項'));
    await tester.pumpAndSettle();
    expect(value, 2);
    expect(find.byType(MenuItemButton), findsNothing);
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.widgetWithText(MenuItemButton, '第二項'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(value, 2);
  });

  testWidgets('沒有選項或停用時不開選單', (tester) async {
    await tester.pumpWidget(
      widgetTestApp(
        child: Column(
          children: [
            AppOptionField<int>(
              key: const ValueKey('empty'),
              label: '空清單',
              value: null,
              options: const [],
              onChanged: (_) => fail('空清單不可選取'),
            ),
            const AppOptionField<int>(
              key: ValueKey('disabled'),
              label: '停用',
              value: 1,
              options: [(1, '第一項')],
              onChanged: null,
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('empty')));
    await tester.tap(find.byKey(const ValueKey('disabled')));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
