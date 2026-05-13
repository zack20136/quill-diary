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
  });

  final AppLockStatus status;
  final String? message;

  bool get isUnlocked => status == AppLockStatus.unlocked;

  AppSessionState copyWith({
    AppLockStatus? status,
    String? message,
    bool clearMessage = false,
  }) {
    return AppSessionState(
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
