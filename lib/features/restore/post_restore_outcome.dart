import '../../../l10n/l10n.dart';
import '../session/session_messages.dart';
import '../session/state/app_session_state.dart';

enum PostRestorePrimaryAction {
  retryVerification,
  openSettingsRecovery,
}

/// 還原完成後的持續可見引導內容。
final class PostRestoreOutcome {
  const PostRestoreOutcome({
    required this.status,
    required this.title,
    required this.body,
    required this.nextStepHint,
    required this.primaryAction,
    required this.primaryActionLabel,
    required this.secondaryHint,
    this.isError = false,
  });

  final AppLockStatus status;
  final String title;
  final String body;
  final String nextStepHint;
  final PostRestorePrimaryAction primaryAction;
  final String primaryActionLabel;
  final String secondaryHint;
  final bool isError;

  factory PostRestoreOutcome.fromSessionState(
    AppLocalizations l10n,
    AppSessionState sessionState, {
    bool unlockFailedAfterRecoveryKey = false,
  }) {
    if (unlockFailedAfterRecoveryKey) {
      return PostRestoreOutcome(
        status: sessionState.status,
        title: l10n.postRestoreOutcomeUnlockFailedTitle,
        body: sessionState.message?.trim().isNotEmpty == true
            ? sessionState.message!.trim()
            : l10n.vaultTransferRestoreUnlockFailed,
        nextStepHint: l10n.postRestoreOutcomeNextStepRecovery,
        primaryAction: PostRestorePrimaryAction.openSettingsRecovery,
        primaryActionLabel: l10n.postRestoreOutcomePrimaryEnterRecoveryKey,
        secondaryHint: l10n.postRestoreOutcomeSecondaryHint,
        isError: true,
      );
    }

    return switch (sessionState.status) {
      AppLockStatus.locked => PostRestoreOutcome(
        status: sessionState.status,
        title: l10n.postRestoreOutcomeTitle,
        body: snackbarMessageForPostRestore(l10n, sessionState.status),
        nextStepHint: l10n.postRestoreOutcomeNextStepLocked,
        primaryAction: PostRestorePrimaryAction.retryVerification,
        primaryActionLabel: l10n.postRestoreOutcomePrimaryRetryVerification,
        secondaryHint: l10n.postRestoreOutcomeSecondaryHint,
      ),
      AppLockStatus.recoveryRequired => PostRestoreOutcome(
        status: sessionState.status,
        title: l10n.postRestoreOutcomeTitle,
        body: snackbarMessageForPostRestore(l10n, sessionState.status),
        nextStepHint: l10n.postRestoreOutcomeNextStepRecovery,
        primaryAction: PostRestorePrimaryAction.openSettingsRecovery,
        primaryActionLabel: l10n.postRestoreOutcomePrimaryEnterRecoveryKey,
        secondaryHint: l10n.postRestoreOutcomeSecondaryHint,
      ),
      _ => PostRestoreOutcome(
        status: sessionState.status,
        title: l10n.postRestoreOutcomeTitle,
        body: snackbarMessageForPostRestore(l10n, sessionState.status),
        nextStepHint: sessionState.message?.trim().isNotEmpty == true
            ? sessionState.message!.trim()
            : l10n.sessionRestoreStartupFailedMessage,
        primaryAction: PostRestorePrimaryAction.openSettingsRecovery,
        primaryActionLabel: l10n.postRestoreOutcomePrimaryEnterRecoveryKey,
        secondaryHint: l10n.postRestoreOutcomeSecondaryHint,
        isError: sessionState.status == AppLockStatus.fatalError,
      ),
    };
  }
}
