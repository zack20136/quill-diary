import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/session/session_route_snapshot.dart';

void main() {
  test('saveLockedRestoreRoute 會 fallback 到背景前可還原路由', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final SessionRouteSnapshotController controller = container.read(
      sessionRouteSnapshotProvider.notifier,
    );
    controller.bindLocationResolver(() => '/dialog');
    controller.saveCurrentRouteBeforeBackground('/editor/entry-1');
    controller.saveLockedRestoreRoute();

    final SessionRouteSnapshotState state = container.read(
      sessionRouteSnapshotProvider,
    );
    expect(state.pendingRestoreLocation, '/editor/entry-1');
    expect(state.savedForInactivityLock, isTrue);
  });

  test('isSessionRestorableRoute 只接受 app 內可還原路由', () {
    expect(isSessionRestorableRoute('/'), isTrue);
    expect(isSessionRestorableRoute('/editor/entry-1'), isTrue);
    expect(isSessionRestorableRoute('/settings/support'), isTrue);
    expect(isSessionRestorableRoute('/dialog'), isFalse);
    expect(isSessionRestorableRoute(''), isFalse);
  });
}
