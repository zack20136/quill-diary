import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';

void main() {
  group('DisplayFormat', () {
    const DateOnly date = DateOnly('2026-06-09');
    final DateTime local = DateTime(2026, 6, 9, 14, 30);

    test('formatDateOnlyZh 使用中文年月日', () {
      expect(DisplayFormat.formatDateOnlyZh(date), '2026年6月9日');
    });

    test('formatDateOnlyWithWeekdayZh 附加星期', () {
      expect(
        DisplayFormat.formatDateOnlyWithWeekdayZh(date),
        '2026年6月9日 星期二',
      );
    });

    test('formatYearMonthZh 不含日', () {
      expect(DisplayFormat.formatYearMonthZh(2026, 6), '2026年6月');
    });

    test('formatYearZh', () {
      expect(DisplayFormat.formatYearZh(2026), '2026年');
    });

    test('formatDateTimeZh', () {
      expect(DisplayFormat.formatDateTimeZh(local), '2026年6月9日 14:30');
    });

    test('formatCountUnit 與 formatRatio', () {
      expect(DisplayFormat.formatCountUnit(3, '天'), '3 天');
      expect(DisplayFormat.formatRatio(1, 30, '天'), '1 / 30 天');
    });

    test('formatDurationMs', () {
      expect(DisplayFormat.formatDurationMs(350), '350 毫秒');
      expect(DisplayFormat.formatDurationMs(1200), '1.2 秒');
      expect(DisplayFormat.formatDurationMs(10000), '10 秒');
    });

    test('formatBytesForDisplay', () {
      expect(DisplayFormat.formatBytesForDisplay(512), '512 B');
      expect(DisplayFormat.formatBytesForDisplay(1536), '1.5 KB');
    });

    test('formatDownloadsDisplayPath', () {
      expect(
        DisplayFormat.formatDownloadsDisplayPath('diary.html'),
        'Downloads / quill-diary / diary.html',
      );
    });

    test('formatGoogleAccountLabel', () {
      expect(
        DisplayFormat.formatGoogleAccountLabel('Alice', 'a@example.com'),
        'Alice · a@example.com',
      );
    });
  });
}
