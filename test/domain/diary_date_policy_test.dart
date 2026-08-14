import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/diary/diary_date_policy.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

void main() {
  test('可選日期從 2000 年開始並動態延伸到明年年底', () {
    final range = DiaryDatePolicy.selectableRange(now: DateTime(2026, 8, 13));

    expect(range.first, DateTime(2000));
    expect(range.last, DateTime(2027, 12, 31));
  });

  test('既有範圍外日期會擴展可選範圍而不修改原值', () {
    final early = DiaryDatePolicy.selectableRange(
      now: DateTime(2026, 8, 13),
      includedDate: const DateOnly('1988-02-29'),
    );
    final late = DiaryDatePolicy.selectableRange(
      now: DateTime(2026, 8, 13),
      includedDate: const DateOnly('2035-06-01'),
    );

    expect(early.first, DateTime(1988, 2, 29));
    expect(early.last, DateTime(2027, 12, 31));
    expect(late.first, DateTime(2000));
    expect(late.last, DateTime(2035, 6, 1));
  });
}
