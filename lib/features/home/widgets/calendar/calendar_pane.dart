import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../domain/shared/value_objects.dart';
import '../../../../infrastructure/database/index_database.dart';
import '../../../../shared/copy/common_copy.dart';
import '../../../../shared/presentation/display_format.dart';
import '../../../../shared/presentation/page_style.dart';
import '../../../../shared/providers/tag_providers.dart';
import '../../../../shared/utils/user_facing_error.dart';
import '../../home_copy.dart';
import '../../home_layout.dart';
import '../../providers/home_providers.dart';
import '../../../session/state/app_session_state.dart';
import '../../state/home_state.dart';
import '../entry_widgets.dart';
import '../home_shared_widgets.dart';
import 'calendar_day_cell.dart';
import 'calendar_helpers.dart';

class CalendarSectionShell extends StatelessWidget {
  const CalendarSectionShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        border: Border.all(color: PageStyle.primaryMutedOutline(cs)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          kCalendarShellPaddingHorizontal,
          kCalendarShellPaddingTop,
          kCalendarShellPaddingHorizontal,
          kCalendarShellPaddingBottom,
        ),
        child: child,
      ),
    );
  }
}

class CalendarPane extends ConsumerWidget {
  const CalendarPane({required this.sessionState, super.key});

  final AppSessionState sessionState;

  Widget _buildDayCell({
    required DateTime day,
    required DateTime focusedDay,
    required Map<String, List<EntryIndexRecord>> entriesByDate,
    required DateOnly selectedDate,
    required bool isSelected,
    required bool isToday,
    required bool isOutside,
    required double rowHeight,
    required Map<String, int> tagAccents,
  }) {
    return CalendarDayCell(
      day: day,
      entries: entriesByDate[DateOnly.fromDateTime(day).value] ?? const <EntryIndexRecord>[],
      isSelected: isSelected,
      isToday: isToday,
      isOutside: isOutside,
      rowHeight: rowHeight,
      tagAccents: tagAccents,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canReadEntries = sessionState.isUnlocked && sessionState.session != null;
    final AsyncValue<List<EntryIndexRecord>> monthEntriesAsync =
        ref.watch(calendarMonthEntriesProvider);
    final AsyncValue<List<EntryIndexRecord>> entriesAsync = ref.watch(calendarEntriesProvider);
    final DateTime visibleMonth = ref.watch(calendarVisibleMonthProvider);
    final DateOnly? selectedDateRaw = ref.watch(calendarSelectedDateProvider);
    final DateOnly selectedDate =
        selectedDateRaw ?? DateOnly.fromDateTime(DateTime.now());
    final ColorScheme cs = Theme.of(context).colorScheme;
    final ThemeData theme = Theme.of(context);
    final Map<String, int> tagAccents = ref.watch(tagAccentArgbMapProvider).maybeWhen(
          data: (Map<String, int> m) => m,
          orElse: () => const <String, int>{},
        );
    final DateTime today = DateTime.now();

    if (!canReadEntries) {
      return HomeBlockedEntriesPane(sessionState: sessionState);
    }

    if (monthEntriesAsync.hasError && !monthEntriesAsync.hasValue) {
      return HomeStateCard(
        icon: Icons.error_outline,
        title: CommonCopy.readFailureTitle(context),
        message: userFacingErrorMessage(monthEntriesAsync.error!),
      );
    }

    // 換月重載時保留版面，僅月曆表格區顯示載入狀態，避免整頁閃爍。
    final bool monthGridLoading = monthEntriesAsync.isLoading;
    final List<EntryIndexRecord> monthEntries = monthGridLoading
        ? const <EntryIndexRecord>[]
        : (monthEntriesAsync.value ?? const <EntryIndexRecord>[]);
    final Map<String, List<EntryIndexRecord>> entriesByDate =
        <String, List<EntryIndexRecord>>{};
    for (final EntryIndexRecord entry in monthEntries) {
      entriesByDate.putIfAbsent(entry.date.value, () => <EntryIndexRecord>[]).add(entry);
    }

    return NotificationListener<OverscrollIndicatorNotification>(
      onNotification: (OverscrollIndicatorNotification notification) {
        notification.disallowIndicator();
        return false;
      },
      child: CustomScrollView(
        scrollCacheExtent: HomeLayout.entryListCacheExtent,
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints _) {
                final double textScale = MediaQuery.textScalerOf(context).scale(1);
                final double viewportHeight = MediaQuery.sizeOf(context).height * 0.52;
                final double rowHeight = calendarRowHeightForAvailableHeight(
                  viewportHeight - kCalendarShellVerticalInset,
                  textScale: textScale,
                );
                final double calendarHeight = calendarContentHeight(rowHeight);

                return CalendarSectionShell(
                  child: Stack(
                    children: <Widget>[
                      SizedBox(
                        height: calendarHeight,
                        child: IgnorePointer(
                          ignoring: monthGridLoading,
                          child: Opacity(
                            opacity: monthGridLoading ? 0.45 : 1,
                            child: TableCalendar<Object>(
                          firstDay: DateTime(2020),
                          lastDay: DateTime(2100),
                          focusedDay: visibleMonth,
                          calendarFormat: CalendarFormat.month,
                          availableCalendarFormats: <CalendarFormat, String>{
                            CalendarFormat.month: HomeCopy.calendarMonthFormatLabel(context),
                          },
                          startingDayOfWeek: StartingDayOfWeek.sunday,
                          sixWeekMonthsEnforced: true,
                          headerStyle: HeaderStyle(
                            titleCentered: true,
                            formatButtonVisible: false,
                            headerPadding: const EdgeInsets.only(bottom: 6),
                            leftChevronPadding: const EdgeInsets.all(6),
                            rightChevronPadding: const EdgeInsets.all(6),
                            leftChevronMargin: const EdgeInsets.only(left: 0),
                            rightChevronMargin: const EdgeInsets.only(right: 0),
                            leftChevronIcon: Icon(
                              Icons.chevron_left_rounded,
                              color: cs.onSurfaceVariant,
                              size: 22,
                            ),
                            rightChevronIcon: Icon(
                              Icons.chevron_right_rounded,
                              color: cs.onSurfaceVariant,
                              size: 22,
                            ),
                            titleTextStyle: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ) ??
                                const TextStyle(fontWeight: FontWeight.w800),
                            titleTextFormatter: (DateTime date, _) => calendarMonthTitleZh(date),
                          ),
                          daysOfWeekHeight: kCalendarDaysOfWeekHeight,
                          rowHeight: rowHeight,
                          calendarStyle: CalendarStyle(
                            outsideDaysVisible: true,
                            cellMargin: EdgeInsets.zero,
                            tablePadding: EdgeInsets.zero,
                            tableBorder: TableBorder(
                              top: BorderSide(color: calendarGridLineColor(cs), width: 0.5),
                              bottom: BorderSide(color: calendarGridLineColor(cs), width: 0.5),
                              left: BorderSide(color: calendarGridLineColor(cs), width: 0.5),
                              right: BorderSide(color: calendarGridLineColor(cs), width: 0.5),
                              horizontalInside: BorderSide(
                                color: calendarGridLineColor(cs),
                                width: 0.5,
                              ),
                              verticalInside: BorderSide(
                                color: calendarGridLineColor(cs),
                                width: 0.5,
                              ),
                            ),
                            defaultDecoration: const BoxDecoration(),
                            selectedDecoration: const BoxDecoration(),
                            todayDecoration: const BoxDecoration(),
                            outsideDecoration: const BoxDecoration(),
                            weekendDecoration: const BoxDecoration(),
                            markerDecoration: const BoxDecoration(),
                          ),
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ) ??
                                TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                            weekendStyle: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ) ??
                                TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                          ),
                          selectedDayPredicate: (DateTime day) =>
                              selectedDate.value == DateOnly.fromDateTime(day).value,
                          onPageChanged: (DateTime focusedDay) {
                            ref.read(calendarVisibleMonthProvider.notifier).set(
                                  DateTime(focusedDay.year, focusedDay.month),
                                );
                          },
                          onDaySelected: (DateTime selectedDay, DateTime focusedDay) {
                            ref.read(calendarVisibleMonthProvider.notifier).set(
                                  DateTime(focusedDay.year, focusedDay.month),
                                );
                            ref.read(calendarSelectedDateProvider.notifier).set(
                                  DateOnly.fromDateTime(selectedDay),
                                );
                          },
                          eventLoader: (_) => const <Object>[],
                          calendarBuilders: CalendarBuilders<Object>(
                            dowBuilder: (BuildContext context, DateTime day) {
                              final bool isSun = calendarIsSunday(day);
                              final bool isSat = calendarIsSaturday(day);
                              return DecoratedBox(
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHigh.withValues(alpha: 0.45),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: calendarGridLineColor(cs),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    calendarWeekdayLabel(day),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 10.5,
                                      color: isSun
                                          ? cs.error.withValues(alpha: 0.78)
                                          : isSat
                                              ? cs.primary.withValues(alpha: 0.72)
                                              : cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              );
                            },
                            defaultBuilder: (BuildContext context, DateTime day, DateTime focusedDay) {
                              return _buildDayCell(
                                day: day,
                                focusedDay: focusedDay,
                                entriesByDate: entriesByDate,
                                selectedDate: selectedDate,
                                isSelected: false,
                                isToday: calendarIsSameDay(day, today),
                                isOutside: day.month != focusedDay.month,
                                rowHeight: rowHeight,
                                tagAccents: tagAccents,
                              );
                            },
                            selectedBuilder: (BuildContext context, DateTime day, DateTime focusedDay) {
                              return _buildDayCell(
                                day: day,
                                focusedDay: focusedDay,
                                entriesByDate: entriesByDate,
                                selectedDate: selectedDate,
                                isSelected: true,
                                isToday: calendarIsSameDay(day, today),
                                isOutside: day.month != focusedDay.month,
                                rowHeight: rowHeight,
                                tagAccents: tagAccents,
                              );
                            },
                            todayBuilder: (BuildContext context, DateTime day, DateTime focusedDay) {
                              return _buildDayCell(
                                day: day,
                                focusedDay: focusedDay,
                                entriesByDate: entriesByDate,
                                selectedDate: selectedDate,
                                isSelected: selectedDate.value == DateOnly.fromDateTime(day).value,
                                isToday: true,
                                isOutside: day.month != focusedDay.month,
                                rowHeight: rowHeight,
                                tagAccents: tagAccents,
                              );
                            },
                            outsideBuilder: (BuildContext context, DateTime day, DateTime focusedDay) {
                              return _buildDayCell(
                                day: day,
                                focusedDay: focusedDay,
                                entriesByDate: entriesByDate,
                                selectedDate: selectedDate,
                                isSelected: selectedDate.value == DateOnly.fromDateTime(day).value,
                                isToday: calendarIsSameDay(day, today),
                                isOutside: true,
                                rowHeight: rowHeight,
                                tagAccents: tagAccents,
                              );
                            },
                          ),
                            ),
                          ),
                        ),
                      ),
                      if (monthGridLoading)
                        SizedBox(
                          height: calendarHeight,
                          child: Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: cs.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: HomeLayout.sectionGap)),
          SliverToBoxAdapter(
            child: entriesAsync.when(
              skipLoadingOnReload: true,
              data: (List<EntryIndexRecord> entries) {
                final String dateLabel = DisplayFormat.formatDateOnlyZh(selectedDate);
                return HomeDiaryListSectionCard(
                  title: HomeCopy.diarySectionTitleForDate(context, dateLabel),
                  stripeColor: cs.primary,
                  child: entries.isEmpty
                      ? HomePaneEmptyHint(text: HomeCopy.emptyDayMessage(context, dateLabel))
                      : HomeCompactEntryList(entries: entries),
                );
              },
              loading: () {
                final String dateLabel = DisplayFormat.formatDateOnlyZh(selectedDate);
                return HomeDiaryListSectionCard(
                  title: HomeCopy.diarySectionTitleForDate(context, dateLabel),
                  stripeColor: cs.primary,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              error: (Object error, StackTrace _) {
                final String dateLabel = DisplayFormat.formatDateOnlyZh(selectedDate);
                return HomeDiaryListSectionCard(
                  title: HomeCopy.diarySectionTitleForDate(context, dateLabel),
                  stripeColor: cs.primary,
                  child: Text(userFacingErrorMessage(error)),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
