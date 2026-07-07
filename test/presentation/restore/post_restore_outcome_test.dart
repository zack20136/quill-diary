import 'package:flutter_test/flutter_test.dart';

import 'package:quill_diary/presentation/restore/post_restore_outcome.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../helpers/shared/test_l10n.dart';

void main() {
  group('PostRestoreOutcome', () {
    test('locked 狀態會導向重新驗證', () {
      final AppLocalizations l10n = testL10n;
      final PostRestoreOutcome outcome = PostRestoreOutcome.fromSessionState(
        l10n,
        const AppSessionState(status: AppLockStatus.locked),
      );

      expect(outcome.primaryAction, PostRestorePrimaryAction.retryVerification);
      expect(outcome.title, l10n.postRestoreOutcomeTitle);
      expect(outcome.nextStepHint, l10n.postRestoreOutcomeNextStepLocked);
    });

    test('recoveryRequired 狀態會導向輸入復原金鑰', () {
      final AppLocalizations l10n = testL10n;
      final PostRestoreOutcome outcome = PostRestoreOutcome.fromSessionState(
        l10n,
        const AppSessionState(status: AppLockStatus.recoveryRequired),
      );

      expect(
        outcome.primaryAction,
        PostRestorePrimaryAction.openSettingsRecovery,
      );
      expect(outcome.nextStepHint, l10n.postRestoreOutcomeNextStepRecovery);
    });
  });
}
