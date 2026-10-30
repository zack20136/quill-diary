import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/settings_flow_controller.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../helpers/shared/test_l10n.dart';

void main() {
  group('SettingsRestorePrompt', () {
    test('locked 狀態會導向重新驗證', () {
      final AppLocalizations l10n = testL10n;
      final SettingsRestorePrompt outcome =
          SettingsRestorePrompt.fromSessionState(
            l10n: l10n,
            sessionState: const AppSessionState(status: AppLockStatus.locked),
          );

      expect(
        outcome.primaryAction,
        SettingsRestorePrimaryAction.retryVerification,
      );
      expect(outcome.title, l10n.postRestoreOutcomeTitle);
      expect(outcome.nextStepHint, l10n.postRestoreOutcomeNextStepLocked);
    });

    test('recoveryRequired 狀態會導向輸入復原金鑰', () {
      final AppLocalizations l10n = testL10n;
      final SettingsRestorePrompt outcome =
          SettingsRestorePrompt.fromSessionState(
            l10n: l10n,
            sessionState: const AppSessionState(
              status: AppLockStatus.recoveryRequired,
            ),
          );

      expect(
        outcome.primaryAction,
        SettingsRestorePrimaryAction.openSettingsRecovery,
      );
      expect(outcome.nextStepHint, l10n.postRestoreOutcomeNextStepRecovery);
    });
  });
}
