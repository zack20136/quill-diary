import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_date_text.dart';

void main() {
  group('formatQuillDiaryExportEntryDateTime', () {
    test('輸出含繁中星期的新格式', () {
      // 2026-10-31 是星期六
      final DiaryEntry entry = DiaryEntry(
        id: 'jrn_test',
        vaultId: 'vlt_test',
        title: '測試',
        date: const DateOnly('2026-10-31'),
        createdAt: DateTime(2026, 10, 31, 10, 14),
        updatedAt: DateTime(2026, 10, 31, 10, 14),
        markdownBody: '',
      );
      expect(
        formatQuillDiaryExportEntryDateTime(entry),
        '2026-10-31 星期六 10:14',
      );
    });

    test('星期依日記日期，時間依 createdAt', () {
      final DiaryEntry entry = DiaryEntry(
        id: 'jrn_test',
        vaultId: 'vlt_test',
        title: '測試',
        date: const DateOnly('2026-10-31'),
        createdAt: DateTime(2026, 11, 1, 9, 5),
        updatedAt: DateTime(2026, 11, 1, 9, 5),
        markdownBody: '',
      );
      expect(
        formatQuillDiaryExportEntryDateTime(entry),
        '2026-10-31 星期六 09:05',
      );
    });
  });

  group('parsePortableDateTime', () {
    test('解析含星期的新格式', () {
      final DateTime? parsed = parsePortableDateTime('2026-10-31 星期六 10:14');
      expect(parsed, isNotNull);
      expect(parsed!.year, 2026);
      expect(parsed.month, 10);
      expect(parsed.day, 31);
      expect(parsed.hour, 10);
      expect(parsed.minute, 14);
    });

    test('format／parse 往返保留時分', () {
      final DiaryEntry entry = DiaryEntry(
        id: 'jrn_test',
        vaultId: 'vlt_test',
        title: '測試',
        date: const DateOnly('2026-07-03'),
        createdAt: DateTime(2026, 7, 3, 16, 28),
        updatedAt: DateTime(2026, 7, 3, 16, 28),
        markdownBody: '',
      );
      final String formatted = formatQuillDiaryExportEntryDateTime(entry);
      final DateTime? parsed = parsePortableDateTime(formatted);
      expect(parsed, isNotNull);
      expect(parsed!.hour, 16);
      expect(parsed.minute, 28);
      expect(parsePortableDateOnly(formatted)?.value, '2026-07-03');
    });

    test('resolveQuillDiaryImportEntryTimes 使用新格式時間', () {
      final result = resolveQuillDiaryImportEntryTimes(
        dateText: '2026-10-31 星期六 10:14',
        fallback: DateTime(2000),
      );
      expect(result.date.value, '2026-10-31');
      expect(result.createdAt.hour, 10);
      expect(result.createdAt.minute, 14);
    });

    test('舊版無星期格式不解析時間', () {
      expect(parsePortableDateTime('2026-05-28 16:00'), isNull);
    });
  });
}
