import '../state/app_session_state.dart';

String blockedTitleForStatus(AppLockStatus status) {
  return switch (status) {
    AppLockStatus.locked => '日記庫已鎖定',
    AppLockStatus.recoveryRequired => '需要復原金鑰',
    AppLockStatus.fatalError => '無法啟動',
    _ => '請稍候',
  };
}

String blockedSubtitleForState(AppSessionState state) {
  if (state.message != null && state.message!.isNotEmpty) {
    return state.message!;
  }
  return switch (state.status) {
    AppLockStatus.locked => '請完成驗證以繼續',
    AppLockStatus.recoveryRequired => '請輸入復原金鑰解鎖',
    AppLockStatus.fatalError => '請檢查設定或重新啟動應用程式',
    _ => '',
  };
}
