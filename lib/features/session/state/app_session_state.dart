import '../../../domain/security/unlocked_vault_session.dart';
import 'session_lock_reason.dart';

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
    this.lockReason,
  });

  final AppLockStatus status;
  final String? message;
  final UnlockedVaultSession? session;

  /// 僅在 [status] 為 [AppLockStatus.locked] 時有意義。
  final SessionLockReason? lockReason;

  bool get isUnlocked => status == AppLockStatus.unlocked;

  bool get shouldUnlockOnResume => status == AppLockStatus.locked;

  AppSessionState copyWith({
    AppLockStatus? status,
    String? message,
    UnlockedVaultSession? session,
    SessionLockReason? lockReason,
    bool clearMessage = false,
    bool clearSession = false,
    bool clearLockReason = false,
  }) {
    return AppSessionState(
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
      session: clearSession ? null : (session ?? this.session),
      lockReason: clearLockReason ? null : (lockReason ?? this.lockReason),
    );
  }
}
