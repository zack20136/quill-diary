import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';

import '../../helpers/shared/widget_test_app.dart';

void main() {
  Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
      widgetTestApp(brightness: brightness, center: false, child: child);

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

  testWidgets('scrollable page body 套用標準留白並可捲動', (WidgetTester tester) async {
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
          child: AppActionGroup(actions: <Widget>[Text('操作一'), Text('操作二')]),
        ),
      ),
    );
    expect(find.byType(AppSectionHeader), findsOneWidget);
    expect(find.byType(AppInsetPanel), findsOneWidget);
    expect(find.text('操作一'), findsOneWidget);
    expect(find.text('操作二'), findsOneWidget);

    final double iconLeft = tester.getTopLeft(find.byIcon(Icons.tune)).dx;
    final double descriptionLeft = tester.getTopLeft(find.text('說明')).dx;
    expect(descriptionLeft, closeTo(iconLeft, 0.5));

    final Finder stripe = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Container &&
          (widget.decoration is BoxDecoration) &&
          (widget.decoration as BoxDecoration).borderRadius != null &&
          widget.constraints?.minWidth == 4,
    );
    final double stripeHeight = tester.getSize(stripe).height;
    final double titleTop = tester.getTopLeft(find.text('標題')).dy;
    final double descriptionBottom = tester.getBottomLeft(find.text('說明')).dy;
    expect(
      stripeHeight,
      greaterThanOrEqualTo(descriptionBottom - titleTop - 1),
    );
  });

  testWidgets('沒有說明且有 trailing 時標題與藍條垂直置中', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        AppSectionCard(
          title: '日記 ‧ 筆記',
          trailing: IconButton(
            onPressed: () {},
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              maximumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.close_rounded),
          ),
          child: const SizedBox.shrink(),
        ),
      ),
    );

    final Finder stripe = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Container &&
          (widget.decoration is BoxDecoration) &&
          (widget.decoration as BoxDecoration).borderRadius != null &&
          widget.constraints?.minWidth == 4,
    );
    final double stripeCenter = tester.getCenter(stripe).dy;
    final double titleCenter = tester.getCenter(find.text('日記 ‧ 筆記')).dy;
    expect(titleCenter, closeTo(stripeCenter, 0.5));
  });

  testWidgets('AppSectionCard 支援 elevated 與 expandChild', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        const SizedBox(
          height: 240,
          child: AppSectionCard(
            title: '可展開',
            style: AppSurfaceStyle.elevated,
            expandChild: true,
            child: ColoredBox(color: Colors.red, child: SizedBox.expand()),
          ),
        ),
      ),
    );

    expect(find.byType(AppSectionHeader), findsOneWidget);
    final AppSectionCard card = tester.widget<AppSectionCard>(
      find.byType(AppSectionCard),
    );
    expect(card.expandChild, isTrue);
    expect(card.style, AppSurfaceStyle.elevated);
  });

  testWidgets('AppSliverSectionCard 會渲染標題與內容 sliver', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        CustomScrollView(
          slivers: <Widget>[
            AppSliverSectionCard(
              title: '日記區段',
              stripeColor: Colors.teal,
              slivers: <Widget>[SliverToBoxAdapter(child: Text('內容列'))],
            ),
          ],
        ),
      ),
    );

    expect(find.text('日記區段'), findsOneWidget);
    expect(find.text('內容列'), findsOneWidget);
    expect(find.byType(AppSectionHeader), findsOneWidget);
  });
}
