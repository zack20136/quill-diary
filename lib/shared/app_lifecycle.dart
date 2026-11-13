import 'dart:ui';

/// 截圖與控制中心只會進入 [AppLifecycleState.inactive]，不算離開 App。
bool appLifecycleIsBackground(AppLifecycleState state) {
  return state == AppLifecycleState.hidden || state == AppLifecycleState.paused;
}
