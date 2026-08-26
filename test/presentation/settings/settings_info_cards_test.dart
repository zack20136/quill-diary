import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/presentation/settings/widgets/settings_info_cards.dart';

import '../../helpers/app_test_theme.dart';

void main() {
  testWidgets('Hero 標題接在 icon 右側並垂直置中', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTestTheme(),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: SettingsGradientHeroCard(
              icon: Icons.edit_note_rounded,
              title: '寫作、暫存與正式保存各走自己的路',
              body: '說明文字',
              chips: <String>['可匯出 Markdown', '自動草稿'],
            ),
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

  testWidgets('Hero chips 單列可橫向捲動並顯示 scrollbar', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: appTestTheme(),
        home: const Scaffold(
          body: Padding(
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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(Scrollbar), findsOneWidget);
    expect(find.byType(Wrap), findsNothing);

    final double firstTop = tester.getTopLeft(find.text('資料留在裝置')).dy;
    final double lastTop = tester.getTopLeft(find.text('Markdown / HTML')).dy;
    expect((lastTop - firstTop).abs(), lessThan(1));

    final double firstLeft = tester.getTopLeft(find.text('資料留在裝置')).dx;
    final double secondLeft = tester.getTopLeft(find.text('完整加密備份')).dx;
    expect(secondLeft, greaterThan(firstLeft));
  });
}
