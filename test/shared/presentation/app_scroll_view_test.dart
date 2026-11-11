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
  testWidgets('AppScrollView 內容超出時顯示捲軸且可捲動', (tester) async {
    await tester.pumpWidget(
      widgetTestApp(
        child: const SizedBox(
          height: 200,
          child: AppScrollView(child: SizedBox(height: 800)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppScrollbar), findsOneWidget);
    expect(_thumbFinder, findsOneWidget);
    expect(
      _positionOf(tester, find.byType(AppScrollView)).maxScrollExtent,
      greaterThan(0),
    );
  });

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

  testWidgets('AppScrollView 內容未超出時不顯示捲軸', (tester) async {
    await tester.pumpWidget(
      widgetTestApp(
        child: const SizedBox(
          height: 200,
          child: AppScrollView(child: SizedBox(height: 80)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppScrollbar), findsOneWidget);
    expect(_thumbFinder, findsNothing);
  });

  testWidgets('dialog 內 thumb 的上下留白與頁面一致', (tester) async {
    final pageController = ScrollController();
    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        wrapScaffold: false,
        viewport: const Size(400, 400),
        child: AppScrollablePageBody(
          controller: pageController,
          children: const [SizedBox(height: 1200)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Rect pageRect = tester.getRect(find.byType(AppScrollablePageBody));
    final double pageTopGap = tester.getRect(_thumbFinder).top - pageRect.top;
    pageController.jumpTo(pageController.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final double pageBottomGap =
        pageRect.bottom - tester.getRect(_thumbFinder).bottom;

    late ScrollController dialogController;
    await tester.pumpWidget(
      widgetTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppDialog<void>(
              context: context,
              builder: (_) => AppDialogShell(
                title: '測試',
                content: SizedBox(
                  height: 200,
                  child: AppScrollableContent(
                    builder: (context, controller) {
                      dialogController = controller;
                      return SingleChildScrollView(
                        controller: controller,
                        child: const SizedBox(height: 800),
                      );
                    },
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
    final Rect scrollRect = tester.getRect(find.byType(SingleChildScrollView));
    final double dialogTopGap =
        tester.getRect(_thumbFinder).top -
        (scrollRect.top - AppDialogInsets.content.top);
    dialogController.jumpTo(dialogController.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final double dialogBottomGap =
        scrollRect.bottom +
        AppDialogInsets.content.bottom -
        tester.getRect(_thumbFinder).bottom;

    expect(dialogTopGap, closeTo(pageTopGap, 0.5));
    expect(dialogBottomGap, closeTo(pageBottomGap, 0.5));
    pageController.dispose();
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
