import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/widgets/accent_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_loading_state.dart';
import 'package:quill_diary/shared/presentation/widgets/app_progress.dart';
import 'package:quill_diary/shared/presentation/widgets/app_state_card.dart';

import '../../helpers/shared/widget_test_app.dart';

void main() {
  Widget host(Widget child) =>
      widgetTestApp(child: SizedBox.expand(child: child));

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
    final Size buttonSize = tester.getSize(find.byType(FilledButton));
    expect(buttonSize.width, greaterThan(buttonSize.height));
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
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('AccentDialogShell 關閉按鈕觸控目標至少 44', (tester) async {
    await tester.pumpWidget(
      host(
        AccentDialogShell(
          icon: Icons.palette_outlined,
          title: '標題',
          onClose: () {},
          child: const SizedBox(height: 40),
        ),
      ),
    );

    final Size size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });
}
