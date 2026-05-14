import '../../domain/security/unlocked_vault_session.dart';

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
  });

  final AppLockStatus status;
  final String? message;
  final UnlockedVaultSession? session;

  bool get isUnlocked => status == AppLockStatus.unlocked;

  AppSessionState copyWith({
    AppLockStatus? status,
    String? message,
    UnlockedVaultSession? session,
    bool clearMessage = false,
    bool clearSession = false,
  }) {
    return AppSessionState(
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
      session: clearSession ? null : (session ?? this.session),
    );
  }
}
