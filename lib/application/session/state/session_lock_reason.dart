/// 應用程式進入 [AppLockStatus.locked] 的原因。
enum SessionLockReason {
  /// 背景逾時；回到前景時應自動重新驗證。
  inactivity,

  /// 使用者手動鎖定。
  manual,

  /// 可信裝置驗證取消或失敗。
  authFailed,
}
