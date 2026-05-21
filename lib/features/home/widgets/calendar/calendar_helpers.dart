/// Shared helpers for the home calendar widgets.
library;

import 'package:flutter/material.dart';

const List<String> kCalendarWeekdayLabelsZh = <String>[
  '日',
  '一',
  '二',
  '三',
  '四',
  '五',
  '六',
];

const int kCalendarMaxEntriesPerCell = 2;
const int kCalendarPreviewCharCount = 5;

const double kCalendarShellPadding = 20;
const double kCalendarHeaderHeight = 48;
const double kCalendarDaysOfWeekHeight = 22;
const double kCalendarRowCount = 6;
const double kCalendarPaneSectionGap = 12;
const double kCalendarHeightSafetyBuffer = 4;

bool calendarIsSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String calendarWeekdayLabel(DateTime day) {
  return kCalendarWeekdayLabelsZh[day.weekday % 7];
}

String calendarMonthTitleZh(DateTime month) {
  return '${month.year}年${month.month}月';
}

bool calendarIsSunday(DateTime day) => day.weekday == DateTime.sunday;

bool calendarIsSaturday(DateTime day) => day.weekday == DateTime.saturday;

/// First [kCalendarPreviewCharCount] characters for calendar cell preview.
String calendarEntryPreviewLabel(String text) {
  final String trimmed = text.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  if (trimmed.length <= kCalendarPreviewCharCount) {
    return trimmed;
  }
  return trimmed.substring(0, kCalendarPreviewCharCount);
}

double calendarRowHeightForShellHeight(double shellOuterHeight) {
  final double innerHeight = shellOuterHeight - kCalendarShellPadding;
  if (innerHeight <= kCalendarHeaderHeight + kCalendarDaysOfWeekHeight + 1) {
    return 40;
  }

  final double availableForRows = innerHeight -
      kCalendarHeaderHeight -
      kCalendarDaysOfWeekHeight -
      kCalendarHeightSafetyBuffer;
  return (availableForRows / kCalendarRowCount).clamp(46.0, 72.0);
}

bool calendarShouldShowEntryTitles(double rowHeight) => rowHeight >= 46;

double calendarEntryFontSize(double rowHeight) {
  if (rowHeight >= 60) {
    return 8;
  }
  return 7.5;
}

Color calendarGridLineColor(ColorScheme cs) {
  return cs.outlineVariant.withValues(alpha: 0.22);
}
