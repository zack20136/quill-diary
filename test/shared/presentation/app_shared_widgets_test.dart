import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_loading_state.dart';
import 'package:quill_diary/shared/presentation/widgets/app_progress.dart';
import 'package:quill_diary/shared/presentation/widgets/app_state_card.dart';

import '../../helpers/app_test_theme.dart';

void main() {
  Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        theme: appTestTheme(brightness: brightness),
        home: Scaffold(
          body: SizedBox.expand(child: Center(child: child)),
        ),
      );

  Finder dialogSurface() => find.byWidgetPredicate(
    (Widget widget) => widget is Material && widget.type == MaterialType.card,
  );

  Future<void> pumpDialogLauncher(
    WidgetTester tester, {
    required AppDialogSize size,
  }) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () => showAppDialog<void>(
              context: context,
              size: size,
              builder: (_) =>
                  const AppDialogShell(title: '確認操作', content: Text('內容')),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
  }

  testWidgets('操作按鈕會套用 loading 與滿寬設定', (tester) async {
    await tester.pumpWidget(
      host(
        const AppActionButton(
          label: '儲存',
          icon: Icons.save_outlined,
          onPressed: null,
          appearance: AppActionButtonAppearance.primary,
          fullWidth: true,
          loading: true,
        ),
      ),
    );

    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.getSize(find.byType(SizedBox).last).width, isNonZero);
  });

  for (final Brightness brightness in Brightness.values) {
    testWidgets('四種操作按鈕在${brightness.name}主題保留既有色彩語意', (tester) async {
      await tester.pumpWidget(
        host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppActionButton(
                label: '主要',
                icon: Icons.save_outlined,
                onPressed: () {},
                appearance: AppActionButtonAppearance.primary,
              ),
              AppActionButton(
                label: '次要',
                icon: Icons.refresh_rounded,
                onPressed: () {},
                appearance: AppActionButtonAppearance.tonal,
              ),
              AppActionButton(
                label: '外框',
                icon: Icons.settings_outlined,
                onPressed: () {},
              ),
              AppActionButton(
                label: '刪除',
                icon: Icons.delete_outline,
                onPressed: () {},
                appearance: AppActionButtonAppearance.destructive,
              ),
            ],
          ),
          brightness: brightness,
        ),
      );

      final ColorScheme colorScheme = appTestTheme(
        brightness: brightness,
      ).colorScheme;
      final List<FilledButton> filledButtons = tester
          .widgetList<FilledButton>(find.byType(FilledButton))
          .toList();
      final List<OutlinedButton> outlinedButtons = tester
          .widgetList<OutlinedButton>(find.byType(OutlinedButton))
          .toList();
      expect(
        filledButtons[0].style?.backgroundColor?.resolve(const <WidgetState>{}),
        brightness == Brightness.dark
            ? colorScheme.primaryContainer
            : colorScheme.primary,
      );
      expect(
        filledButtons[1].style?.backgroundColor?.resolve(const <WidgetState>{}),
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.secondaryContainer,
      );
      expect(
        outlinedButtons[0].style?.foregroundColor?.resolve(
          const <WidgetState>{},
        ),
        colorScheme.onSurface,
      );
      expect(
        outlinedButtons[1].style?.foregroundColor?.resolve(
          const <WidgetState>{},
        ),
        colorScheme.error,
      );
    });
  }

  testWidgets('深色主按鈕 loading 使用主按鈕前景色', (tester) async {
    await tester.pumpWidget(
      host(
        const AppActionButton(
          label: '處理中',
          icon: Icons.save_outlined,
          onPressed: null,
          appearance: AppActionButtonAppearance.primary,
          loading: true,
        ),
        brightness: Brightness.dark,
      ),
    );

    final ColorScheme colorScheme = appTestTheme(
      brightness: Brightness.dark,
    ).colorScheme;
    final FilledButton button = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(
      button.style?.backgroundColor?.resolve(const <WidgetState>{
        WidgetState.disabled,
      }),
      colorScheme.primaryContainer,
    );
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .color,
      colorScheme.onPrimaryContainer,
    );
  });

  testWidgets('loading state 依 layout 顯示留白與說明', (tester) async {
    await tester.pumpWidget(
      host(
        const AppLoadingState(
          layout: AppLoadingStateLayout.page,
          message: '正在讀取',
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('正在讀取'), findsOneWidget);
  });

  testWidgets('state card 會顯示可選操作', (tester) async {
    await tester.pumpWidget(
      host(
        AppStateCard(
          icon: Icons.info_outline,
          title: '沒有資料',
          message: '請建立第一筆日記。',
          actionLabel: '前往設定',
          onAction: () {},
          actionAppearance: AppActionButtonAppearance.outlined,
        ),
      ),
    );

    expect(find.text('沒有資料'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('progress card 保留語意、提示與比例', (tester) async {
    await tester.pumpWidget(
      host(
        const AppProgressCard(
          title: '正在處理',
          message: '正在檢查附件',
          hint: '請保持 App 開啟',
          semanticLabel: '正在處理，38%',
          value: .38,
        ),
      ),
    );

    expect(find.bySemanticsLabel('正在處理，38%'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .38,
    );
    expect(find.text('請保持 App 開啟'), findsOneWidget);
  });

  testWidgets('線性進度會把比例限制在有效範圍', (tester) async {
    await tester.pumpWidget(host(const AppLinearProgressIndicator(value: 1.4)));
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      1,
    );

    await tester.pumpWidget(
      host(const AppLinearProgressIndicator(value: -0.2)),
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0,
    );
  });

  testWidgets('確認 dialog 取消與確認會回傳對應結果', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    bool? result;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () async {
              result = await showAppConfirmDialog(
                context: context,
                title: '刪除資料',
                content: const Text('刪除後無法復原'),
                cancelLabel: '取消',
                confirmLabel: '刪除',
                confirmStyle: AppConfirmStyle.destructive,
              );
            },
            child: const Text('開啟'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    expect(tester.getSize(dialogSurface()).width, 256);
    expect(find.byType(FilledButton), findsWidgets);
    final FilledButton deleteButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '刪除'),
    );
    expect(
      deleteButton.style?.backgroundColor?.resolve(const <WidgetState>{}),
      appTestTheme().colorScheme.error,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('dialog shell 在窄寬與寬螢幕均使用九成寬度', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpDialogLauncher(tester, size: AppDialogSize.standard);

    expect(tester.getSize(dialogSurface()).width, 288);
    expect(find.text('確認操作'), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(800, 568));
    await tester.pump();
    expect(tester.getSize(dialogSurface()).width, 720);
  });

  testWidgets('compact dialog 在窄寬與寬螢幕均使用八成寬度', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpDialogLauncher(tester, size: AppDialogSize.compact);

    expect(tester.getSize(dialogSurface()).width, 256);
    await tester.binding.setSurfaceSize(const Size(800, 568));
    await tester.pump();
    expect(tester.getSize(dialogSurface()).width, 640);
  });
}
