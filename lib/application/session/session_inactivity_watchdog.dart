import 'dart:async';

import 'package:flutter/foundation.dart';

import 'session_timeout_policy.dart';

enum ForegroundResumeResult { none, expired, waitingForSettle }

class SessionInactivityWatchdog {
  SessionInactivityWatchdog({DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  DateTime Function() clock;
  Duration foregroundSettleDelay = kSessionForegroundSettleDelay;

  Duration _timeout = kDefaultSessionBackgroundTimeout;
  Future<void> Function()? _onExpired;
  bool _armed = false;
  DateTime? _backgroundSince;
  Timer? _backgroundTimer;
  Timer? _foregroundSettleTimer;

  bool get isArmed => _armed;

  @visibleForTesting
  DateTime? get backgroundSince => _backgroundSince;

  void arm({
    required Duration timeout,
    required Future<void> Function() onExpired,
  }) {
    disarm();
    _armed = true;
    _timeout = timeout;
    _onExpired = onExpired;
  }

  void disarm() {
    _armed = false;
    _onExpired = null;
    _backgroundSince = null;
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    _foregroundSettleTimer?.cancel();
    _foregroundSettleTimer = null;
  }

  void notifyBackground() {
    if (!_armed) {
      return;
    }
    _foregroundSettleTimer?.cancel();
    _foregroundSettleTimer = null;
    _backgroundSince ??= clock();
    _scheduleBackgroundTimer();
  }

  Future<ForegroundResumeResult> notifyForegroundResumed({
    required VoidCallback onForegroundSettled,
  }) async {
    if (!_armed || _backgroundSince == null) {
      return ForegroundResumeResult.none;
    }
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    if (_isExpired) {
      await _fireExpired();
      return ForegroundResumeResult.expired;
    }
    _foregroundSettleTimer?.cancel();
    if (foregroundSettleDelay <= Duration.zero) {
      _confirmForegroundSettled(onForegroundSettled);
      return ForegroundResumeResult.none;
    }
    _foregroundSettleTimer = Timer(foregroundSettleDelay, () {
      _foregroundSettleTimer = null;
      if (!_armed || _backgroundSince == null) {
        return;
      }
      _confirmForegroundSettled(onForegroundSettled);
    });
    return ForegroundResumeResult.waitingForSettle;
  }

  void notifyUserInteraction() {
    if (!_armed) {
      return;
    }
    _foregroundSettleTimer?.cancel();
    _foregroundSettleTimer = null;
    _clearBackgroundTracking();
  }

  bool get _isExpired {
    final DateTime? since = _backgroundSince;
    if (since == null) {
      return false;
    }
    return hasSessionTimedOut(
      lastForegroundExitAt: since,
      now: clock(),
      timeout: _timeout,
    );
  }

  void _scheduleBackgroundTimer() {
    final DateTime? since = _backgroundSince;
    if (since == null) {
      return;
    }
    _backgroundTimer?.cancel();
    final Duration remaining = _timeout - clock().difference(since);
    if (remaining <= Duration.zero) {
      unawaited(_fireExpired());
      return;
    }
    _backgroundTimer = Timer(remaining, () {
      unawaited(_fireExpired());
    });
  }

  void _confirmForegroundSettled(VoidCallback onForegroundSettled) {
    _clearBackgroundTracking();
    onForegroundSettled();
  }

  void _clearBackgroundTracking() {
    _backgroundSince = null;
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }

  Future<void> _fireExpired() async {
    _foregroundSettleTimer?.cancel();
    _foregroundSettleTimer = null;
    _clearBackgroundTracking();
    final Future<void> Function()? callback = _onExpired;
    if (callback != null) {
      await callback();
    }
  }
}
