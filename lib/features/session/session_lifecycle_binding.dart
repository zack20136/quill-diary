import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_inactivity_watchdog.dart';
import 'providers/session_providers.dart';
import 'state/unlock_result.dart';

/// 將 App 生命週期與使用者互動接到 session 背景逾時與自動 reauth。
class SessionLifecycleBinding with WidgetsBindingObserver {
  SessionLifecycleBinding(
    this.ref, {
    this.autoReauthDelay = const Duration(milliseconds: 350),
    this.autoReauthRetryDelay = const Duration(milliseconds: 700),
  });

  final WidgetRef ref;
  final Duration autoReauthDelay;
  final Duration autoReauthRetryDelay;
  bool _attached = false;
  bool _isForeground = true;
  int _autoReauthToken = 0;

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
    _cancelPendingAutoReauth();
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
    final AppSessionController controller = ref.read(appSessionProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _isForeground = false;
        _cancelPendingAutoReauth();
        controller.notifyAppBackground();
        break;
      case AppLifecycleState.resumed:
        _isForeground = true;
        final ForegroundResumeResult result = await controller
            .notifyAppForegroundResumed(
              onForegroundSettled: () => _scheduleAutoReauthIfNeeded(controller),
            );
        if (result == ForegroundResumeResult.expired) {
          _scheduleAutoReauthIfNeeded(controller);
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _scheduleAutoReauthIfNeeded(AppSessionController controller) {
    if (!_attached || !_isForeground || !controller.shouldAutoReauth) {
      return;
    }
    final int token = ++_autoReauthToken;
    unawaited(_runAutoReauthAttempt(controller, token: token));
  }

  void _cancelPendingAutoReauth() {
    _autoReauthToken++;
  }

  Future<void> _runAutoReauthAttempt(
    AppSessionController controller, {
    required int token,
    int attempt = 0,
  }) async {
    final Duration delay = attempt == 0 ? autoReauthDelay : autoReauthRetryDelay;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (!_canRunAutoReauth(controller, token)) {
      return;
    }
    final UnlockOutcome outcome = await controller.unlock(
      source: UnlockRequestSource.lifecycleResume,
    );
    if (outcome == UnlockOutcome.success) {
      return;
    }
    if (attempt > 0 || !_canRunAutoReauth(controller, token)) {
      return;
    }
    unawaited(_runAutoReauthAttempt(controller, token: token, attempt: attempt + 1));
  }

  bool _canRunAutoReauth(AppSessionController controller, int token) {
    return _attached &&
        _isForeground &&
        token == _autoReauthToken &&
        controller.shouldAutoReauth;
  }

  Widget wrap(Widget child) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onPointerDown(),
      child: child,
    );
  }
}
