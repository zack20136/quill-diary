import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/session_providers.dart';

/// 將 App 生命週期與使用者互動接到 session 背景逾時與 resumed 自動解鎖。
class SessionLifecycleBinding with WidgetsBindingObserver {
  SessionLifecycleBinding(
    this.ref, {
    this.resumeUnlockDelay = const Duration(milliseconds: 350),
  });

  final WidgetRef ref;
  final Duration resumeUnlockDelay;
  bool _attached = false;
  bool _isForeground = true;
  bool _wasBackgrounded = false;
  int _resumeUnlockToken = 0;
  int _lastStartupCycleId = 0;

  void attach() {
    if (_attached) {
      return;
    }
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void detach() {
    if (!_attached) {
      return;
    }
    clearStaleLifecycleState();
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
  }

  /// bootstrap 週期結束時清掉同次啟動累積的 stale 背景狀態。
  void clearStaleLifecycleState() {
    _wasBackgrounded = false;
    _cancelPendingResumeUnlock();
  }

  void _syncStartupCycle(AppSessionController controller) {
    final int cycleId = controller.startupCycleId;
    if (cycleId == _lastStartupCycleId) {
      return;
    }
    _lastStartupCycleId = cycleId;
    clearStaleLifecycleState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_handleLifecycleChange(state));
  }

  void onPointerDown() {
    ref.read(appSessionProvider.notifier).notifyUserInteraction();
  }

  Future<void> _handleLifecycleChange(AppLifecycleState state) async {
    final AppSessionController controller = ref.read(
      appSessionProvider.notifier,
    );
    _syncStartupCycle(controller);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _isForeground = false;
        if (controller.canRecordLifecycleBackground) {
          controller.recordFirstLifecycleBackground();
          _wasBackgrounded = true;
        }
        _cancelPendingResumeUnlock();
        controller.notifyAppBackground();
        break;
      case AppLifecycleState.resumed:
        _isForeground = true;
        await controller.notifyAppForegroundResumed();
        final bool shouldScheduleResumeUnlock =
            controller.canScheduleLifecycleResumeUnlock &&
            _wasBackgrounded &&
            controller.shouldUnlockOnResume;
        _wasBackgrounded = false;
        if (shouldScheduleResumeUnlock) {
          _scheduleResumeUnlockIfNeeded(controller);
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _scheduleResumeUnlockIfNeeded(AppSessionController controller) {
    if (!_attached ||
        !_isForeground ||
        !controller.canScheduleLifecycleResumeUnlock ||
        !controller.shouldUnlockOnResume) {
      return;
    }
    final int token = ++_resumeUnlockToken;
    unawaited(_runResumeUnlock(controller, token: token));
  }

  void _cancelPendingResumeUnlock() {
    _resumeUnlockToken++;
  }

  Future<void> _runResumeUnlock(
    AppSessionController controller, {
    required int token,
  }) async {
    if (resumeUnlockDelay > Duration.zero) {
      await Future<void>.delayed(resumeUnlockDelay);
    }
    if (!_canRunResumeUnlock(controller, token)) {
      return;
    }
    await controller.unlock(source: UnlockRequestSource.lifecycleResume);
  }

  bool _canRunResumeUnlock(AppSessionController controller, int token) {
    return _attached &&
        _isForeground &&
        token == _resumeUnlockToken &&
        controller.canScheduleLifecycleResumeUnlock &&
        controller.shouldUnlockOnResume;
  }

  Widget wrap(Widget child) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onPointerDown(),
      child: child,
    );
  }
}
