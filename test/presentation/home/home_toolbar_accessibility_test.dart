import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/presentation/home/widgets/entry_widgets.dart';
import 'package:quill_diary/presentation/home/widgets/home_selection_toolbar.dart';
import 'package:quill_diary/presentation/home/widgets/home_shared_widgets.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/shared/entry_index_fixtures.dart';
import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  Widget host(Widget child, {Size size = const Size(390, 800)}) {
    return widgetTestApp(
      center: false,
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }

  testWidgets('選取模式下日記卡片提供 button 與 selected 語意', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        HomeEntryCard(
          entry: buildEntryIndexRecord(),
          typography: EditorTypographyPreferences.defaults,
          selectionActive: true,
          selected: true,
          tagAccents: const <String, int>{},
          showUnsavedDraft: false,
          onTap: () {},
          onLongPress: () {},
        ),
      ),
    );

    final SemanticsNode node = tester.getSemantics(find.byType(HomeEntryCard));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isSelected, Tristate.isTrue);
  });

  testWidgets('搜尋框具有語意標籤與 focused border', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(HomeSearchTextField(hintText: testL10n.peopleSearchHint)),
    );

    expect(
      find.bySemanticsLabel(testL10n.peopleSearchHint),
      findsAtLeastNWidgets(1),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    final OutlineInputBorder? focused =
        field.decoration?.focusedBorder as OutlineInputBorder?;
    expect(focused, isNotNull);
    expect(focused!.borderSide.width, 1.5);
    expect(
      focused.borderSide.color,
      appTestTheme().colorScheme.primary,
    );
  });

  testWidgets('圓形操作按鈕觸控目標至少 44', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        HomeCircleIconButton(
          tooltip: testL10n.homeTooltipEditTag,
          icon: Icons.edit_outlined,
          onPressed: () {},
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.black,
        ),
      ),
    );

    expect(kHomeToolbarActionCircleSize, greaterThanOrEqualTo(44));
    expect(
      tester.getSize(find.byType(HomeCircleIconButton)),
      const Size(44, 44),
    );
  });

  testWidgets('寬螢幕分頁顯示文字標籤', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      host(
        SizedBox(
          height: kHomeSearchRowControlHeight,
          child: HomeHeaderTabButton(
            label: testL10n.homeNavHome,
            icon: Icons.home_rounded,
            active: true,
            showLabel: true,
            onTap: () {},
          ),
        ),
        size: const Size(800, 600),
      ),
    );

    expect(find.text(testL10n.homeNavHome), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
  });

  testWidgets('窄螢幕分頁僅顯示圖示', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 52,
          height: kHomeSearchRowControlHeight,
          child: HomeHeaderTabButton(
            label: testL10n.homeNavHome,
            icon: Icons.home_rounded,
            active: false,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text(testL10n.homeNavHome), findsNothing);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
  });

  testWidgets('選取工具列白色膠囊包住輕量動作按鈕', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        HomeSelectionToolbar(
          selectedCount: 1,
          allSelected: false,
          onCancel: () {},
          onSelectAll: () {},
          onTogglePin: () {},
          pinToggleEnabled: true,
          actions: <HomeSelectionAction>[
            HomeSelectionAction(
              tooltip: testL10n.homeTooltipExportHtml,
              icon: Icons.html,
              onPressed: () {},
            ),
            HomeSelectionAction(
              tooltip: testL10n.commonActionDelete,
              icon: Icons.delete_outline_rounded,
              onPressed: () {},
              destructive: true,
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('home-selection-status-capsule')), findsOneWidget);
    expect(find.text(testL10n.homeSelectionSelectedCount(1)), findsOneWidget);
    expect(find.byType(HomeCircleIconButton), findsNothing);

    final Finder selectAll = find.byTooltip(testL10n.homeSelectionSelectAll);
    final Finder delete = find.byTooltip(testL10n.commonActionDelete);
    expect(selectAll, findsOneWidget);
    expect(delete, findsOneWidget);

    expect(tester.getSize(selectAll).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(selectAll).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(delete).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(delete).height, greaterThanOrEqualTo(44));

    final Icon deleteIcon = tester.widget<Icon>(
      find.descendant(
        of: delete,
        matching: find.byIcon(Icons.delete_outline_rounded),
      ),
    );
    expect(deleteIcon.color, appTestTheme().colorScheme.error);

    final Rect capsule = tester.getRect(
      find.byKey(const Key('home-selection-status-capsule')),
    );
    final Rect selectAllRect = tester.getRect(selectAll);
    final Rect deleteRect = tester.getRect(delete);
    expect(selectAllRect.left, greaterThanOrEqualTo(capsule.left));
    expect(selectAllRect.right, lessThanOrEqualTo(capsule.right));
    expect(deleteRect.left, greaterThanOrEqualTo(capsule.left));
    expect(deleteRect.right, lessThanOrEqualTo(capsule.right));
  });
}
