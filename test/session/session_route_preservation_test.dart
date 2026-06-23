import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/session/session_route_preservation.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/session/state/session_lock_reason.dart';
import 'package:quill_diary/features/session/state/unlock_result.dart';

void main() {
  test('isPreservableAppRoute 接受站內路由', () {
    expect(isPreservableAppRoute('/'), isTrue);
    expect(isPreservableAppRoute('/editor'), isTrue);
    expect(isPreservableAppRoute('/editor/abc'), isTrue);
    expect(isPreservableAppRoute('/settings'), isTrue);
    expect(isPreservableAppRoute('/settings/about'), isTrue);
    expect(isPreservableAppRoute('/unknown'), isFalse);
    expect(isPreservableAppRoute(''), isFalse);
  });

  test('onInactivityLock 保存 location', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final SessionRoutePreservationController controller = container.read(
      sessionRoutePreservationProvider.notifier,
    );
    controller.bindLocationResolver(() => '/editor/abc');
    controller.onInactivityLock();
    expect(
      container.read(sessionRoutePreservationProvider).pendingRestoreLocation,
      '/editor/abc',
    );
    expect(
      container.read(sessionRoutePreservationProvider).savedForInactivityLock,
      isTrue,
    );
  });

  test('resolveLifecycleResumeRouteAction 成功時還原', () {
    expect(
      resolveLifecycleResumeRouteAction(
        outcome: UnlockOutcome.success,
        recoverable: false,
        savedForInactivityLock: true,
        pendingRestoreLocation: '/editor/abc',
        nextState: const AppSessionState(status: AppLockStatus.unlocked),
      ),
      SessionRouteNavigationAction.restore,
    );
  });

  test('resolveLifecycleResumeRouteAction 取消時回首頁', () {
    expect(
      resolveLifecycleResumeRouteAction(
        outcome: UnlockOutcome.failed,
        recoverable: true,
        savedForInactivityLock: true,
        pendingRestoreLocation: '/editor/abc',
        nextState: const AppSessionState(
          status: AppLockStatus.locked,
          lockReason: SessionLockReason.inactivity,
        ),
      ),
      SessionRouteNavigationAction.goHome,
    );
  });

  test('resolveLifecycleResumeRouteAction AuthFailed 回首頁', () {
    expect(
      resolveLifecycleResumeRouteAction(
        outcome: UnlockOutcome.failed,
        recoverable: false,
        savedForInactivityLock: true,
        pendingRestoreLocation: '/editor/abc',
        nextState: const AppSessionState(
          status: AppLockStatus.locked,
          lockReason: SessionLockReason.authFailed,
        ),
      ),
      SessionRouteNavigationAction.goHome,
    );
  });

  test('resolveLifecycleResumeRouteAction manual 鎖定失敗不回首頁', () {
    expect(
      resolveLifecycleResumeRouteAction(
        outcome: UnlockOutcome.failed,
        recoverable: false,
        savedForInactivityLock: true,
        pendingRestoreLocation: '/editor/abc',
        nextState: const AppSessionState(
          status: AppLockStatus.locked,
          lockReason: SessionLockReason.manual,
        ),
      ),
      SessionRouteNavigationAction.none,
    );
  });
}
