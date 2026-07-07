import 'dart:async' show Timer;

import 'package:flutter/foundation.dart';

import 'session_inactivity_watchdog.dart';
import 'state/app_session_state.dart';

enum SessionStartupPhase {
  bootstrapping,
  awaitingFirstBackground,
  resumeUnlockArmed,
}

class SessionResumeCoordinator {
  SessionResumeCoordinator({
    SessionInactivityWatchdog? inactivityWatchdog,
  }) : _inactivityWatchdog = inactivityWatchdog ?? SessionInactivityWatchdog();

  final SessionInactivityWatchdog _inactivityWatchdog;
  int _activeSensitiveTasks = 0;
  bool _pendingResourceCleanup = false;
  bool _isInForeground = true;
  SessionStartupPhase _startupPhase = SessionStartupPhase.bootstrapping;
  int _startupCycleId = 0;
  Timer? _resumeArmTimer;

  @visibleForTesting
  SessionInactivityWatchdog get inactivityWatchdog => _inactivityWatchdog;

  bool get trustedUnlockBootstrapFinished =>
      _startupPhase != SessionStartupPhase.bootstrapping;

  bool get trustedUnlockBootstrapActive =>
      _startupPhase == SessionStartupPhase.bootstrapping;

  SessionStartupPhase get startupPhase => _startupPhase;

  int get startupCycleId => _startupCycleId;

  bool shouldUnlockOnResume(AppSessionState state) => state.shouldUnlockOnResume;

  bool canRecordLifecycleBackground(
    AppSessionState state,
    Future<Object?>? trustedUnlockInFlight,
  ) {
    return canParticipateInLifecycleResumeUnlock(state, trustedUnlockInFlight) &&
        _startupPhase == SessionStartupPhase.resumeUnlockArmed;
  }

  bool canScheduleLifecycleResumeUnlock(
    AppSessionState state,
    Future<Object?>? trustedUnlockInFlight,
  ) {
    return canParticipateInLifecycleResumeUnlock(state, trustedUnlockInFlight) &&
        _startupPhase == SessionStartupPhase.resumeUnlockArmed;
  }

  bool canParticipateInLifecycleResumeUnlock(
    AppSessionState state,
    Future<Object?>? trustedUnlockInFlight,
  ) {
    return _startupPhase != SessionStartupPhase.bootstrapping &&
        state.status != AppLockStatus.unlocking &&
        trustedUnlockInFlight == null;
  }

  void dispose() {
    _inactivityWatchdog.disarm();
    _cancelResumeArmTimer();
  }

  void reset() {
    _inactivityWatchdog.disarm();
    _activeSensitiveTasks = 0;
    _pendingResourceCleanup = false;
    _cancelResumeArmTimer();
    _startupPhase = SessionStartupPhase.bootstrapping;
  }

  void beginPostRestoreStartup() {
    _inactivityWatchdog.disarm();
    _activeSensitiveTasks = 0;
    _pendingResourceCleanup = false;
    _cancelResumeArmTimer();
    _startupPhase = SessionStartupPhase.bootstrapping;
  }

  void endTrustedUnlockBootstrap(AppSessionState state) {
    if (_startupPhase != SessionStartupPhase.bootstrapping) {
      return;
    }
    _startupCycleId++;
    _startupPhase = SessionStartupPhase.awaitingFirstBackground;
    _scheduleResumeUnlockArmAfterBootstrapSettle(state);
  }

  void armLifecycleResumeUnlock() {
    _cancelResumeArmTimer();
    if (_startupPhase == SessionStartupPhase.awaitingFirstBackground) {
      _startupPhase = SessionStartupPhase.resumeUnlockArmed;
    }
  }

  void notifyAppBackground({
    required AppSessionState state,
    required VoidCallback saveCurrentRouteBeforeBackground,
  }) {
    _isInForeground = false;
    if (state.isUnlocked) {
      saveCurrentRouteBeforeBackground();
    }
    if (!_shouldWatchInactivity(state)) {
      return;
    }
    _inactivityWatchdog.notifyBackground();
  }

  Future<ForegroundResumeResult> notifyAppForegroundResumed({
    VoidCallback? onForegroundSettled,
  }) {
    _isInForeground = true;
    return _inactivityWatchdog.notifyForegroundResumed(
      onForegroundSettled: onForegroundSettled ?? () {},
    );
  }

  void notifyUserInteraction(AppSessionState state) {
    if (!state.isUnlocked) {
      return;
    }
    _inactivityWatchdog.notifyUserInteraction();
  }

  void onSessionUnlocked({
    required AppSessionState state,
    required Duration timeout,
    required Future<void> Function() onExpired,
  }) {
    _inactivityWatchdog.disarm();
    if (!_shouldWatchInactivity(state)) {
      return;
    }
    _inactivityWatchdog.arm(timeout: timeout, onExpired: onExpired);
    if (!_isInForeground) {
      _inactivityWatchdog.notifyBackground();
    }
  }

  Future<T> runProtectedTask<T>({
    required Future<T> Function() action,
    required bool Function() isSessionStillUnlocked,
    required VoidCallback onUnlockedStateStillActive,
    required Future<void> Function() cleanupUnlockedResourcesIfPossible,
  }) async {
    _inactivityWatchdog.disarm();
    _activeSensitiveTasks++;
    try {
      return await action();
    } finally {
      _activeSensitiveTasks--;
      if (isSessionStillUnlocked()) {
        onUnlockedStateStillActive();
      }
      await cleanupUnlockedResourcesIfPossible();
    }
  }

  void markPendingCleanup() {
    _pendingResourceCleanup = true;
  }

  Future<void> cleanupUnlockedResourcesIfPossible(
    Future<void> Function() cleanupAction,
  ) async {
    if (!_pendingResourceCleanup || _activeSensitiveTasks > 0) {
      return;
    }
    _pendingResourceCleanup = false;
    await cleanupAction();
  }

  void disarm() {
    _inactivityWatchdog.disarm();
  }

  bool hasActiveSensitiveTasks() => _activeSensitiveTasks > 0;

  void _scheduleResumeUnlockArmAfterBootstrapSettle(AppSessionState state) {
    _cancelResumeArmTimer();
    if (_startupPhase != SessionStartupPhase.awaitingFirstBackground) {
      return;
    }
    if (!state.isUnlocked || state.session == null) {
      return;
    }
    _resumeArmTimer = Timer(kSessionForegroundSettleDelay, () {
      _resumeArmTimer = null;
      if (_startupPhase != SessionStartupPhase.awaitingFirstBackground) {
        return;
      }
      if (!state.isUnlocked || state.session == null) {
        return;
      }
      armLifecycleResumeUnlock();
    });
  }

  void _cancelResumeArmTimer() {
    _resumeArmTimer?.cancel();
    _resumeArmTimer = null;
  }

  bool _shouldWatchInactivity(AppSessionState state) =>
      state.isUnlocked && _activeSensitiveTasks == 0;
}
