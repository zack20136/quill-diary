import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/session/session_inactivity_watchdog.dart';
import 'package:quill_diary/features/session/session_timeout_policy.dart';

void main() {
  test('armed 後 notifyBackground 會記錄起點並在逾時後觸發 onExpired', () async {
    DateTime fakeNow = DateTime.utc(2026, 5, 19, 12, 0);
    final SessionInactivityWatchdog watchdog = SessionInactivityWatchdog(
      clock: () => fakeNow,
    );
    int expiredCount = 0;
    watchdog.arm(
      timeout: defaultSessionTimeout,
      onExpired: () async => expiredCount++,
    );

    watchdog.notifyBackground();
    expect(watchdog.backgroundSince, fakeNow);

    fakeNow = fakeNow.add(defaultSessionTimeout + const Duration(seconds: 1));
    final ForegroundResumeResult result = await watchdog
        .notifyForegroundResumed(onForegroundSettled: () {});

    expect(result, ForegroundResumeResult.expired);
    expect(expiredCount, 1);
    expect(watchdog.backgroundSince, isNull);
  });

  test('resumed 後前景穩定期完成會清掉背景計時', () async {
    DateTime fakeNow = DateTime.utc(2026, 5, 19, 12, 0);
    final SessionInactivityWatchdog watchdog = SessionInactivityWatchdog(
      clock: () => fakeNow,
    );
    watchdog.foregroundSettleDelay = const Duration(milliseconds: 10);
    int settledCount = 0;
    watchdog.arm(timeout: defaultSessionTimeout, onExpired: () async {});

    watchdog.notifyBackground();
    fakeNow = fakeNow.add(const Duration(minutes: 1));
    final ForegroundResumeResult result = await watchdog
        .notifyForegroundResumed(onForegroundSettled: () => settledCount++);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(result, ForegroundResumeResult.waitingForSettle);
    expect(settledCount, 1);
    expect(watchdog.backgroundSince, isNull);
  });

  test('未 armed 時 notifyBackground 不會開始計時', () {
    final SessionInactivityWatchdog watchdog = SessionInactivityWatchdog();
    watchdog.notifyBackground();
    expect(watchdog.backgroundSince, isNull);
  });

  test('notifyUserInteraction 會取消背景計時', () async {
    DateTime fakeNow = DateTime.utc(2026, 5, 19, 12, 0);
    final SessionInactivityWatchdog watchdog = SessionInactivityWatchdog(
      clock: () => fakeNow,
    );
    int expiredCount = 0;
    watchdog.arm(
      timeout: defaultSessionTimeout,
      onExpired: () async => expiredCount++,
    );

    watchdog.notifyBackground();
    watchdog.notifyUserInteraction();
    fakeNow = fakeNow.add(defaultSessionTimeout + const Duration(seconds: 1));
    final ForegroundResumeResult result = await watchdog
        .notifyForegroundResumed(onForegroundSettled: () {});

    expect(result, ForegroundResumeResult.none);
    expect(expiredCount, 0);
    expect(watchdog.backgroundSince, isNull);
  });

  test('disarm 會清除計時狀態', () async {
    DateTime fakeNow = DateTime.utc(2026, 5, 19, 12, 0);
    final SessionInactivityWatchdog watchdog = SessionInactivityWatchdog(
      clock: () => fakeNow,
    );
    int expiredCount = 0;
    watchdog.arm(
      timeout: defaultSessionTimeout,
      onExpired: () async => expiredCount++,
    );
    watchdog.notifyBackground();
    watchdog.disarm();

    fakeNow = fakeNow.add(defaultSessionTimeout + const Duration(seconds: 1));
    final ForegroundResumeResult result = await watchdog
        .notifyForegroundResumed(onForegroundSettled: () {});

    expect(result, ForegroundResumeResult.none);
    expect(expiredCount, 0);
  });
}
