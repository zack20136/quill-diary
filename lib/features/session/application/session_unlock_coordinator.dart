import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/session_providers.dart';
import '../session_messages.dart';
import '../state/app_session_state.dart';
import '../state/resume_unlock_action.dart';
import '../state/unlock_result.dart';

/// 依 [AppSessionState.resumeAction] 自動觸發解鎖或裝置螢幕鎖備援。
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
        case ResumeUnlockAction.deviceCredentialFallback:
          await _unlockWithDeviceCredentialFallback();
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

  Future<void> _unlockWithDeviceCredentialFallback() async {
    final AppSessionController controller = ref.read(appSessionProvider.notifier);
    final UnlockOutcome outcome = await controller.unlock(deviceCredentialFallback: true);
    if (outcome == UnlockOutcome.failed) {
      _showUnlockFailedSnackBar();
    }
  }

  void _showUnlockFailedSnackBar() {
    final BuildContext context = ref.context;
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(kUnlockFailedMessage)),
    );
  }
}
