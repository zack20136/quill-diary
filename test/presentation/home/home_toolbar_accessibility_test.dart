import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/presentation/home/pages/home_page.dart';
import 'package:quill_diary/presentation/home/widgets/entry_widgets.dart';
import 'package:quill_diary/presentation/home/widgets/home_selection_toolbar.dart';
import 'package:quill_diary/presentation/home/widgets/home_shared_widgets.dart';

import '../../helpers/shared/entry_index_fixtures.dart';
import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('選取工具列停用時一併停用退出、全選、釘選及其他操作', (tester) async {
    await tester.pumpWidget(
      widgetTestApp(
        child: HomeSelectionToolbar(
          selectedCount: 1,
          allSelected: false,
          enabled: false,
          onCancel: () => fail('停用時不可退出'),
          onSelectAll: () => fail('停用時不可全選'),
          onTogglePin: () => fail('停用時不可釘選'),
          pinToggleEnabled: true,
          actions: [
            HomeSelectionAction(
              tooltip: testL10n.commonActionDelete,
              icon: Icons.delete_outline_rounded,
              onPressed: () => fail('停用時不可刪除'),
            ),
          ],
        ),
      ),
    );
    expect(
      tester
          .widgetList<IconButton>(find.byType(IconButton))
          .every((button) => button.onPressed == null),
      isTrue,
    );
  });

  Widget host(Widget child) {
    return widgetTestApp(
      center: false,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(390, 800)),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }

  testWidgets('選取模式下日記卡片提供 button 與 selected 語意', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        HomeEntryCard(
          entry: buildDiaryEntrySummary(),
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

  testWidgets('搜尋框提供語意標籤，點擊後取得輸入焦點', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(HomeSearchTextField(hintText: testL10n.peopleSearchHint)),
    );

    expect(
      find.bySemanticsLabel(testL10n.peopleSearchHint),
      findsAtLeastNWidgets(1),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    expect(editable.widget.focusNode.hasFocus, isTrue);
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

    final size = tester.getSize(find.byType(HomeCircleIconButton));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('320 dp 寬的首頁可直接點選每個分頁', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      widgetTestApp(
        overrides: [],
        wrapScaffold: false,
        child: const Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(76),
            child: HomeHeader(settingsEnabled: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tabs = find.byType(HomeHeaderTabButton);
    expect(tabs.hitTestable(), findsNWidgets(HomeTab.values.length));
    for (final (index, tab) in HomeTab.values.indexed) {
      await tester.tap(tabs.at(index));
      await tester.pumpAndSettle();
      final activeTabs = tester
          .widgetList<HomeHeaderTabButton>(tabs)
          .where((button) => button.active);
      expect(
        activeTabs.single.label,
        tester.widget<HomeHeaderTabButton>(tabs.at(index)).label,
        reason: tab.name,
      );
    }
  });

  testWidgets('選取工具列可點擊全選與刪除', (tester) async {
    final operations = <String>[];
    await tester.pumpWidget(
      host(
        HomeSelectionToolbar(
          selectedCount: 1,
          allSelected: false,
          onCancel: () {},
          onSelectAll: () => operations.add('全選'),
          actions: [
            HomeSelectionAction(
              tooltip: testL10n.commonActionDelete,
              icon: Icons.delete_outline_rounded,
              onPressed: () => operations.add('刪除'),
              destructive: true,
            ),
          ],
        ),
      ),
    );

    expect(find.text(testL10n.homeSelectionSelectedCount(1)), findsOneWidget);
    await tester.tap(find.byTooltip(testL10n.homeSelectionSelectAll));
    await tester.tap(find.byTooltip(testL10n.commonActionDelete));
    expect(operations, ['全選', '刪除']);
  });
}
