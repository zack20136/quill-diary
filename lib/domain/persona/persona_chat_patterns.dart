import 'package:quill_diary/domain/shared/value_objects.dart';

/// 行首日期，可帶星期，例如 `2026/11/05（四）` 或 `2026.07.31 Friday`。
final RegExp textChatDateLine = RegExp(
  r'^(\d{4})[/.\-](\d{1,2})[/.\-](\d{1,2})(?:\s*(?:[（(][^）)]+[）)]|\S+))?\s*$',
);

String? textChatDay(String year, String month, String day) {
  final value = '$year-${month.padLeft(2, '0')}-${day.padLeft(2, '0')}';
  return DateOnly.tryParse(value)?.value;
}

/// 上午、下午與正午 12 點換算成 24 小時制。超出 23:59 回傳 null。
String? formatTextChatClock({
  required int hour,
  required int minute,
  String? marker,
}) {
  final period = marker?.toLowerCase();
  var normalized = hour;
  if (period == '下午' || period == '午後' || period == 'pm') {
    if (normalized < 12) normalized += 12;
  } else if ((period == '上午' || period == '午前' || period == 'am') &&
      normalized == 12) {
    normalized = 0;
  }
  if (normalized > 23 || minute > 59) return null;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(normalized)}:${two(minute)}:00';
}

/// 把拆開的上午、下午標記與時、分拼回一個時間欄。
String joinTextChatClock(
  String? prefix,
  String hour,
  String minute,
  String? suffix,
) {
  if (prefix != null && prefix.isNotEmpty) return '$prefix $hour:$minute';
  if (suffix != null && suffix.isNotEmpty) return '$hour:$minute $suffix';
  return '$hour:$minute';
}
