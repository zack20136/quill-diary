import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../config/app_identifiers.dart';
import '../../domain/shared/value_objects.dart';
import '../../l10n/l10n.dart';

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
      return _formatEnglishDate(value);
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
    return formatDateTime(
      l10n,
      combineEntryDateTime(date, hour: hour, minute: minute),
    );
  }

  static String formatDateTime(AppLocalizations l10n, DateTime local) {
    final DateTime value = local.toLocal();
    if (isEnglishL10n(l10n)) {
      return '${_formatEnglishDate(value)} ${formatTime24h(value)} · ${_englishWeekdayShort[value.weekday - 1]}';
    }
    return '${value.year}年${value.month}月${value.day}日 ${formatTime24h(value)} · ${_zhTwWeekdayLong[value.weekday - 1]}';
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

  static String _formatEnglishDate(DateTime value) {
    final String year = value.year.toString().padLeft(4, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }

  static String formatCharCount(AppLocalizations l10n, int count) {
    return formatCountUnit(count, l10n.commonUnitCharacters);
  }

  /// 24 小時制時間：`14:30`。
  static String formatTime24h(DateTime local) {
    return DateFormat('HH:mm').format(local.toLocal());
  }

  /// 數字與量詞：`3 天`、`5 篇`。
  static String formatCountUnit(num count, String unit) => '$count $unit';

  /// 比例與量詞：`1 / 30 天`。
  static String formatRatio(int numerator, int denominator, String unit) =>
      '$numerator / $denominator $unit';

  /// 耗時：`350 毫秒` 或 `1.2 秒`。
  static String formatDurationMs(AppLocalizations l10n, int milliseconds) {
    if (milliseconds < 1000) {
      return formatCountUnit(milliseconds, l10n.commonUnitMilliseconds);
    }
    final double seconds = milliseconds / 1000;
    if (seconds < 10) {
      return '${seconds.toStringAsFixed(1)} ${l10n.commonUnitSeconds}';
    }
    return formatCountUnit(seconds.round(), l10n.commonUnitSeconds);
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

  /// Downloads 匯出路徑：`Downloads / quill-diary / file.html`。
  static String formatDownloadsDisplayPath(String fileName) {
    return 'Downloads / ${AppIdentifiers.downloadsExportDirectory} / $fileName';
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

  /// Google 帳號顯示：`名稱 · email@example.com`。
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
}
