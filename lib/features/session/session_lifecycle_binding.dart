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
  int _resumeUnlockToken = 0;

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
    _cancelPendingResumeUnlock();
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
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
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _isForeground = false;
        _cancelPendingResumeUnlock();
        controller.notifyAppBackground();
        break;
      case AppLifecycleState.resumed:
        _isForeground = true;
        await controller.notifyAppForegroundResumed(
          onForegroundSettled: () => _scheduleResumeUnlockIfNeeded(controller),
        );
        if (controller.shouldUnlockOnResume) {
          _scheduleResumeUnlockIfNeeded(controller);
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _scheduleResumeUnlockIfNeeded(AppSessionController controller) {
    if (!_attached || !_isForeground || !controller.shouldUnlockOnResume) {
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
