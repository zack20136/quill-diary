import '../../../domain/diary/diary_entry.dart';
import '../../../domain/shared/value_objects.dart';

const List<String> _zhTwWeekdayLong = <String>[
  '星期一',
  '星期二',
  '星期三',
  '星期四',
  '星期五',
  '星期六',
  '星期日',
];

/// Quill Diary HTML 匯出用的條目日期字串（日記日期 + 星期 + 建立時間）。
///
/// 格式：`2026-10-31 星期六 10:14`。星期依 [DiaryEntry.date]，時間依 [DiaryEntry.createdAt] 本地時區。
String formatQuillDiaryExportEntryDateTime(DiaryEntry entry) {
  final DateTime day = entry.date.toDateTime();
  final DateTime local = entry.createdAt.toLocal();
  return '${entry.date.value} '
      '${_zhTwWeekdayLong[day.weekday - 1]} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

/// 從可攜式文字解析日期時間（`2026-10-31 星期六 10:14` 等）。
DateTime? parsePortableDateTime(String text) {
  final Match? ymdWeekdayTime = RegExp(
    r'(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})'
    r'\s+星期[一二三四五六日]'
    r'\s+(\d{1,2}):(\d{2})(?::(\d{2}))?',
  ).firstMatch(text);
  if (ymdWeekdayTime != null) {
    return DateTime(
      int.parse(ymdWeekdayTime.group(1)!),
      int.parse(ymdWeekdayTime.group(2)!),
      int.parse(ymdWeekdayTime.group(3)!),
      int.parse(ymdWeekdayTime.group(4)!),
      int.parse(ymdWeekdayTime.group(5)!),
      ymdWeekdayTime.group(6) != null ? int.parse(ymdWeekdayTime.group(6)!) : 0,
    );
  }

  final Match? cjkTime = RegExp(
    r'(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日'
    r'(?:\s*星期[一二三四五六日])?'
    r'\s*(上午|下午)?\s*(\d{1,2}):(\d{2})(?::(\d{2}))?',
  ).firstMatch(text);
  if (cjkTime != null) {
    return DateTime(
      int.parse(cjkTime.group(1)!),
      int.parse(cjkTime.group(2)!),
      int.parse(cjkTime.group(3)!),
      _hourFromChinesePeriod(
        hour: int.parse(cjkTime.group(5)!),
        period: cjkTime.group(4),
      ),
      int.parse(cjkTime.group(6)!),
      cjkTime.group(7) != null ? int.parse(cjkTime.group(7)!) : 0,
    );
  }

  return null;
}

/// 從可攜式文字解析 [DateOnly]。
DateOnly? parsePortableDateOnly(String text) {
  final Match? ymd = RegExp(
    r'(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})',
  ).firstMatch(text);
  if (ymd != null) {
    return DateOnly(
      '${ymd.group(1)}-${_pad2(ymd.group(2))}-${_pad2(ymd.group(3))}',
    );
  }

  final Match? korean = RegExp(
    r'(\d{4})\s*년\s*(\d{1,2})\s*월\s*(\d{1,2})\s*일',
  ).firstMatch(text);
  if (korean != null) {
    return DateOnly(
      '${korean.group(1)}-${_pad2(korean.group(2))}-${_pad2(korean.group(3))}',
    );
  }

  final Match? cjk = RegExp(
    r'(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日',
  ).firstMatch(text);
  if (cjk != null) {
    return DateOnly(
      '${cjk.group(1)}-${_pad2(cjk.group(2))}-${_pad2(cjk.group(3))}',
    );
  }

  return null;
}

/// 由 HTML 條目日期與後備值推導匯入日記的日期與時間戳。
({DateOnly date, DateTime createdAt, DateTime updatedAt})
resolveQuillDiaryImportEntryTimes({
  required String? dateText,
  required DateTime fallback,
}) {
  final DateOnly date = dateText == null
      ? DateOnly.fromDateTime(fallback)
      : (parsePortableDateOnly(dateText) ?? DateOnly.fromDateTime(fallback));
  final DateTime? parsed = dateText == null
      ? null
      : parsePortableDateTime(dateText);
  final DateTime timestamp = parsed ?? fallback;
  return (date: date, createdAt: timestamp, updatedAt: timestamp);
}

int _hourFromChinesePeriod({required int hour, String? period}) {
  if (period == '下午' && hour < 12) {
    return hour + 12;
  }
  if (period == '上午' && hour == 12) {
    return 0;
  }
  return hour;
}

String _pad2(String? value) {
  final int parsed = int.tryParse(value ?? '') ?? 1;
  return parsed.toString().padLeft(2, '0');
}
