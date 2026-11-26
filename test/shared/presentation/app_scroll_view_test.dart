import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

import '../../helpers/shared/widget_test_app.dart';

final _thumbFinder = find.byKey(const ValueKey<String>('app-scrollbar-thumb'));

ScrollPosition _positionOf(WidgetTester tester, Finder owner) {
  final ScrollableState state = tester.state<ScrollableState>(
    find.descendant(of: owner, matching: find.byType(Scrollable)),
  );
  return state.position;
}

void main() {
  testWidgets('AppScrollView 捲軸畫在右側保留欄，不蓋住內容', (tester) async {
    await tester.pumpWidget(
      widgetTestApp(
        child: const SizedBox(
          width: 300,
          height: 200,
          child: AppScrollView(
            child: SizedBox(key: ValueKey('content'), width: 300, height: 800),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Rect content = tester.getRect(find.byKey(const ValueKey('content')));
    final Rect thumb = tester.getRect(_thumbFinder);
    expect(thumb.left, greaterThanOrEqualTo(content.right));
  });

  testWidgets('內容在原位置變長或縮短時立即更新捲軸', (tester) async {
    final height = ValueNotifier<double>(80);
    addTearDown(height.dispose);
    await tester.pumpWidget(
      widgetTestApp(
        child: SizedBox(
          width: 300,
          height: 200,
          child: AppScrollView(
            child: ValueListenableBuilder<double>(
              valueListenable: height,
              builder: (_, value, _) => SizedBox(height: value),
            ),
          ),
        ),
      ),
    );
    expect(_thumbFinder, findsNothing);

    height.value = 800;
    await tester.pumpAndSettle();
    expect(_thumbFinder.hitTestable(), findsOneWidget);
    height.value = 80;
    await tester.pumpAndSettle();
    expect(_thumbFinder, findsNothing);
  });

  testWidgets('拖曳內層滑塊只會捲動內層清單', (tester) async {
    final outer = ScrollController();
    final inner = ScrollController();
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);
    await tester.pumpWidget(
      widgetTestApp(
        child: SizedBox(
          width: 300,
          height: 300,
          child: ListView(
            controller: outer,
            children: [
              SizedBox(
                height: 180,
                child: AppScrollbar(
                  controller: inner,
                  placement: AppScrollbarPlacement.nestedPanel,
                  child: SingleChildScrollView(
                    controller: inner,
                    child: const SizedBox(height: 900),
                  ),
                ),
              ),
              const SizedBox(height: 900),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(_thumbFinder, const Offset(0, 135));
    await tester.pumpAndSettle();
    expect(inner.offset, greaterThan(0));
    expect(outer.offset, 0);
  });

  testWidgets('拖曳中內容縮短而隱藏滑塊時，會結束拖曳狀態', (tester) async {
    final controller = ScrollController();
    final height = ValueNotifier<double>(800);
    final dragStates = <bool>[];
    addTearDown(controller.dispose);
    addTearDown(height.dispose);
    await tester.pumpWidget(
      widgetTestApp(
        child: SizedBox(
          width: 300,
          height: 200,
          child: AppScrollbar(
            controller: controller,
            onThumbDragChanged: dragStates.add,
            child: SingleChildScrollView(
              controller: controller,
              child: ValueListenableBuilder<double>(
                valueListenable: height,
                builder: (_, height, _) => SizedBox(height: height),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(_thumbFinder));
    await gesture.moveBy(const Offset(0, 32));
    await tester.pump();
    expect(dragStates, [true]);
    height.value = 80;
    await tester.pumpAndSettle();
    expect(_thumbFinder, findsNothing);
    expect(dragStates, [true, false]);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(dragStates, [true, false]);
  });

  testWidgets('對話框內容長短切換時保持左右對齊，滑塊使用現有留白', (tester) async {
    final height = ValueNotifier<double>(80);
    addTearDown(height.dispose);
    const bodyKey = ValueKey('dialog-content');
    await tester.pumpWidget(
      widgetTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppDialog<void>(
              context: context,
              builder: (_) => AppDialogShell(
                title: '測試',
                content: AppScrollView(
                  child: ValueListenableBuilder<double>(
                    valueListenable: height,
                    builder: (_, value, _) => SizedBox(
                      key: bodyKey,
                      width: double.infinity,
                      height: value,
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    final surface = find
        .descendant(of: find.byType(Dialog), matching: find.byType(Material))
        .first;
    void expectCentered() {
      final dialog = tester.getRect(surface);
      final body = tester.getRect(find.byKey(bodyKey));
      expect(body.left - dialog.left, closeTo(dialog.right - body.right, 0.1));
    }

    expectCentered();
    expect(_thumbFinder, findsNothing);
    height.value = 800;
    await tester.pumpAndSettle();
    expectCentered();
    expect(
      tester.getRect(_thumbFinder).left,
      greaterThanOrEqualTo(tester.getRect(find.byKey(bodyKey)).right),
    );

    final Rect scrollRect = tester.getRect(find.byType(SingleChildScrollView));
    expect(tester.getRect(_thumbFinder).top, closeTo(scrollRect.top, 1));
    final position = _positionOf(tester, find.byType(AppScrollView));
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(tester.getRect(_thumbFinder).bottom, closeTo(scrollRect.bottom, 1));
  });

  testWidgets('AppScrollableContent 把同一個 controller 交給 ListView 並顯示捲軸', (
    tester,
  ) async {
    await tester.pumpWidget(
      widgetTestApp(
        child: SizedBox(
          height: 200,
          child: AppScrollableContent(
            builder: (context, controller) => ListView.builder(
              controller: controller,
              itemCount: 40,
              itemBuilder: (context, index) =>
                  SizedBox(height: 50, child: Text('列 $index')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_thumbFinder, findsOneWidget);
    expect(
      _positionOf(tester, find.byType(ListView)).maxScrollExtent,
      greaterThan(0),
    );
  });
}
