import '../../domain/shared/value_objects.dart';

/// 繁體中文完整星期名稱（星期一 … 星期日），供日記列表與編輯器共用。
const List<String> kWeekdayNamesZhLong = <String>[
  '星期一',
  '星期二',
  '星期三',
  '星期四',
  '星期五',
  '星期六',
  '星期日',
];

String weekdayZhLong(DateTime dateTime) => kWeekdayNamesZhLong[dateTime.weekday - 1];

String weekdayZhLongFromDateOnly(DateOnly date) => weekdayZhLong(date.toDateTime());
