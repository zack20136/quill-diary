import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';

void main() {
  group('DisplayFormat', () {
    const DateOnly date = DateOnly('2026-06-09');
    final DateTime local = DateTime(2026, 6, 9, 14, 30);
    final AppLocalizations zhTwL10n = lookupAppLocalizations(appZhLocale);
    final AppLocalizations enL10n = lookupAppLocalizations(appEnLocale);

    test('formatDateOnly 依語系輸出日期', () {
      expect(DisplayFormat.formatDateOnly(zhTwL10n, date), '2026年6月9日');
      expect(DisplayFormat.formatDateOnly(enL10n, date), '2026/06/09');
    });

    test('formatDateOnlyWithWeekday 依語系附加星期', () {
      expect(
        DisplayFormat.formatDateOnlyWithWeekday(zhTwL10n, date),
        '2026年6月9日 星期二',
      );
      expect(
        DisplayFormat.formatDateOnlyWithWeekday(enL10n, date),
        '2026/06/09 Tue',
      );
    });

    test('formatYearMonth 依語系輸出年月', () {
      expect(DisplayFormat.formatYearMonth(zhTwL10n, 2026, 6), '2026年6月');
      expect(DisplayFormat.formatYearMonth(enL10n, 2026, 6), 'Jun 2026');
    });

    test('formatYear 依語系輸出年份', () {
      expect(DisplayFormat.formatYear(zhTwL10n, 2026), '2026年');
      expect(DisplayFormat.formatYear(enL10n, 2026), '2026');
    });

    test('formatDateTime 依語系輸出日期時間', () {
      expect(
        DisplayFormat.formatDateTime(zhTwL10n, local),
        '2026年6月9日 14:30',
      );
      expect(DisplayFormat.formatDateTime(enL10n, local), '2026/06/09 14:30');
    });

    test('formatCountUnit 與 formatRatio', () {
      expect(DisplayFormat.formatCountUnit(3, '天'), '3 天');
      expect(DisplayFormat.formatRatio(1, 30, '天'), '1 / 30 天');
    });

    test('formatDurationMs 依語系輸出單位', () {
      expect(DisplayFormat.formatDurationMs(zhTwL10n, 350), '350 毫秒');
      expect(DisplayFormat.formatDurationMs(zhTwL10n, 1200), '1.2 秒');
      expect(DisplayFormat.formatDurationMs(zhTwL10n, 10000), '10 秒');
      expect(DisplayFormat.formatDurationMs(enL10n, 350), '350 ms');
      expect(DisplayFormat.formatDurationMs(enL10n, 1200), '1.2 sec');
      expect(DisplayFormat.formatDurationMs(enL10n, 10000), '10 sec');
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

    test('formatSavedFileNameForDisplay 從 Android SAF content URI 取出檔名', () {
      expect(
        DisplayFormat.formatSavedFileNameForDisplay(
          'content://com.android.externalstorage.documents/document/'
          'primary%3ADownload%2Fquill%2Fbackup_2026-06-10_03-16-01.zip',
        ),
        'backup_2026-06-10_03-16-01.zip',
      );
    });

    test('formatSavedFileNameForDisplay 從一般路徑取出檔名', () {
      expect(
        DisplayFormat.formatSavedFileNameForDisplay(
          r'C:\Users\me\Downloads\backup_2026-06-10_03-16-01.zip',
        ),
        'backup_2026-06-10_03-16-01.zip',
      );
      expect(
        DisplayFormat.formatSavedFileNameForDisplay(
          '/home/me/Downloads/markdown_2026-06-10_03-16-01.zip',
        ),
        'markdown_2026-06-10_03-16-01.zip',
      );
    });

    test('formatSavedFileNameForDisplay 邊界情況', () {
      expect(DisplayFormat.formatSavedFileNameForDisplay(''), '');
      expect(
        DisplayFormat.formatSavedFileNameForDisplay('backup.zip'),
        'backup.zip',
      );
      expect(
        DisplayFormat.formatSavedFileNameForDisplay('content://invalid'),
        'invalid',
      );
    });

    test('formatGoogleAccountLabel', () {
      expect(
        DisplayFormat.formatGoogleAccountLabel(
          zhTwL10n,
          'Alice',
          'a@example.com',
        ),
        'Alice · a@example.com',
      );
      expect(
        DisplayFormat.formatGoogleAccountLabel(
          enL10n,
          'Alice',
          'a@example.com',
        ),
        'Alice · a@example.com',
      );
    });
  });
}
