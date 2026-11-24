import 'dart:async' show unawaited;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

import '../../helpers/app_test_theme.dart';

Widget _app({required WidgetBuilder dialogBuilder}) => MaterialApp(
  theme: appTestTheme(),
  locale: appZhLocale,
  supportedLocales: appSupportedLocales,
  localizationsDelegates: appLocalizationsDelegates,
  home: Builder(
    builder: (BuildContext context) => Scaffold(
      body: Center(
        child: FilledButton(
          key: const Key('open-dialog'),
          onPressed: () => unawaited(
            showAppDialog<void>(context: context, builder: dialogBuilder),
          ),
          child: const Text('開啟'),
        ),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-dialog')));
  await tester.pumpAndSettle();
}

final Finder _closeButton = find.byTooltip(
  lookupAppLocalizations(appZhLocale).commonCloseTooltip,
);

void main() {
  testWidgets('預設標題列有關閉 X，點擊後關閉 dialog', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        dialogBuilder: (_) =>
            const AppDialogShell(title: '測試標題', content: Text('內容')),
      ),
    );
    await _open(tester);

    expect(_closeButton, findsOneWidget);
    await tester.tap(_closeButton);
    await tester.pumpAndSettle();

    expect(find.text('內容'), findsNothing);
  });

  testWidgets('長確認內容可捲動，操作按鈕仍可按下', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        dialogBuilder: (_) => AppConfirmDialog(
          title: '刪除選取項目',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var index = 0; index < 40; index++) Text('項目 $index'),
            ],
          ),
          cancelLabel: '返回',
          confirmLabel: '刪除',
          confirmStyle: AppConfirmStyle.destructive,
        ),
      ),
    );
    await _open(tester);

    final confirm = find.widgetWithText(FilledButton, '刪除');
    expect(confirm.hitTestable(), findsOneWidget);
    expect(find.text('項目 39').hitTestable(), findsNothing);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -800),
    );
    await tester.pumpAndSettle();

    expect(find.text('項目 39').hitTestable(), findsOneWidget);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(confirm, findsNothing);
  });

  testWidgets('showClose 為 false 時不顯示關閉 X', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        dialogBuilder: (_) => const AppDialogShell(
          title: '測試標題',
          content: Text('內容'),
          showClose: false,
        ),
      ),
    );
    await _open(tester);

    expect(_closeButton, findsNothing);
    expect(find.text('內容'), findsOneWidget);
  });

  testWidgets('closeEnabled 為 false 時關閉 X 停用，點了也不會關閉', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        dialogBuilder: (_) => const AppDialogShell(
          title: '測試標題',
          content: Text('內容'),
          closeEnabled: false,
        ),
      ),
    );
    await _open(tester);

    final IconButton close = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.close_rounded),
    );
    expect(close.onPressed, isNull);
    await tester.tap(_closeButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('內容'), findsOneWidget);
  });

  testWidgets('onClose 取代預設關閉行為，dialog 保持開啟', (WidgetTester tester) async {
    var closed = 0;
    await tester.pumpWidget(
      _app(
        dialogBuilder: (_) => AppDialogShell(
          title: '測試標題',
          content: const Text('內容'),
          onClose: () => closed++,
        ),
      ),
    );
    await _open(tester);

    await tester.tap(_closeButton);
    await tester.pumpAndSettle();

    expect(closed, 1);
    expect(find.text('內容'), findsOneWidget);
  });

  testWidgets('放大字級時依實際寬度分列，左右操作仍可點擊', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 800);
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var leadingTapped = false;
    var applied = false;
    final leading = find.byKey(const Key('shell-leading'));
    final cancel = find.byKey(const Key('shell-cancel'));
    final apply = find.byKey(const Key('shell-apply'));
    await tester.pumpWidget(
      _app(
        dialogBuilder: (_) => AppDialogShell(
          title: '測試標題',
          content: const Text('內容'),
          leading: TextButton(
            key: const Key('shell-leading'),
            onPressed: () => leadingTapped = true,
            child: const Text('Default'),
          ),
          actions: [
            TextButton(
              key: const Key('shell-cancel'),
              onPressed: () {},
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('shell-apply'),
              onPressed: () => applied = true,
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    await _open(tester);
    expect(tester.getCenter(leading).dy, tester.getCenter(apply).dy);

    tester.view.physicalSize = const Size(320, 800);
    await tester.pumpAndSettle();
    final left = tester.getRect(leading);
    final right = tester.getRect(apply);
    expect(left.left, lessThan(right.left));
    expect(left.bottom, lessThan(tester.getTopLeft(cancel).dy));
    expect(tester.getRect(cancel).right, closeTo(right.right, 0.1));

    await tester.tap(leading);
    await tester.tap(apply);
    expect(leadingTapped, isTrue);
    expect(applied, isTrue);
  });

  testWidgets('很高的內容不超過表面的 90%，短內容不會被拉高', (WidgetTester tester) async {
    Size cardSize() => tester.getSize(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Material),
          )
          .first,
    );

    final double surfaceHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    await tester.pumpWidget(
      _app(
        dialogBuilder: (_) =>
            const AppDialogShell(title: '短', content: Text('一行')),
      ),
    );
    await _open(tester);
    final double shortHeight = cardSize().height;
    expect(shortHeight, lessThan(surfaceHeight * 0.5));

    await tester.tap(_closeButton);
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _app(
        dialogBuilder: (_) => AppDialogShell(
          title: '高',
          content: AppScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var index = 0; index < 80; index++) Text('行 $index'),
              ],
            ),
          ),
        ),
      ),
    );
    await _open(tester);
    final double tallHeight = cardSize().height;
    expect(
      tallHeight,
      lessThanOrEqualTo(surfaceHeight * appDialogMaxHeightFactor + 1),
    );
    expect(tallHeight, greaterThan(shortHeight));
    expect(tester.takeException(), isNull);
  });

  testWidgets('填滿高度的卡片直接用到表面的 90%', (WidgetTester tester) async {
    final double surfaceHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    await tester.pumpWidget(
      _app(
        dialogBuilder: (_) => const AppDialogShell(
          title: '填滿',
          fillHeight: true,
          content: Text('一行'),
        ),
      ),
    );
    await _open(tester);
    final double height = tester
        .getSize(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(Material),
              )
              .first,
        )
        .height;
    expect(height, greaterThan(surfaceHeight * 0.85));
    expect(
      height,
      lessThanOrEqualTo(surfaceHeight * appDialogMaxHeightFactor + 1),
    );
    expect(tester.takeException(), isNull);
  });
}
