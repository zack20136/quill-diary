import '../../../domain/security/unlocked_vault_session.dart';
import 'resume_unlock_action.dart';

enum AppLockStatus {
  uninitialized,
  locked,
  unlocking,
  unlocked,
  recoveryRequired,
  fatalError,
}

class AppSessionState {
  const AppSessionState({
    required this.status,
    this.message,
    this.session,
    this.resumeAction,
  });

  final AppLockStatus status;
  final String? message;
  final UnlockedVaultSession? session;

  /// 逾時鎖定後 UI 應執行的步驟；`null` 表示不需自動介入。
  final ResumeUnlockAction? resumeAction;

  bool get isUnlocked => status == AppLockStatus.unlocked;

  AppSessionState copyWith({
    AppLockStatus? status,
    String? message,
    UnlockedVaultSession? session,
    ResumeUnlockAction? resumeAction,
    bool clearMessage = false,
    bool clearSession = false,
    bool clearResumeAction = false,
  }) {
    return AppSessionState(
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
      session: clearSession ? null : (session ?? this.session),
      resumeAction: clearResumeAction ? null : (resumeAction ?? this.resumeAction),
    );
  }
}
