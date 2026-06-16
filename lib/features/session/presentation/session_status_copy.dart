import '../../../l10n/l10n.dart';
import '../state/app_session_state.dart';

String blockedTitleForStatus(AppLocalizations l10n, AppLockStatus status) {
  return switch (status) {
    AppLockStatus.locked => l10n.sessionBlockedLockedTitle,
    AppLockStatus.recoveryRequired => l10n.sessionBlockedRecoveryRequiredTitle,
    AppLockStatus.fatalError => l10n.sessionBlockedFatalErrorTitle,
    _ => l10n.sessionBlockedDefaultTitle,
  };
}

String blockedSubtitleForState(AppLocalizations l10n, AppSessionState state) {
  if (state.message != null && state.message!.isNotEmpty) {
    return state.message!;
  }
  return switch (state.status) {
    AppLockStatus.locked => l10n.sessionBlockedLockedSubtitle,
    AppLockStatus.recoveryRequired => l10n.sessionBlockedRecoveryRequiredSubtitle,
    AppLockStatus.fatalError => l10n.sessionBlockedFatalErrorSubtitle,
    _ => '',
  };
}
