import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../config/app_identifiers.dart';
import '../../domain/shared/value_objects.dart';
import '../../l10n/l10n.dart';
import '../utils/weekday_zh.dart';

/// App 內使用者可見的日期、時間、數量與檔案大小格式化（單一來源）。
abstract final class DisplayFormat {
  static bool _isEnglish(AppLocalizations l10n) =>
      l10n.localeName.startsWith('en');

  static String formatDateOnly(AppLocalizations l10n, DateOnly date) {
    return _isEnglish(l10n)
        ? DateFormat.yMd('en').format(date.toDateTime())
        : formatDateOnlyZh(date);
  }

  static String formatDateOnlyWithWeekday(
    AppLocalizations l10n,
    DateOnly date,
  ) {
    final DateTime local = date.toDateTime();
    if (_isEnglish(l10n)) {
      return '${DateFormat.yMd('en').format(local)} ${DateFormat('EEE', 'en').format(local)}';
    }
    return formatDateOnlyWithWeekdayZh(date);
  }

  static String formatYearMonth(AppLocalizations l10n, int year, int month) {
    if (_isEnglish(l10n)) {
      return DateFormat('MMM yyyy', 'en').format(DateTime(year, month));
    }
    return formatYearMonthZh(year, month);
  }

  static String formatYear(AppLocalizations l10n, int year) {
    return _isEnglish(l10n) ? '$year' : formatYearZh(year);
  }

  static String formatDateTime(AppLocalizations l10n, DateTime local) {
    final DateTime value = local.toLocal();
    if (_isEnglish(l10n)) {
      return '${DateFormat.yMd('en').format(value)} ${formatTime24h(value)}';
    }
    return formatDateTimeZh(value);
  }

  static String formatWeekdayAndTime(AppLocalizations l10n, DateOnly date, DateTime at) {
    if (_isEnglish(l10n)) {
      return '${DateFormat('EEE', 'en').format(date.toDateTime())} ${formatTime24h(at)}';
    }
    return '${weekdayZhLongFromDateOnly(date)} ${formatTime24h(at)}';
  }

  static String formatCharCount(AppLocalizations l10n, int count) {
    return formatCountUnit(count, _isEnglish(l10n) ? 'chars' : '字');
  }

  /// 中文日期：`2026年6月9日`。
  static String formatDateOnlyZh(DateOnly date) {
    return _formatDatePartZh(date.toDateTime());
  }

  /// 中文日期加星期：`2026年6月9日 星期一`。
  static String formatDateOnlyWithWeekdayZh(DateOnly date) {
    final DateTime local = date.toDateTime();
    return '${_formatDatePartZh(local)} ${weekdayZhLong(local)}';
  }

  /// 中文年月：`2026年6月`。
  static String formatYearMonthZh(int year, int month) {
    try {
      return DateFormat('yyyy年M月', 'zh_Hant').format(DateTime(year, month));
    } catch (_) {
      return DateFormat('yyyy年M月').format(DateTime(year, month));
    }
  }

  /// 中文年：`2026年`。
  static String formatYearZh(int year) => '$year年';

  /// 中文日期時間：`2026年6月9日 14:30`。
  static String formatDateTimeZh(DateTime local) {
    final DateTime value = local.toLocal();
    return '${_formatDatePartZh(value)} ${formatTime24h(value)}';
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
  static String formatDurationMs(int milliseconds) {
    if (milliseconds < 1000) {
      return formatCountUnit(milliseconds, '毫秒');
    }
    final double seconds = milliseconds / 1000;
    if (seconds < 10) {
      return '${seconds.toStringAsFixed(1)} 秒';
    }
    return formatCountUnit(seconds.round(), '秒');
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
  static String formatGoogleAccountLabel(String name, String email) {
    final String trimmedName = name.trim();
    final String trimmedEmail = email.trim();
    if (trimmedName.isEmpty) {
      return trimmedEmail;
    }
    if (trimmedEmail.isEmpty) {
      return trimmedName;
    }
    return '$trimmedName · $trimmedEmail';
  }

  static String _formatDatePartZh(DateTime date) {
    try {
      return DateFormat('yyyy年M月d日', 'zh_Hant').format(date);
    } catch (_) {
      return DateFormat('yyyy年M月d日').format(date);
    }
  }
}
