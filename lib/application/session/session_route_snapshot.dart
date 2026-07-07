import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/app/router.dart';

class SessionRouteSnapshotState {
  const SessionRouteSnapshotState({
    this.pendingRestoreLocation,
    this.savedForInactivityLock = false,
    this.preBackgroundLocation,
  });

  final String? pendingRestoreLocation;
  final bool savedForInactivityLock;
  final String? preBackgroundLocation;

  SessionRouteSnapshotState copyWith({
    String? pendingRestoreLocation,
    bool? savedForInactivityLock,
    String? preBackgroundLocation,
  }) {
    return SessionRouteSnapshotState(
      pendingRestoreLocation:
          pendingRestoreLocation ?? this.pendingRestoreLocation,
      savedForInactivityLock:
          savedForInactivityLock ?? this.savedForInactivityLock,
      preBackgroundLocation:
          preBackgroundLocation ?? this.preBackgroundLocation,
    );
  }
}

bool isSessionRestorableRoute(String location) {
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

class SessionRouteSnapshotController
    extends Notifier<SessionRouteSnapshotState> {
  String Function()? _resolveLocation;

  @override
  SessionRouteSnapshotState build() {
    return const SessionRouteSnapshotState();
  }

  void bindLocationResolver(String Function() resolver) {
    _resolveLocation = resolver;
  }

  String _resolveCurrentLocation() {
    return _resolveLocation?.call() ?? AppRouter.homeRoute;
  }

  void saveCurrentRouteBeforeBackground([String? location]) {
    final String resolved = location ?? _resolveCurrentLocation();
    if (!isSessionRestorableRoute(resolved)) {
      return;
    }
    state = state.copyWith(preBackgroundLocation: resolved);
  }

  void saveLockedRestoreRoute([String? location]) {
    String resolved = location ?? _resolveCurrentLocation();
    if (!isSessionRestorableRoute(resolved)) {
      final String? fallback = state.preBackgroundLocation;
      if (fallback != null && isSessionRestorableRoute(fallback)) {
        resolved = fallback;
      } else {
        return;
      }
    }
    state = SessionRouteSnapshotState(
      pendingRestoreLocation: resolved,
      savedForInactivityLock: true,
      preBackgroundLocation: state.preBackgroundLocation,
    );
  }

  void clear() {
    state = const SessionRouteSnapshotState();
  }
}

final sessionRouteSnapshotProvider =
    NotifierProvider<SessionRouteSnapshotController, SessionRouteSnapshotState>(
      SessionRouteSnapshotController.new,
    );
