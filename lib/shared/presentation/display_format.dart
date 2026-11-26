import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/app_identifiers.dart';

/// App 內使用者可見的日期、時間、數量與檔案大小格式化（單一來源）。
abstract final class DisplayFormat {
  static const List<String> _englishMonthShort = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _englishWeekdayShort = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> _zhTwWeekdayLong = <String>[
    '星期一',
    '星期二',
    '星期三',
    '星期四',
    '星期五',
    '星期六',
    '星期日',
  ];

  static String formatDateOnly(AppLocalizations l10n, DateOnly date) {
    final DateTime value = date.toDateTime();
    if (isEnglishL10n(l10n)) {
      return _formatNumericDate(value);
    }
    return '${value.year}年${value.month}月${value.day}日';
  }

  static String formatYearMonth(AppLocalizations l10n, int year, int month) {
    if (isEnglishL10n(l10n)) {
      return '${_englishMonthShort[month - 1]} $year';
    }
    return '$year年$month月';
  }

  static String formatYear(AppLocalizations l10n, int year) {
    return isEnglishL10n(l10n) ? '$year' : '$year年';
  }

  static String formatMonth(AppLocalizations l10n, int month) {
    return isEnglishL10n(l10n) ? _englishMonthShort[month - 1] : '$month 月';
  }

  /// 人物生日只顯示月日。
  static String formatBirthday(
    AppLocalizations l10n, {
    required int month,
    required int day,
  }) {
    if (isEnglishL10n(l10n)) {
      return '${_englishMonthShort[month - 1]} $day';
    }
    return '$month月$day日';
  }

  /// 相對「今天」的日距（本地日曆）；用於上次提及等摘要。
  static String formatRelativeDayDistance(
    AppLocalizations l10n,
    DateOnly date, {
    DateTime? now,
  }) {
    final DateOnly today = DateOnly.fromDateTime(now ?? DateTime.now());
    final int daysAgo = _utcCalendarDay(today)
        .difference(_utcCalendarDay(date))
        .inDays;
    return switch (daysAgo) {
      0 => l10n.commonRelativeToday,
      1 => l10n.commonRelativeYesterday,
      < 0 => l10n.commonRelativeDaysFromNow(-daysAgo),
      _ => l10n.commonRelativeDaysAgo(daysAgo),
    };
  }

  static DateTime _utcCalendarDay(DateOnly date) {
    final day = date.toDateTime();
    return DateTime.utc(day.year, day.month, day.day);
  }

  static DateTime combineEntryDateTime(
    DateOnly date, {
    required int hour,
    required int minute,
  }) {
    final DateTime day = date.toDateTime();
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  static String formatEntryDateTime(
    AppLocalizations l10n,
    DateOnly date, {
    required int hour,
    required int minute,
  }) {
    final DateTime value = combineEntryDateTime(
      date,
      hour: hour,
      minute: minute,
    );
    final String weekday = isEnglishL10n(l10n)
        ? _englishWeekdayShort[value.weekday - 1]
        : _zhTwWeekdayLong[value.weekday - 1];
    return '${_formatNumericDate(value)} ${formatTime24h(value)} · $weekday';
  }

  static String formatDateTime(AppLocalizations l10n, DateTime local) {
    final DateTime value = local.toLocal();
    final weekday = isEnglishL10n(l10n)
        ? _englishWeekdayShort[value.weekday - 1]
        : _zhTwWeekdayLong[value.weekday - 1];
    return '${formatDateTimeWithoutWeekday(l10n, value)} · $weekday';
  }

  /// 日期時間，不含星期（備份狀態等簡短摘要用）。
  static String formatDateTimeWithoutWeekday(
    AppLocalizations l10n,
    DateTime local,
  ) {
    final DateTime value = local.toLocal();
    if (isEnglishL10n(l10n)) {
      return '${_formatNumericDate(value)} ${formatTime24h(value)}';
    }
    return '${value.year}年${value.month}月${value.day}日 ${formatTime24h(value)}';
  }

  static String formatWeekdayAndTime(
    AppLocalizations l10n,
    DateOnly date,
    DateTime at,
  ) {
    if (isEnglishL10n(l10n)) {
      return '${_englishWeekdayShort[date.toDateTime().weekday - 1]} ${formatTime24h(at)}';
    }
    return '${_zhTwWeekdayLong[date.toDateTime().weekday - 1]} ${formatTime24h(at)}';
  }

  static String _formatNumericDate(DateTime value) {
    final String year = value.year.toString().padLeft(4, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }

  /// 24 小時制時間：`14:30`。
  static String formatTime24h(DateTime local) {
    return DateFormat('HH:mm').format(local.toLocal());
  }

  /// 檔案大小：`1.2 MB`。
  static String formatBytesForDisplay(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final double kib = bytes / 1024;
    if (kib < 1024) {
      return '${kib.toStringAsFixed(kib >= 10 ? 0 : 1)} KB';
    }
    final double mib = kib / 1024;
    if (mib < 1024) {
      return '${mib.toStringAsFixed(mib >= 10 ? 0 : 1)} MB';
    }
    final double gib = mib / 1024;
    return '${gib.toStringAsFixed(gib >= 10 ? 0 : 1)} GB';
  }

  /// 從本機路徑或 Android SAF content URI 取出可讀檔名。
  static String formatSavedFileNameForDisplay(String savedPathOrUri) {
    final String trimmed = savedPathOrUri.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    if (trimmed.startsWith('content://')) {
      try {
        final Uri uri = Uri.parse(trimmed);
        if (uri.pathSegments.isNotEmpty) {
          final String documentId = Uri.decodeComponent(uri.pathSegments.last);
          final int colonIndex = documentId.indexOf(':');
          final String pathPart = colonIndex >= 0
              ? documentId.substring(colonIndex + 1)
              : documentId;
          final String fileName = p.basename(pathPart);
          if (fileName.isNotEmpty) {
            return fileName;
          }
        }
      } on Object {
        // 解析失敗時改走一般路徑後備。
      }
    }
    return p.basename(trimmed);
  }

  /// Google 帳戶顯示：`名稱 · email@example.com`。
  static String formatGoogleAccountLabel(
    AppLocalizations l10n,
    String name,
    String email,
  ) {
    final String trimmedName = name.trim();
    final String trimmedEmail = email.trim();
    if (trimmedName.isEmpty) {
      return trimmedEmail;
    }
    if (trimmedEmail.isEmpty) {
      return trimmedName;
    }
    return l10n.commonGoogleAccountLabel(trimmedName, trimmedEmail);
  }

  static String formatPicturesDisplayPath(String fileName) =>
      'Pictures / ${AppIdentifiers.downloadsExportDirectory} / $fileName';
}
