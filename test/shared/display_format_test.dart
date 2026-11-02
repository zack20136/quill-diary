import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';

import '../helpers/shared/test_l10n.dart';

void main() {
  test('日記工具列日期補零並保留時間、分隔符號及各語言星期', () {
    const date = DateOnly('2026-01-02');
    expect(
      DisplayFormat.formatEntryDateTime(testZhL10n, date, hour: 9, minute: 5),
      '2026/01/02 09:05 · 星期五',
    );
    expect(
      DisplayFormat.formatEntryDateTime(testEnL10n, date, hour: 9, minute: 5),
      '2026/01/02 09:05 · Fri',
    );
    expect(DisplayFormat.formatDateOnly(testZhL10n, date), '2026年1月2日');
    expect(
      DisplayFormat.formatDateTime(testZhL10n, DateTime(2026, 1, 2, 9, 5)),
      '2026年1月2日 09:05 · 星期五',
    );
  });

  test('上次提及日期為今天與昨天時顯示自然語句', () {
    final DateTime now = DateTime(2026, 8, 12);

    expect(
      DisplayFormat.formatRelativeDayDistance(
        testZhL10n,
        const DateOnly('2026-08-12'),
        now: now,
      ),
      '今天',
    );
    expect(
      DisplayFormat.formatRelativeDayDistance(
        testZhL10n,
        const DateOnly('2026-08-11'),
        now: now,
      ),
      '昨天',
    );
  });

  test('上次提及日期早於今天時顯示經過天數', () {
    expect(
      DisplayFormat.formatRelativeDayDistance(
        testZhL10n,
        const DateOnly('2026-08-09'),
        now: DateTime(2026, 8, 12),
      ),
      '3 天前',
    );
  });

  test('上次提及日期晚於今天時仍顯示為幾天前', () {
    expect(
      DisplayFormat.formatRelativeDayDistance(
        testZhL10n,
        const DateOnly('2026-08-15'),
        now: DateTime(2026, 8, 12),
      ),
      '3 天前',
    );
  });

  test('英文上次提及相差一天時使用單數 day', () {
    expect(
      DisplayFormat.formatRelativeDayDistance(
        testEnL10n,
        const DateOnly('2026-08-13'),
        now: DateTime(2026, 8, 12),
      ),
      '1 day ago',
    );
  });
}
