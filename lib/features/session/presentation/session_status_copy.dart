import '../session_copy.dart';
import '../state/app_session_state.dart';

String blockedTitleForStatus(AppLockStatus status) {
  return switch (status) {
    AppLockStatus.locked => SessionCopy.blockedLockedTitle,
    AppLockStatus.recoveryRequired => SessionCopy.blockedRecoveryRequiredTitle,
    AppLockStatus.fatalError => SessionCopy.blockedFatalErrorTitle,
    _ => SessionCopy.blockedDefaultTitle,
  };
}

String blockedSubtitleForState(AppSessionState state) {
  if (state.message != null && state.message!.isNotEmpty) {
    return state.message!;
  }
  return switch (state.status) {
    AppLockStatus.locked => SessionCopy.blockedLockedSubtitle,
    AppLockStatus.recoveryRequired => SessionCopy.blockedRecoveryRequiredSubtitle,
    AppLockStatus.fatalError => SessionCopy.blockedFatalErrorSubtitle,
    _ => '',
  };
}
