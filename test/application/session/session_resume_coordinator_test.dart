import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/session/session_inactivity_watchdog.dart';
import 'package:quill_diary/application/session/session_resume_coordinator.dart';
import 'package:quill_diary/application/session/session_timeout_policy.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';

class _RecordingWatchdog extends SessionInactivityWatchdog {
  int armCalls = 0;
  int disarmCalls = 0;
  int backgroundCalls = 0;
  int userInteractionCalls = 0;
  Duration? lastTimeout;
  ForegroundResumeResult nextForegroundResult = ForegroundResumeResult.none;

  @override
  void arm({
    required Duration timeout,
    required Future<void> Function() onExpired,
  }) {
    armCalls++;
    lastTimeout = timeout;
  }

  @override
  void disarm() {
    disarmCalls++;
  }

  @override
  void notifyBackground() {
    backgroundCalls++;
  }

  @override
  Future<ForegroundResumeResult> notifyForegroundResumed({
    required void Function() onForegroundSettled,
  }) async {
    return nextForegroundResult;
  }

  @override
  void notifyUserInteraction() {
    userInteractionCalls++;
  }
}

void main() {
  group('SessionResumeCoordinator', () {
    test('解鎖後會依 timeout 重新 arm watchdog', () {
      final _RecordingWatchdog watchdog = _RecordingWatchdog();
      final SessionResumeCoordinator coordinator = SessionResumeCoordinator(
        inactivityWatchdog: watchdog,
      );
      final AppSessionState unlockedState = AppSessionState(
        status: AppLockStatus.unlocked,
        session: UnlockedVaultSession(
          vaultId: 'vault-session-coordinator',
          trustedDevice: true,
          recoveryWrapKey: const <int>[1, 2, 3],
        ),
      );

      coordinator.onSessionUnlocked(
        state: unlockedState,
        timeout: const Duration(minutes: 7),
        onExpired: () async {},
      );

      expect(watchdog.armCalls, 1);
      expect(watchdog.lastTimeout, const Duration(minutes: 7));
    });

    test('背景切回前景後，在穩定延遲後會 arm lifecycle resume unlock', () async {
      final SessionResumeCoordinator coordinator = SessionResumeCoordinator(
        inactivityWatchdog: _RecordingWatchdog(),
      );
      final AppSessionState unlockedState = AppSessionState(
        status: AppLockStatus.unlocked,
        session: UnlockedVaultSession(
          vaultId: 'vault-session-bootstrap',
          trustedDevice: true,
          recoveryWrapKey: const <int>[4, 5, 6],
        ),
      );

      coordinator.endTrustedUnlockBootstrap(unlockedState);
      await Future<void>.delayed(kSessionForegroundSettleDelay * 2);

      expect(coordinator.startupPhase, SessionStartupPhase.resumeUnlockArmed);
      expect(
        coordinator.canScheduleLifecycleResumeUnlock(unlockedState, null),
        isTrue,
      );
    });

    test('protected task 完成後會通知重設 watchdog 並做 cleanup', () async {
      final _RecordingWatchdog watchdog = _RecordingWatchdog();
      final SessionResumeCoordinator coordinator = SessionResumeCoordinator(
        inactivityWatchdog: watchdog,
      );
      var onUnlockedCalls = 0;
      var cleanupCalls = 0;

      final String result = await coordinator.runProtectedTask<String>(
        action: () async => 'done',
        isSessionStillUnlocked: () => true,
        onUnlockedStateStillActive: () => onUnlockedCalls++,
        cleanupUnlockedResourcesIfPossible: () async => cleanupCalls++,
      );

      expect(result, 'done');
      expect(watchdog.disarmCalls, greaterThan(0));
      expect(onUnlockedCalls, 1);
      expect(cleanupCalls, 1);
    });
  });
}
