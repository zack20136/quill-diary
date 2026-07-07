import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/presentation/home/providers/home_bottom_chrome_provider.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';

import '../../helpers/app_test_theme.dart';

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
      MaterialApp(
        theme: appTestTheme(),
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
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
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();

    showAppFeedbackSnackBar(dialogContext, toastMessage);
    await tester.pump(_toastAnimation);

    expect(find.text(toastMessage), findsOneWidget);
    expect(find.text('對話框'), findsOneWidget);

    await _pumpToastLifecycle(tester);
  });

  testWidgets('新 toast 會取代舊 toast', (WidgetTester tester) async {
    late BuildContext hostContext;

    await tester.pumpWidget(
      MaterialApp(
        theme: appTestTheme(),
        home: Builder(
          builder: (BuildContext context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    showAppFeedbackSnackBar(hostContext, '第一則');
    await tester.pump(_toastAnimation);
    expect(find.text('第一則'), findsOneWidget);

    showAppFeedbackSnackBar(hostContext, '第二則');
    await tester.pump(_toastAnimation);

    expect(find.text('第一則'), findsNothing);
    expect(find.text('第二則'), findsOneWidget);

    await _pumpToastLifecycle(tester);
  });

  testWidgets('toast 顯示與關閉時更新 homeBottomChromeSnackBarCountProvider', (
    WidgetTester tester,
  ) async {
    late BuildContext hostContext;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: appTestTheme(),
          home: Builder(
            builder: (BuildContext context) {
              hostContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      ),
    );

    final ProviderContainer container = ProviderScope.containerOf(hostContext);
    expect(container.read(homeBottomChromeSnackBarCountProvider), 0);

    showAppFeedbackSnackBar(hostContext, '通知');
    await tester.pump();
    expect(container.read(homeBottomChromeSnackBarCountProvider), 1);

    await _pumpToastLifecycle(tester);
    expect(find.text('通知'), findsNothing);
    expect(container.read(homeBottomChromeSnackBarCountProvider), 0);
  });
}
