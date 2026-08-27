import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';

import '../../helpers/shared/widget_test_app.dart';

const Duration _toastAnimation = Duration(milliseconds: 250);
const Duration _toastDisplay = Duration(seconds: 4);

Future<void> _pumpToastLifecycle(WidgetTester tester) async {
  await tester.pump(_toastAnimation + _toastDisplay);
  await tester.pump(_toastAnimation);
  await tester.pump();
}

void main() {
  testWidgets('dialog 開啟時從 dialog context 顯示 toast', (
    WidgetTester tester,
  ) async {
    const String toastMessage = '已複製到剪貼簿';
    late BuildContext dialogContext;

    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        child: Builder(
          builder: (BuildContext context) {
            return Center(
              child: FilledButton(
                onPressed: () {
                  unawaited(
                    showDialog<void>(
                      context: context,
                      builder: (BuildContext ctx) {
                        dialogContext = ctx;
                        return const AlertDialog(
                          title: Text('對話框'),
                          content: SizedBox(width: 280, height: 360),
                        );
                      },
                    ),
                  );
                },
                child: const Text('開啟'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();

    showAppFeedbackToast(dialogContext, toastMessage);
    await tester.pump(_toastAnimation);

    expect(find.text(toastMessage), findsOneWidget);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    expect(find.text('對話框'), findsOneWidget);

    await _pumpToastLifecycle(tester);
  });

  testWidgets('新 toast 會取代舊 toast', (WidgetTester tester) async {
    late BuildContext hostContext;

    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        child: Builder(
          builder: (BuildContext context) {
            hostContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    showAppFeedbackToast(hostContext, '第一則');
    await tester.pump(_toastAnimation);
    expect(find.text('第一則'), findsOneWidget);

    showAppFeedbackToast(hostContext, '第二則');
    await tester.pump(_toastAnimation);

    expect(find.text('第一則'), findsNothing);
    expect(find.text('第二則'), findsOneWidget);

    await _pumpToastLifecycle(tester);
  });

  testWidgets('toast 顯示與關閉時更新共用 feedback 顯示計數', (
    WidgetTester tester,
  ) async {
    late BuildContext hostContext;

    await tester.pumpWidget(
      widgetTestApp(
        overrides: const [],
        center: false,
        child: Builder(
          builder: (BuildContext context) {
            hostContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final ProviderContainer container = ProviderScope.containerOf(hostContext);
    expect(container.read(appFeedbackVisibilityCountProvider), 0);

    showAppFeedbackToast(hostContext, '通知');
    await tester.pump();
    expect(container.read(appFeedbackVisibilityCountProvider), 1);

    await _pumpToastLifecycle(tester);
    expect(find.text('通知'), findsNothing);
    expect(container.read(appFeedbackVisibilityCountProvider), 0);
  });

  testWidgets('Banner 具有 liveRegion 語意', (WidgetTester tester) async {
    await tester.pumpWidget(
      widgetTestApp(child: const AppFeedbackBanner(message: '已儲存')),
    );

    final SemanticsNode node = tester.getSemantics(
      find.byType(AppFeedbackBanner),
    );
    expect(node.flagsCollection.isLiveRegion, isTrue);
  });

  testWidgets('Toast 具有 liveRegion 語意', (WidgetTester tester) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        child: Builder(
          builder: (BuildContext context) {
            hostContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    showAppFeedbackToast(hostContext, '備份成功', tone: AppFeedbackTone.success);
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Semantics && widget.properties.liveRegion == true,
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 250));
  });
}
