import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/presentation/session/widgets/session_locked_pane.dart';

import '../../helpers/shared/test_l10n.dart';

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
}
