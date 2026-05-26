import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/session_providers.dart';
import '../state/app_session_state.dart';
import '../state/resume_unlock_action.dart';

/// 依 [AppSessionState.resumeAction] 自動觸發解鎖。
class SessionUnlockCoordinator {
  SessionUnlockCoordinator(this.ref);

  final WidgetRef ref;
  bool _handling = false;

  void listen() {
    ref.listen(appSessionProvider, (AppSessionState? previous, AppSessionState next) {
      if (next.resumeAction == previous?.resumeAction) {
        return;
      }
      unawaited(_handleResumeAction(next.resumeAction));
    });
  }

  Future<void> _handleResumeAction(ResumeUnlockAction? action) async {
    if (action == null || _handling) {
      return;
    }
    _handling = true;
    try {
      switch (action) {
        case ResumeUnlockAction.autoTrusted:
        case ResumeUnlockAction.keystoreUnlock:
          await _unlockTrustedSession();
          return;
      }
    } finally {
      _handling = false;
    }
  }

  Future<void> _unlockTrustedSession() async {
    final AppSessionController controller = ref.read(appSessionProvider.notifier);
    await controller.unlock();
  }
}
