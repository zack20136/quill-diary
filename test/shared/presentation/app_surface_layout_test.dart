import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';

import '../../helpers/app_test_theme.dart';

void main() {
  Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        theme: appTestTheme(brightness: brightness),
        home: Scaffold(body: child),
      );

  for (final Brightness brightness in Brightness.values) {
    testWidgets('三種 surface style 在 ${brightness.name} 主題可正確組合', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          const Column(
            children: <Widget>[
              AppCard(
                key: Key('outlined'),
                style: AppSurfaceStyle.outlined,
                child: Text('描邊'),
              ),
              AppCard(
                key: Key('elevated'),
                style: AppSurfaceStyle.elevated,
                child: Text('陰影'),
              ),
              AppCard(
                key: Key('combined'),
                style: AppSurfaceStyle.outlinedElevated,
                backgroundColor: Colors.amber,
                radius: 12,
                child: Text('組合'),
              ),
            ],
          ),
          brightness: brightness,
        ),
      );

      final Material outlined = tester.widget<Material>(
        find.descendant(
          of: find.byKey(const Key('outlined')),
          matching: find.byType(Material),
        ),
      );
      final Material elevated = tester.widget<Material>(
        find.descendant(
          of: find.byKey(const Key('elevated')),
          matching: find.byType(Material),
        ),
      );
      final Material combined = tester.widget<Material>(
        find.descendant(
          of: find.byKey(const Key('combined')),
          matching: find.byType(Material),
        ),
      );
      expect(outlined.elevation, 0);
      expect(elevated.elevation, 1);
      expect(combined.elevation, 1);
      expect(combined.color, Colors.amber);
      expect(combined.borderRadius, BorderRadius.circular(12));
    });
  }

  testWidgets('scrollable page body 套用標準留白並可捲動', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      host(
        AppScrollablePageBody(
          children: List<Widget>.generate(
            30,
            (int index) => SizedBox(height: 48, child: Text('項目 $index')),
          ),
        ),
      ),
    );

    expect(find.byType(SafeArea), findsOneWidget);
    expect(find.byType(AppScrollbar), findsOneWidget);
    final Offset firstPosition = tester.getTopLeft(find.text('項目 0'));
    expect(firstPosition.dx, PageStyle.pageHorizontalPadding);
    expect(firstPosition.dy, PageStyle.pageTopPadding);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('項目 0'), findsNothing);
  });

  testWidgets('section 與 action group 共用一致的 surface 結構', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AppSectionCard(
          title: '標題',
          description: '說明',
          icon: Icons.tune,
          child: AppActionGroup(
            actions: <Widget>[Text('操作一'), Text('操作二')],
          ),
        ),
      ),
    );
    expect(find.byType(AppSectionHeader), findsOneWidget);
    expect(find.byType(AppInsetPanel), findsOneWidget);
    expect(find.text('操作一'), findsOneWidget);
    expect(find.text('操作二'), findsOneWidget);
  });
}
