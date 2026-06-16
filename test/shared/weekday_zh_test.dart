import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/shared/utils/weekday_zh.dart';

void main() {
  test(
    'weekdayZhLong returns Monday through Sunday in Traditional Chinese',
    () {
      expect(weekdayZhLong(DateTime.parse('2026-06-01')), '星期一');
      expect(weekdayZhLong(DateTime.parse('2026-06-02')), '星期二');
      expect(weekdayZhLong(DateTime.parse('2026-06-03')), '星期三');
      expect(weekdayZhLong(DateTime.parse('2026-06-04')), '星期四');
      expect(weekdayZhLong(DateTime.parse('2026-06-05')), '星期五');
      expect(weekdayZhLong(DateTime.parse('2026-06-06')), '星期六');
      expect(weekdayZhLong(DateTime.parse('2026-06-07')), '星期日');
    },
  );

  test('weekdayZhLongFromDateOnly matches weekdayZhLong', () {
    const DateOnly date = DateOnly('2026-06-03');
    expect(weekdayZhLongFromDateOnly(date), weekdayZhLong(date.toDateTime()));
  });
}
