import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import 'session_route_snapshot.dart';
import 'state/app_session_state.dart';
import 'state/session_lock_reason.dart';
import 'state/unlock_result.dart';

enum SessionNavigationAction { restore, goHome }

class SessionNavigationRequest {
  const SessionNavigationRequest._({
    required this.action,
    this.location,
  });

  const SessionNavigationRequest.restore(String location)
    : this._(action: SessionNavigationAction.restore, location: location);

  const SessionNavigationRequest.goHome()
    : this._(action: SessionNavigationAction.goHome);

  final SessionNavigationAction action;
  final String? location;
}

class SessionNavigationRequestController
    extends Notifier<SessionNavigationRequest?> {
  @override
  SessionNavigationRequest? build() => null;

  void publish(SessionNavigationRequest request) {
    state = request;
  }

  void clear() {
    state = null;
  }
}

final sessionNavigationRequestProvider =
    NotifierProvider<SessionNavigationRequestController, SessionNavigationRequest?>(
      SessionNavigationRequestController.new,
    );

final sessionNavigationCoordinatorProvider = Provider<SessionNavigationCoordinator>(
  (Ref ref) => SessionNavigationCoordinator(ref),
);

class SessionNavigationCoordinator {
  const SessionNavigationCoordinator(this._ref);

  final Ref _ref;

  void bindLocationResolver(String Function() resolver) {
    _ref
        .read(sessionRouteSnapshotProvider.notifier)
        .bindLocationResolver(resolver);
  }

  void saveCurrentRouteBeforeBackground() {
    _ref
        .read(sessionRouteSnapshotProvider.notifier)
        .saveCurrentRouteBeforeBackground();
  }

  void saveLockedRestoreRoute() {
    _ref.read(sessionRouteSnapshotProvider.notifier).saveLockedRestoreRoute();
  }

  void clearRouteSnapshot() {
    _ref.read(sessionRouteSnapshotProvider.notifier).clear();
  }

  void publishUnlockNavigation(SessionUnlockResultEvent event, AppSessionState nextState) {
    if (event.source != UnlockRequestSource.lifecycleResume) {
      return;
    }
    final SessionRouteSnapshotState snapshot = _ref.read(
      sessionRouteSnapshotProvider,
    );
    final SessionNavigationRequest? request = resolveSessionNavigationRequest(
      event: event,
      snapshot: snapshot,
      nextState: nextState,
    );
    if (request != null) {
      _ref.read(sessionNavigationRequestProvider.notifier).publish(request);
    }
    if (request != null || event.outcome == UnlockOutcome.failed) {
      clearRouteSnapshot();
    }
  }
}

SessionNavigationRequest? resolveSessionNavigationRequest({
  required SessionUnlockResultEvent event,
  required SessionRouteSnapshotState snapshot,
  required AppSessionState nextState,
}) {
  if (event.outcome == UnlockOutcome.success &&
      snapshot.savedForInactivityLock) {
    final String? target = snapshot.pendingRestoreLocation;
    if (target != null && isSessionRestorableRoute(target)) {
      return SessionNavigationRequest.restore(target);
    }
  }
  if (event.outcome == UnlockOutcome.failed &&
      nextState.status == AppLockStatus.locked &&
      _shouldGoHomeAfterResumeUnlockFailure(
        lockReason: nextState.lockReason,
        recoverable: event.recoverable,
      )) {
    return const SessionNavigationRequest.goHome();
  }
  return null;
}

bool _shouldGoHomeAfterResumeUnlockFailure({
  required SessionLockReason? lockReason,
  required bool recoverable,
}) {
  return lockReason == SessionLockReason.authFailed ||
      (recoverable && lockReason == SessionLockReason.inactivity);
}

String sessionNavigationLocation(SessionNavigationRequest request) {
  switch (request.action) {
    case SessionNavigationAction.restore:
      return request.location ?? AppRouter.homeRoute;
    case SessionNavigationAction.goHome:
      return AppRouter.homeRoute;
  }
}
