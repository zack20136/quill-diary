import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/presentation/session/widgets/session_locked_pane.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';
import 'package:quill_diary/shared/presentation/widgets/app_state_card.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  test('鎖定狀態會提供重試驗證操作', () {
    final SessionBlockedPresentation presentation =
        SessionBlockedPresentation.resolve(
          sessionState: const AppSessionState(status: AppLockStatus.locked),
          l10n: testL10n,
        );

    expect(presentation.title, testL10n.sessionBlockedLockedTitle);
    expect(presentation.actionKind, SessionBlockedActionKind.retryUnlock);
    expect(presentation.actionLabel, testL10n.homeRetryVerification);
  });

  test('recovery 狀態會提供前往設定操作', () {
    final SessionBlockedPresentation presentation =
        SessionBlockedPresentation.resolve(
          sessionState: const AppSessionState(
            status: AppLockStatus.recoveryRequired,
          ),
          l10n: testL10n,
        );

    expect(presentation.title, testL10n.sessionBlockedRecoveryRequiredTitle);
    expect(presentation.actionKind, SessionBlockedActionKind.openSettings);
    expect(presentation.actionLabel, testL10n.homeGoToSettings);
  });

  testWidgets('鎖定畫面會顯示狀態卡與操作按鈕', (WidgetTester tester) async {
    await tester.pumpWidget(
      widgetTestApp(
        overrides: const [],
        child: const SessionBlockedPane(
          sessionState: AppSessionState(status: AppLockStatus.locked),
        ),
      ),
    );

    expect(find.byType(AppStateView), findsOneWidget);
    expect(find.byType(AppActionButton), findsOneWidget);
  });

  testWidgets('recovery 畫面會顯示狀態卡與操作按鈕', (WidgetTester tester) async {
    await tester.pumpWidget(
      widgetTestApp(
        overrides: const [],
        child: const SessionBlockedPane(
          sessionState: AppSessionState(status: AppLockStatus.recoveryRequired),
        ),
      ),
    );

    expect(find.byType(AppStateView), findsOneWidget);
    expect(find.byType(AppActionButton), findsOneWidget);
  });
}
