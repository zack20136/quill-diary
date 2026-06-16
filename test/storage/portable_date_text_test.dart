import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_date_text.dart';

void main() {
  test('formatQuillDiaryExportEntryDateTime 輸出日期與本地時間', () {
    final DiaryEntry entry = DiaryEntry(
      id: 'jrn_TEST0001',
      vaultId: 'vlt_TEST',
      date: const DateOnly('2026-05-28'),
      createdAt: DateTime.parse('2026-05-28T08:00:00Z'),
      updatedAt: DateTime.parse('2026-05-28T09:00:00Z'),
      markdownBody: 'body',
    );

    expect(
      formatQuillDiaryExportEntryDateTime(entry),
      '2026-05-28 ${entry.createdAt.toLocal().hour.toString().padLeft(2, '0')}:'
      '${entry.createdAt.toLocal().minute.toString().padLeft(2, '0')}',
    );
  });

  test('resolveQuillDiaryImportEntryTimes 由 entry-date 還原時間', () {
    final ({DateOnly date, DateTime createdAt, DateTime updatedAt}) times =
        resolveQuillDiaryImportEntryTimes(
          dateText: '2026-05-28 16:30',
          fallback: DateTime.parse('2026-01-01T00:00:00'),
        );

    expect(times.date.value, '2026-05-28');
    expect(times.createdAt, DateTime(2026, 5, 28, 16, 30));
    expect(times.updatedAt, times.createdAt);
  });

  test('parsePortableDateOnly 可從含時間字串取日期', () {
    expect(parsePortableDateOnly('2026-05-28 16:30')?.value, '2026-05-28');
  });
}
