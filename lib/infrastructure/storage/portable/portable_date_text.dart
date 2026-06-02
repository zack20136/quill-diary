import '../../../domain/diary/diary_entry.dart';
import '../../../domain/shared/value_objects.dart';

/// Quill Lock HTML 匯出用的 entry-date 字串（日記日期 + 建立時間）。
String formatQuillLockExportEntryDateTime(DiaryEntry entry) {
  final DateTime local = entry.createdAt.toLocal();
  return '${entry.date.value} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

/// 從可攜式文字解析日期時間（支援 `2026-05-28 16:00` 等格式）。
DateTime? parsePortableDateTime(String text) {
  final Match? ymdTime = RegExp(
    r'(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})[ T](\d{1,2}):(\d{2})(?::(\d{2}))?',
  ).firstMatch(text);
  if (ymdTime != null) {
    return DateTime(
      int.parse(ymdTime.group(1)!),
      int.parse(ymdTime.group(2)!),
      int.parse(ymdTime.group(3)!),
      int.parse(ymdTime.group(4)!),
      int.parse(ymdTime.group(5)!),
      ymdTime.group(6) != null ? int.parse(ymdTime.group(6)!) : 0,
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
  final Match? ymd = RegExp(r'(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(text);
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

/// 由 HTML entry-date 與 fallback 推導匯入日記的日期與時間戳。
({DateOnly date, DateTime createdAt, DateTime updatedAt}) resolveQuillLockImportEntryTimes({
  required String? dateText,
  required DateTime fallback,
}) {
  final DateOnly date = dateText == null
      ? DateOnly.fromDateTime(fallback)
      : (parsePortableDateOnly(dateText) ?? DateOnly.fromDateTime(fallback));
  final DateTime? parsed = dateText == null ? null : parsePortableDateTime(dateText);
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
