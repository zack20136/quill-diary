import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/session/session_timeout_policy.dart';
import 'package:quill_diary/l10n/l10n.dart';

void main() {
  final AppLocalizations zhL10n = lookupAppLocalizations(appZhLocale);

  test('未滿 3 分鐘不算 timeout', () {
    final DateTime exitAt = DateTime.utc(2026, 5, 18, 1, 0, 0);
    final DateTime now = exitAt.add(const Duration(minutes: 2, seconds: 59));

    expect(hasSessionTimedOut(lastForegroundExitAt: exitAt, now: now), isFalse);
  });

  test('滿 3 分鐘即算 timeout', () {
    final DateTime exitAt = DateTime.utc(2026, 5, 18, 1, 0, 0);
    final DateTime now = exitAt.add(defaultSessionTimeout);

    expect(hasSessionTimedOut(lastForegroundExitAt: exitAt, now: now), isTrue);
  });

  test('sessionBackgroundTimeoutLabel 格式化分鐘', () {
    expect(
      sessionBackgroundTimeoutLabel(defaultSessionTimeout, zhL10n),
      '3 分鐘',
    );
    expect(
      sessionBackgroundTimeoutLabel(const Duration(minutes: 3), zhL10n),
      '3 分鐘',
    );
    expect(
      sessionBackgroundTimeoutLabel(const Duration(minutes: 10), zhL10n),
      '10 分鐘',
    );
  });

  test('自訂 timeout 門檻', () {
    final DateTime exitAt = DateTime.utc(2026, 5, 18, 1, 0, 0);
    final DateTime now = exitAt.add(const Duration(minutes: 2));

    expect(
      hasSessionTimedOut(
        lastForegroundExitAt: exitAt,
        now: now,
        timeout: const Duration(minutes: 2),
      ),
      isTrue,
    );
    expect(
      hasSessionTimedOut(
        lastForegroundExitAt: exitAt,
        now: exitAt.add(const Duration(minutes: 1, seconds: 59)),
        timeout: const Duration(minutes: 2),
      ),
      isFalse,
    );
  });
}
