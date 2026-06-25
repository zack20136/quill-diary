import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import 'state/app_session_state.dart';
import 'state/session_lock_reason.dart';
import 'state/unlock_result.dart';

enum SessionRouteNavigationAction { none, restore, goHome }

/// 背景逾時後 lifecycle resume 解鎖完成時，應執行的路由動作（不含 GoRouter 呼叫）。
SessionRouteNavigationAction resolveLifecycleResumeRouteAction({
  required UnlockOutcome outcome,
  required bool recoverable,
  required bool savedForInactivityLock,
  required String? pendingRestoreLocation,
  required AppSessionState nextState,
}) {
  if (outcome == UnlockOutcome.success &&
      savedForInactivityLock &&
      pendingRestoreLocation != null) {
    return SessionRouteNavigationAction.restore;
  }
  if (outcome == UnlockOutcome.failed &&
      nextState.status == AppLockStatus.locked &&
      _shouldGoHomeAfterResumeUnlockFailure(
        lockReason: nextState.lockReason,
        recoverable: recoverable,
      )) {
    return SessionRouteNavigationAction.goHome;
  }
  return SessionRouteNavigationAction.none;
}

bool _shouldGoHomeAfterResumeUnlockFailure({
  required SessionLockReason? lockReason,
  required bool recoverable,
}) {
  return lockReason == SessionLockReason.authFailed ||
      (recoverable && lockReason == SessionLockReason.inactivity);
}

String? restoreTargetLocation(SessionRoutePreservationState preservation) {
  final String? location = preservation.pendingRestoreLocation;
  if (location == null || !isPreservableAppRoute(location)) {
    return null;
  }
  return location;
}

/// 背景逾時鎖定前後的路由保存狀態，供 resume 解鎖後還原或失敗時回首頁。
class SessionRoutePreservationState {
  const SessionRoutePreservationState({
    this.pendingRestoreLocation,
    this.savedForInactivityLock = false,
    this.preBackgroundLocation,
  });

  final String? pendingRestoreLocation;
  final bool savedForInactivityLock;
  final String? preBackgroundLocation;

  SessionRoutePreservationState copyWith({
    String? pendingRestoreLocation,
    bool? savedForInactivityLock,
    String? preBackgroundLocation,
  }) {
    return SessionRoutePreservationState(
      pendingRestoreLocation:
          pendingRestoreLocation ?? this.pendingRestoreLocation,
      savedForInactivityLock:
          savedForInactivityLock ?? this.savedForInactivityLock,
      preBackgroundLocation:
          preBackgroundLocation ?? this.preBackgroundLocation,
    );
  }
}

/// 是否為可保存／還原的站內路由。
bool isPreservableAppRoute(String location) {
  final String normalized = location.trim();
  if (normalized.isEmpty) {
    return false;
  }
  final String path = Uri.parse(
    normalized.startsWith('/') ? normalized : '/$normalized',
  ).path;
  return path == AppRouter.homeRoute ||
      path == AppRouter.editorRoute ||
      path.startsWith('${AppRouter.editorRoute}/') ||
      path == AppRouter.settingsRoute ||
      path.startsWith('${AppRouter.settingsRoute}/');
}

class SessionRoutePreservationController
    extends Notifier<SessionRoutePreservationState> {
  String Function()? _resolveLocation;

  @override
  SessionRoutePreservationState build() {
    return const SessionRoutePreservationState();
  }

  void bindLocationResolver(String Function() resolver) {
    _resolveLocation = resolver;
  }

  String _resolveCurrentLocation() {
    return _resolveLocation?.call() ?? AppRouter.homeRoute;
  }

  void savePreBackgroundLocation([String? location]) {
    final String resolved = location ?? _resolveCurrentLocation();
    if (!isPreservableAppRoute(resolved)) {
      return;
    }
    state = state.copyWith(preBackgroundLocation: resolved);
  }

  void onInactivityLock([String? location]) {
    String resolved = location ?? _resolveCurrentLocation();
    if (!isPreservableAppRoute(resolved)) {
      final String? fallback = state.preBackgroundLocation;
      if (fallback != null && isPreservableAppRoute(fallback)) {
        resolved = fallback;
      } else {
        return;
      }
    }
    state = SessionRoutePreservationState(
      pendingRestoreLocation: resolved,
      savedForInactivityLock: true,
      preBackgroundLocation: state.preBackgroundLocation,
    );
  }

  void clear() {
    state = const SessionRoutePreservationState();
  }
}

final sessionRoutePreservationProvider =
    NotifierProvider<
      SessionRoutePreservationController,
      SessionRoutePreservationState
    >(SessionRoutePreservationController.new);
