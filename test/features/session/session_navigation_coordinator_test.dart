import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/session/session_navigation_coordinator.dart';
import 'package:quill_diary/features/session/session_route_snapshot.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/session/state/session_lock_reason.dart';
import 'package:quill_diary/features/session/state/unlock_result.dart';

void main() {
  test('lifecycle resume 成功且為 inactivity lock 時會還原先前路由', () {
    final SessionNavigationRequest? request = resolveSessionNavigationRequest(
      event: const SessionUnlockResultEvent(
        source: UnlockRequestSource.lifecycleResume,
        outcome: UnlockOutcome.success,
      ),
      snapshot: const SessionRouteSnapshotState(
        pendingRestoreLocation: '/editor/entry-1',
        savedForInactivityLock: true,
      ),
      nextState: const AppSessionState(status: AppLockStatus.unlocked),
    );

    expect(request, isNotNull);
    expect(request!.action, SessionNavigationAction.restore);
    expect(request.location, '/editor/entry-1');
  });

  test('lifecycle resume 驗證失敗時會回首頁', () {
    final SessionNavigationRequest? request = resolveSessionNavigationRequest(
      event: const SessionUnlockResultEvent(
        source: UnlockRequestSource.lifecycleResume,
        outcome: UnlockOutcome.failed,
      ),
      snapshot: const SessionRouteSnapshotState(),
      nextState: const AppSessionState(
        status: AppLockStatus.locked,
        lockReason: SessionLockReason.authFailed,
      ),
    );

    expect(request, isNotNull);
    expect(request!.action, SessionNavigationAction.goHome);
  });

  test('非法 restore 路由不會導頁', () {
    final SessionNavigationRequest? request = resolveSessionNavigationRequest(
      event: const SessionUnlockResultEvent(
        source: UnlockRequestSource.lifecycleResume,
        outcome: UnlockOutcome.success,
      ),
      snapshot: const SessionRouteSnapshotState(
        pendingRestoreLocation: '/not-allowed',
        savedForInactivityLock: true,
      ),
      nextState: const AppSessionState(status: AppLockStatus.unlocked),
    );

    expect(request, isNull);
  });
}
