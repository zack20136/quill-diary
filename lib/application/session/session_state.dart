import 'package:quill_diary/domain/security/unlocked_vault_session.dart';

enum SessionFailure { unreadableIndex }

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
    this.failure,
    this.session,
    this.lockReason,
  });

  final AppLockStatus status;
  final String? message;
  final SessionFailure? failure;
  final UnlockedVaultSession? session;

  final SessionLockReason? lockReason;

  bool get isUnlocked => status == AppLockStatus.unlocked;

  bool get shouldUnlockOnResume =>
      status == AppLockStatus.locked && lockReason != SessionLockReason.manual;

  AppSessionState copyWith({
    AppLockStatus? status,
    String? message,
    SessionFailure? failure,
    UnlockedVaultSession? session,
    SessionLockReason? lockReason,
    bool clearMessage = false,
    bool clearSession = false,
    bool clearLockReason = false,
  }) {
    return AppSessionState(
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
      failure: clearMessage ? null : (failure ?? this.failure),
      session: clearSession ? null : (session ?? this.session),
      lockReason: clearLockReason ? null : (lockReason ?? this.lockReason),
    );
  }
}

/// 應用程式進入 [AppLockStatus.locked] 的原因。
enum SessionLockReason {
  /// 背景逾時；回到前景時應自動重新驗證。
  inactivity,

  /// 使用者手動鎖定。
  manual,

  /// 可信裝置驗證取消或失敗。
  authFailed,
}

enum UnlockRequestSource { manual, lifecycleResume }

enum UnlockOutcome { success, failed }

class SessionUnlockResultEvent {
  const SessionUnlockResultEvent({
    required this.source,
    required this.outcome,
    this.recoverable = false,
  });

  final UnlockRequestSource source;
  final UnlockOutcome outcome;
  final bool recoverable;
}
