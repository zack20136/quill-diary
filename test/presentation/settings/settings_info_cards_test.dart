import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/presentation/settings/widgets/settings_info_cards.dart';
import 'package:quill_diary/presentation/settings/widgets/settings_sections.dart';

import '../../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('事實 chip 使用繁中冒號分隔標籤與數值', (WidgetTester tester) async {
    await tester.pumpWidget(
      widgetTestApp(
        child: const SettingsFactChip(label: '提示', value: 'ABCD'),
      ),
    );

    expect(find.text('提示：ABCD'), findsOneWidget);
    expect(find.textContaining('嚗'), findsNothing);
  });

  testWidgets('Hero 標題接在 icon 右側並垂直置中', (WidgetTester tester) async {
    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: SettingsGradientHeroCard(
            icon: Icons.edit_note_rounded,
            title: '寫作、暫存與正式保存各走自己的路',
            body: '說明文字',
            chips: <String>['可匯出 Markdown', '自動草稿'],
          ),
        ),
      ),
    );

    final Offset iconCenter = tester.getCenter(
      find.byIcon(Icons.edit_note_rounded),
    );
    final Offset titleCenter = tester.getCenter(
      find.text('寫作、暫存與正式保存各走自己的路'),
    );

    expect(titleCenter.dx, greaterThan(iconCenter.dx));
    expect((titleCenter.dy - iconCenter.dy).abs(), lessThan(8));
    expect(find.text('可匯出 Markdown'), findsOneWidget);
    expect(find.text('自動草稿'), findsOneWidget);
  });

  testWidgets('Hero chips 單列可橫向捲動並顯示指示條', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: SettingsGradientHeroCard(
            icon: Icons.menu_book_rounded,
            title: '標題',
            body: '說明',
            chips: <String>[
              '資料留在裝置',
              '完整加密備份',
              '全文搜尋',
              '可攜式匯出',
              'Markdown / HTML',
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(Scrollbar), findsNothing);
    expect(find.byType(Wrap), findsNothing);

    final double firstTop = tester.getTopLeft(find.text('資料留在裝置')).dy;
    final double lastTop = tester.getTopLeft(find.text('Markdown / HTML')).dy;
    expect((lastTop - firstTop).abs(), lessThan(1));

    final double firstLeft = tester.getTopLeft(find.text('資料留在裝置')).dx;
    final double secondLeft = tester.getTopLeft(find.text('完整加密備份')).dx;
    expect(secondLeft, greaterThan(firstLeft));

    final double beforeDrag = tester.getTopLeft(find.text('資料留在裝置')).dx;
    await tester.drag(find.text('全文搜尋'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    final double afterDrag = tester.getTopLeft(find.text('資料留在裝置')).dx;
    expect(afterDrag, lessThan(beforeDrag));
  });

  testWidgets('橫向滑 chip 時外層垂直頁面不跟著捲動', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ScrollController pageController = ScrollController();
    addTearDown(pageController.dispose);

    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        child: ListView(
          controller: pageController,
          padding: const EdgeInsets.all(16),
          children: const <Widget>[
            SettingsGradientHeroCard(
              icon: Icons.menu_book_rounded,
              title: '標題',
              body: '說明',
              chips: <String>[
                '資料留在裝置',
                '完整加密備份',
                '全文搜尋',
                '可攜式匯出',
                'Markdown / HTML',
              ],
            ),
            SizedBox(height: 1200),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(pageController.offset, 0);

    final double chipBefore = tester.getTopLeft(find.text('資料留在裝置')).dx;
    // 帶一點垂直分量，模擬真實手指滑動；外層頁面仍不應移動。
    await tester.drag(find.text('全文搜尋'), const Offset(-140, -40));
    await tester.pumpAndSettle();

    expect(pageController.offset, 0);
    expect(
      tester.getTopLeft(find.text('資料留在裝置')).dx,
      lessThan(chipBefore),
    );
  });
}
