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

  testWidgets('leading 按鈕顯示在操作列並可點擊', (WidgetTester tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _app(
        dialogBuilder: (_) => AppDialogShell(
          title: '測試標題',
          content: const Text('內容'),
          leading: IconButton(
            key: const Key('shell-leading'),
            onPressed: () => tapped++,
            icon: const Icon(Icons.visibility),
          ),
          actions: const <Widget>[Text('確定')],
        ),
      ),
    );
    await _open(tester);

    await tester.tap(find.byKey(const Key('shell-leading')));
    await tester.pumpAndSettle();

    expect(tapped, 1);
    expect(find.text('內容'), findsOneWidget);
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
