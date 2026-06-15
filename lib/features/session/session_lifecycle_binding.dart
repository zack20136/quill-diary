import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_inactivity_watchdog.dart';
import 'providers/session_providers.dart';

/// 將 App 生命週期與使用者互動接到 session 背景逾時與自動 reauth。
class SessionLifecycleBinding with WidgetsBindingObserver {
  SessionLifecycleBinding(this.ref);

  final WidgetRef ref;
  bool _attached = false;

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
        controller.notifyAppBackground();
        break;
      case AppLifecycleState.resumed:
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
    if (!_attached || !controller.shouldAutoReauth) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_attached || !controller.shouldAutoReauth) {
        return;
      }
      unawaited(controller.unlock());
    });
  }

  Widget wrap(Widget child) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onPointerDown(),
      child: child,
    );
  }
}
