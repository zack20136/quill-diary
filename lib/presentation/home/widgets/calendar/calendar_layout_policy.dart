library;

import '../../../../l10n/l10n.dart';
import '../../../../shared/presentation/display_format.dart';
import '../../home_formatters.dart';

const int kCalendarMaxEntriesPerCell = 2;
const int kCalendarPreviewCharCount = 5;

const double kCalendarShellPaddingHorizontal = 6;
const double kCalendarShellPaddingTop = 8;
const double kCalendarShellPaddingBottom = 6;
const double kCalendarShellVerticalInset =
    kCalendarShellPaddingTop + kCalendarShellPaddingBottom;
const double kCalendarHeaderHeight = 50;
const double kCalendarDaysOfWeekHeight = 22;
const double kCalendarRowCount = 6;
const double kCalendarHeightSafetyBuffer = 10;

bool calendarIsSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String calendarWeekdayLabel(AppLocalizations l10n, DateTime day) {
  return calendarWeekdayLabels(l10n)[day.weekday % 7];
}

String calendarMonthTitle(AppLocalizations l10n, DateTime month) {
  return DisplayFormat.formatYearMonth(l10n, month.year, month.month);
}

bool calendarIsSunday(DateTime day) => day.weekday == DateTime.sunday;

bool calendarIsSaturday(DateTime day) => day.weekday == DateTime.saturday;

String calendarEntryPreviewLabel(String text) {
  final String trimmedText = text.trim();
  if (trimmedText.isEmpty) {
    return trimmedText;
  }
  if (trimmedText.length <= kCalendarPreviewCharCount) {
    return trimmedText;
  }
  return trimmedText.substring(0, kCalendarPreviewCharCount);
}

double calendarRowHeightForAvailableHeight(
  double availableHeight, {
  double textScale = 1,
}) {
  if (availableHeight <=
      kCalendarHeaderHeight + kCalendarDaysOfWeekHeight + 1) {
    return 40;
  }

  final double textScaleBuffer = textScale > 1 ? (textScale - 1) * 14 : 0;
  final double availableForRows =
      availableHeight -
      kCalendarHeaderHeight -
      kCalendarDaysOfWeekHeight -
      kCalendarHeightSafetyBuffer -
      textScaleBuffer;
  return (availableForRows / kCalendarRowCount).floorToDouble().clamp(
    46.0,
    72.0,
  );
}

double calendarContentHeight(double rowHeight) {
  return kCalendarHeaderHeight +
      kCalendarDaysOfWeekHeight +
      kCalendarRowCount * rowHeight;
}

bool calendarShouldShowEntryTitles(double rowHeight) => rowHeight >= 46;

double calendarEntryFontSize(double rowHeight) {
  if (rowHeight >= 60) {
    return 8;
  }
  return 7.5;
}
