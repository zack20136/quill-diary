import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/session/widgets/session_locked_pane.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';
import 'package:quill_diary/shared/presentation/widgets/app_state_card.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/shared/test_l10n.dart';

void main() {
  Widget host(Widget child) => ProviderScope(
    child: MaterialApp(
      theme: appTestTheme(),
      locale: appZhLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: Center(child: child)),
    ),
  );

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

    expect(
      presentation.title,
      testL10n.sessionBlockedRecoveryRequiredTitle,
    );
    expect(presentation.actionKind, SessionBlockedActionKind.openSettings);
    expect(presentation.actionLabel, testL10n.homeGoToSettings);
  });

  testWidgets('SessionBlockedPane 顯示鎖定標題與重試按鈕', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        const SessionBlockedPane(
          sessionState: AppSessionState(status: AppLockStatus.locked),
        ),
      ),
    );

    expect(find.byType(AppStateView), findsOneWidget);
    expect(find.text(testL10n.sessionBlockedLockedTitle), findsOneWidget);
    expect(find.byType(AppActionButton), findsOneWidget);
    expect(find.text(testL10n.homeRetryVerification), findsOneWidget);
  });

  testWidgets('SessionBlockedPane 在 recovery 顯示設定操作', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        const SessionBlockedPane(
          sessionState: AppSessionState(
            status: AppLockStatus.recoveryRequired,
          ),
        ),
      ),
    );

    expect(
      find.text(testL10n.sessionBlockedRecoveryRequiredTitle),
      findsOneWidget,
    );
    expect(find.text(testL10n.homeGoToSettings), findsOneWidget);
  });
}
