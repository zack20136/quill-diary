import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/errors/user_facing_error.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/presentation/home/widgets/home_selection_toolbar.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

import '../../helpers/presentation/home/people_test_scope.dart';
import '../../helpers/shared/test_l10n.dart';

void main() {
  late PeopleTestRepository repository;
  late ProviderContainer container;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repository = PeopleTestRepository([
      peopleTestPerson('p-alpha', '阿明'),
      peopleTestPerson('p-beta', '小美'),
      peopleTestPerson('p-gamma', '王大哉'),
    ]);
    container = peopleTestContainer(repository);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    container.read(homeTabProvider.notifier).set(HomeTab.people);
    await tester.pumpWidget(peopleTestApp(container));
    await tester.pumpAndSettle();
  }

  Finder row(String id) => find.byKey(ValueKey<String>('person-row-$id'));
  HomeSelectionToolbar toolbar(WidgetTester tester) =>
      tester.widget<HomeSelectionToolbar>(find.byType(HomeSelectionToolbar));
  Finder dialogAction(String label) => find.descendant(
    of: find.byType(AppConfirmDialog),
    matching: find.widgetWithText(FilledButton, label),
  );

  Future<void> requestDelete(WidgetTester tester) async {
    await tester.tap(find.byTooltip(testL10n.commonActionDelete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('長按進入選取，點擊切換勾選且每列都顯示同一勾選指示', (tester) async {
    await open(tester);
    await tester.longPress(row('p-alpha'));
    await tester.pumpAndSettle();
    expect(toolbar(tester).selectedCount, 1);
    expect(find.byType(HomeSelectionIndicator), findsNWidgets(3));

    await tester.tap(row('p-beta'));
    await tester.pumpAndSettle();
    expect(toolbar(tester).selectedCount, 2);

    await tester.tap(row('p-alpha'));
    await tester.pumpAndSettle();
    expect(toolbar(tester).selectedCount, 1);
  });

  testWidgets('返回鍵與取消只結束人物選取', (tester) async {
    await open(tester);
    await tester.longPress(row('p-alpha'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomeSelectionToolbar), findsNothing);

    await tester.longPress(row('p-beta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(testL10n.homeTooltipDeselectTag));
    await tester.pumpAndSettle();
    expect(find.byType(HomeSelectionToolbar), findsNothing);
    expect(repository.deleteCalls, isEmpty);
  });

  testWidgets('全選涵蓋全部人物，零選取時停用刪除', (tester) async {
    await open(tester);
    await tester.longPress(row('p-alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(testL10n.homeSelectionSelectAll));
    await tester.pumpAndSettle();
    expect(toolbar(tester).selectedCount, 3);

    await tester.tap(find.byTooltip(testL10n.homeSelectionDeselectAll));
    await tester.pumpAndSettle();
    expect(toolbar(tester).selectedCount, 0);
    final IconButton delete = tester.widget<IconButton>(
      find.byKey(Key('home-selection-action-${testL10n.commonActionDelete}')),
    );
    expect(delete.onPressed, isNull);
  });

  testWidgets('批次刪除確認後移除所選人物並結束選取', (tester) async {
    await open(tester);
    await tester.longPress(row('p-alpha'));
    await tester.pumpAndSettle();
    await tester.tap(row('p-beta'));
    await tester.pumpAndSettle();

    await requestDelete(tester);
    expect(
      find.text(testL10n.peopleDeleteSelectedConfirmBody(2)),
      findsOneWidget,
    );
    await tester.tap(dialogAction(testL10n.commonActionDelete));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, unorderedEquals(['p-alpha', 'p-beta']));
    expect(find.byType(HomeSelectionToolbar), findsNothing);
    expect(row('p-alpha'), findsNothing);
    expect(row('p-beta'), findsNothing);
    expect(row('p-gamma'), findsOneWidget);
  });

  testWidgets('取消批次刪除確認時不刪除任何人物', (tester) async {
    await open(tester);
    await tester.longPress(row('p-alpha'));
    await tester.pumpAndSettle();

    await requestDelete(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AppConfirmDialog),
        matching: find.widgetWithText(TextButton, testL10n.commonActionCancel),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, isEmpty);
    expect(toolbar(tester).selectedCount, 1);
    expect(row('p-alpha'), findsOneWidget);
  });

  testWidgets('部分失敗停止後續刪除並保留未完成的勾選', (tester) async {
    await open(tester);
    repository.failOnCall = 2;
    await tester.longPress(row('p-alpha'));
    await tester.pumpAndSettle();
    await tester.tap(row('p-beta'));
    await tester.pumpAndSettle();

    await requestDelete(tester);
    await tester.tap(dialogAction(testL10n.commonActionDelete));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, hasLength(2));
    final String failedId = repository.deleteCalls.last;
    final String doneId = repository.deleteCalls.first;
    expect(row(doneId), findsNothing);
    expect(row(failedId), findsOneWidget);
    expect(toolbar(tester).selectedCount, 1);
    expect(
      find.text(
        testL10n.peopleDeleteSelectedPartial(
          1,
          1,
          userFacingErrorMessage(repository.failure, l10n: testL10n),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('切換離開人物分頁時清除選取', (tester) async {
    await open(tester);
    await tester.longPress(row('p-alpha'));
    await tester.pumpAndSettle();

    container.read(homeTabProvider.notifier).set(HomeTab.home);
    await tester.pumpAndSettle();
    container.read(homeTabProvider.notifier).set(HomeTab.people);
    await tester.pumpAndSettle();

    expect(find.byType(HomeSelectionToolbar), findsNothing);
    expect(row('p-alpha'), findsOneWidget);
  });
}
