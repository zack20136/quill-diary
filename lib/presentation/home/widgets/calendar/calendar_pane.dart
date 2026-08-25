import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../domain/shared/value_objects.dart';
import '../../../../domain/diary/diary_date_policy.dart';
import '../../../../infrastructure/database/index_database.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/presentation/date_picker/app_date_picker_dialog.dart';
import '../../../../shared/presentation/display_format.dart';
import '../../../../app/app_colors.dart';
import '../../../../shared/presentation/page_style.dart';
import '../../../../shared/presentation/widgets/app_state_card.dart';
import '../../../../shared/presentation/widgets/app_loading_state.dart';
import '../../../../../application/tag/tag_providers.dart';
import '../../../../shared/utils/user_facing_error.dart';
import '../../home_layout.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import '../../../../application/session/state/app_session_state.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import '../home_scroll_affordance.dart';
import '../home_shared_widgets.dart';
import 'calendar_day_cell.dart';
import 'calendar_layout_policy.dart';

class CalendarSectionShell extends StatelessWidget {
  const CalendarSectionShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.sectionCard,
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        border: Border.all(color: colors.outlineMuted),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
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

class CalendarPane extends ConsumerStatefulWidget {
  const CalendarPane({required this.sessionState, super.key});

  final AppSessionState sessionState;

  @override
  ConsumerState<CalendarPane> createState() => _CalendarPaneState();
}

class _CalendarPaneState extends ConsumerState<CalendarPane> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
      entries:
          entriesByDate[DateOnly.fromDateTime(day).value] ??
          const <EntryIndexRecord>[],
      isSelected: isSelected,
      isToday: isToday,
      isOutside: isOutside,
      rowHeight: rowHeight,
      tagAccents: tagAccents,
    );
  }

  Future<void> _chooseVisibleMonth({
    required DateTime visibleMonth,
    required DateOnly selectedDate,
    required DateTime firstMonth,
    required DateTime lastMonth,
  }) async {
    final DateTime? picked = await showAppYearMonthPickerDialog(
      context: context,
      initialMonth: visibleMonth,
      firstMonth: firstMonth,
      lastMonth: lastMonth,
    );
    if (picked == null || !mounted) {
      return;
    }

    ref
        .read(calendarVisibleMonthProvider.notifier)
        .set(DateTime(picked.year, picked.month));
    ref
        .read(calendarSelectedDateProvider.notifier)
        .set(calendarSelectedDateForMonth(selectedDate, picked));
  }

  @override
  Widget build(BuildContext context) {
    final bool canReadEntries =
        widget.sessionState.isUnlocked && widget.sessionState.session != null;
    final AsyncValue<List<EntryIndexRecord>> monthEntriesAsync = ref.watch(
      calendarGridEntriesProvider,
    );
    final AsyncValue<List<EntryIndexRecord>> entriesAsync = ref.watch(
      calendarEntriesProvider,
    );
    final DateTime visibleMonth = ref.watch(calendarVisibleMonthProvider);
    final DateOnly? selectedDateRaw = ref.watch(calendarSelectedDateProvider);
    final DateOnly selectedDate =
        selectedDateRaw ?? DateOnly.fromDateTime(DateTime.now());
    final ColorScheme cs = Theme.of(context).colorScheme;
    final ThemeData theme = Theme.of(context);
    final Map<String, int> tagAccents = ref
        .watch(tagAccentArgbMapProvider)
        .maybeWhen(
          data: (Map<String, int> m) => m,
          orElse: () => const <String, int>{},
        );
    final DateTime today = DateTime.now();
    final ({DateOnly earliest, DateOnly latest})? storedBounds = ref
        .watch(entryDateBoundsProvider)
        .value;
    final ({DateTime first, DateTime last}) policyRange =
        DiaryDatePolicy.selectableRange();
    DateTime firstCalendarDay = policyRange.first;
    DateTime lastCalendarDay = policyRange.last;
    final Iterable<DateTime> datesToInclude = <DateTime>[
      visibleMonth,
      selectedDate.toDateTime(),
      if (storedBounds != null) storedBounds.earliest.toDateTime(),
      if (storedBounds != null) storedBounds.latest.toDateTime(),
    ];
    for (final DateTime date in datesToInclude) {
      if (date.isBefore(firstCalendarDay)) {
        firstCalendarDay = date;
      }
      if (date.isAfter(lastCalendarDay)) {
        lastCalendarDay = date;
      }
    }

    if (!canReadEntries) {
      return HomeBlockedEntriesPane(sessionState: widget.sessionState);
    }

    if (monthEntriesAsync.hasError && !monthEntriesAsync.hasValue) {
      return HomeScrollbarGutter(
        child: AppStateCard(
          icon: Icons.error_outline,
          title: context.l10n.commonReadFailureTitle,
          message: userFacingErrorMessage(
            monthEntriesAsync.error!,
            l10n: context.l10n,
          ),
        ),
      );
    }
    // 月份格線載入時保留外層框架，避免高度跳動。
    final bool monthGridLoading = monthEntriesAsync.isLoading;
    final List<EntryIndexRecord> monthEntries = monthGridLoading
        ? const <EntryIndexRecord>[]
        : (monthEntriesAsync.value ?? const <EntryIndexRecord>[]);
    final Map<String, List<EntryIndexRecord>> entriesByDate =
        <String, List<EntryIndexRecord>>{};
    for (final EntryIndexRecord entry in monthEntries) {
      entriesByDate
          .putIfAbsent(entry.date.value, () => <EntryIndexRecord>[])
          .add(entry);
    }

    return HomeScrollAffordance(
      controller: _scrollController,
      child: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: (OverscrollIndicatorNotification notification) {
          notification.disallowIndicator();
          return false;
        },
        child: CustomScrollView(
          controller: _scrollController,
          scrollCacheExtent: HomeLayout.entryListCacheExtent,
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints _) {
                  final double textScale = MediaQuery.textScalerOf(
                    context,
                  ).scale(1);
                  final double viewportHeight =
                      MediaQuery.sizeOf(context).height * 0.52;
                  final double rowHeight = calendarRowHeightForAvailableHeight(
                    viewportHeight - kCalendarShellVerticalInset,
                    textScale: textScale,
                  );
                  final double calendarHeight = calendarContentHeight(
                    rowHeight,
                  );

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
                                firstDay: firstCalendarDay,
                                lastDay: lastCalendarDay,
                                focusedDay: visibleMonth,
                                calendarFormat: CalendarFormat.month,
                                availableCalendarFormats:
                                    <CalendarFormat, String>{
                                      CalendarFormat.month: context
                                          .l10n
                                          .homeCalendarMonthFormatLabel,
                                    },
                                startingDayOfWeek: StartingDayOfWeek.sunday,
                                sixWeekMonthsEnforced: true,
                                headerStyle: HeaderStyle(
                                  titleCentered: true,
                                  formatButtonVisible: false,
                                  headerPadding: const EdgeInsets.only(
                                    bottom: 6,
                                  ),
                                  leftChevronPadding: const EdgeInsets.all(6),
                                  rightChevronPadding: const EdgeInsets.all(6),
                                  leftChevronMargin: const EdgeInsets.only(
                                    left: 0,
                                  ),
                                  rightChevronMargin: const EdgeInsets.only(
                                    right: 0,
                                  ),
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
                                  titleTextStyle:
                                      theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ) ??
                                      const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                  titleTextFormatter: (DateTime date, _) =>
                                      calendarMonthTitle(context.l10n, date),
                                ),
                                daysOfWeekHeight: kCalendarDaysOfWeekHeight,
                                rowHeight: rowHeight,
                                calendarStyle: CalendarStyle(
                                  outsideDaysVisible: true,
                                  cellMargin: EdgeInsets.zero,
                                  tablePadding: EdgeInsets.zero,
                                  tableBorder: TableBorder(
                                    top: BorderSide(
                                      color: context.appColors.calendarGridLine,
                                      width: 0.5,
                                    ),
                                    bottom: BorderSide(
                                      color: context.appColors.calendarGridLine,
                                      width: 0.5,
                                    ),
                                    left: BorderSide(
                                      color: context.appColors.calendarGridLine,
                                      width: 0.5,
                                    ),
                                    right: BorderSide(
                                      color: context.appColors.calendarGridLine,
                                      width: 0.5,
                                    ),
                                    horizontalInside: BorderSide(
                                      color: context.appColors.calendarGridLine,
                                      width: 0.5,
                                    ),
                                    verticalInside: BorderSide(
                                      color: context.appColors.calendarGridLine,
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
                                  weekdayStyle:
                                      theme.textTheme.labelSmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ) ??
                                      TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                  weekendStyle:
                                      theme.textTheme.labelSmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ) ??
                                      TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                selectedDayPredicate: (DateTime day) =>
                                    selectedDate.value ==
                                    DateOnly.fromDateTime(day).value,
                                onPageChanged: (DateTime focusedDay) {
                                  final DateOnly nextSelectedDate =
                                      calendarSelectedDateForMonth(
                                        selectedDate,
                                        focusedDay,
                                      );
                                  ref
                                      .read(
                                        calendarVisibleMonthProvider.notifier,
                                      )
                                      .set(
                                        DateTime(
                                          focusedDay.year,
                                          focusedDay.month,
                                        ),
                                      );
                                  ref
                                      .read(
                                        calendarSelectedDateProvider.notifier,
                                      )
                                      .set(nextSelectedDate);
                                },
                                onDaySelected:
                                    (
                                      DateTime selectedDay,
                                      DateTime focusedDay,
                                    ) {
                                      ref
                                          .read(
                                            calendarVisibleMonthProvider
                                                .notifier,
                                          )
                                          .set(
                                            DateTime(
                                              focusedDay.year,
                                              focusedDay.month,
                                            ),
                                          );
                                      ref
                                          .read(
                                            calendarSelectedDateProvider
                                                .notifier,
                                          )
                                          .set(
                                            DateOnly.fromDateTime(selectedDay),
                                          );
                                    },
                                eventLoader: (_) => const <Object>[],
                                calendarBuilders: CalendarBuilders<Object>(
                                  headerTitleBuilder:
                                      (BuildContext context, DateTime month) {
                                        return Tooltip(
                                          message: context
                                              .l10n
                                              .datePickerChooseYearMonth,
                                          child: Material(
                                            type: MaterialType.transparency,
                                            child: InkWell(
                                              key: const Key(
                                                'calendar-month-title-button',
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap: () => _chooseVisibleMonth(
                                                visibleMonth: month,
                                                selectedDate: selectedDate,
                                                firstMonth: DateTime(
                                                  firstCalendarDay.year,
                                                  firstCalendarDay.month,
                                                ),
                                                lastMonth: DateTime(
                                                  lastCalendarDay.year,
                                                  lastCalendarDay.month,
                                                ),
                                              ),
                                              child: SizedBox(
                                                height: 44,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: <Widget>[
                                                    Text(
                                                      calendarMonthTitle(
                                                        context.l10n,
                                                        month,
                                                      ),
                                                      style:
                                                          theme
                                                              .textTheme
                                                              .titleMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ) ??
                                                          const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Icon(
                                                      Icons.arrow_drop_down,
                                                      size: 20,
                                                      color:
                                                          cs.onSurfaceVariant,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                  dowBuilder:
                                      (BuildContext context, DateTime day) {
                                        final bool isSun = calendarIsSunday(
                                          day,
                                        );
                                        final bool isSat = calendarIsSaturday(
                                          day,
                                        );
                                        return DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: cs.surfaceContainerHigh
                                                .withValues(alpha: 0.45),
                                            border: Border(
                                              bottom: BorderSide(
                                                color: context
                                                    .appColors
                                                    .calendarGridLine,
                                                width: 0.5,
                                              ),
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              calendarWeekdayLabel(
                                                context.l10n,
                                                day,
                                              ),
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    fontSize: 10.5,
                                                    color: isSun
                                                        ? cs.error.withValues(
                                                            alpha: 0.78,
                                                          )
                                                        : isSat
                                                        ? cs.primary.withValues(
                                                            alpha: 0.72,
                                                          )
                                                        : cs.onSurfaceVariant,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                        );
                                      },
                                  defaultBuilder:
                                      (
                                        BuildContext context,
                                        DateTime day,
                                        DateTime focusedDay,
                                      ) {
                                        return _buildDayCell(
                                          day: day,
                                          focusedDay: focusedDay,
                                          entriesByDate: entriesByDate,
                                          selectedDate: selectedDate,
                                          isSelected: false,
                                          isToday: calendarIsSameDay(
                                            day,
                                            today,
                                          ),
                                          isOutside:
                                              day.month != focusedDay.month,
                                          rowHeight: rowHeight,
                                          tagAccents: tagAccents,
                                        );
                                      },
                                  selectedBuilder:
                                      (
                                        BuildContext context,
                                        DateTime day,
                                        DateTime focusedDay,
                                      ) {
                                        return _buildDayCell(
                                          day: day,
                                          focusedDay: focusedDay,
                                          entriesByDate: entriesByDate,
                                          selectedDate: selectedDate,
                                          isSelected: true,
                                          isToday: calendarIsSameDay(
                                            day,
                                            today,
                                          ),
                                          isOutside:
                                              day.month != focusedDay.month,
                                          rowHeight: rowHeight,
                                          tagAccents: tagAccents,
                                        );
                                      },
                                  todayBuilder:
                                      (
                                        BuildContext context,
                                        DateTime day,
                                        DateTime focusedDay,
                                      ) {
                                        return _buildDayCell(
                                          day: day,
                                          focusedDay: focusedDay,
                                          entriesByDate: entriesByDate,
                                          selectedDate: selectedDate,
                                          isSelected:
                                              selectedDate.value ==
                                              DateOnly.fromDateTime(day).value,
                                          isToday: true,
                                          isOutside:
                                              day.month != focusedDay.month,
                                          rowHeight: rowHeight,
                                          tagAccents: tagAccents,
                                        );
                                      },
                                  outsideBuilder:
                                      (
                                        BuildContext context,
                                        DateTime day,
                                        DateTime focusedDay,
                                      ) {
                                        return _buildDayCell(
                                          day: day,
                                          focusedDay: focusedDay,
                                          entriesByDate: entriesByDate,
                                          selectedDate: selectedDate,
                                          isSelected:
                                              selectedDate.value ==
                                              DateOnly.fromDateTime(day).value,
                                          isToday: calendarIsSameDay(
                                            day,
                                            today,
                                          ),
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
            const SliverToBoxAdapter(
              child: SizedBox(height: HomeLayout.sectionGap),
            ),
            entriesAsync.when<Widget>(
              skipLoadingOnReload: true,
              data: (List<EntryIndexRecord> entries) {
                final String dateLabel = DisplayFormat.formatDateOnly(
                  context.l10n,
                  selectedDate,
                );
                final String title = context.l10n.homeDiarySectionTitleForDate(
                  dateLabel,
                );
                if (entries.isNotEmpty) {
                  return HomeDiarySliverSection(
                    title: title,
                    stripeColor: cs.primary,
                    entries: entries,
                  );
                }
                return SliverToBoxAdapter(
                  child: HomeSectionCard(
                    title: title,
                    stripeColor: cs.primary,
                    child: HomePaneEmptyHint(
                      text: context.l10n.homeEmptyDayMessage(dateLabel),
                    ),
                  ),
                );
              },
              loading: () {
                final String dateLabel = DisplayFormat.formatDateOnly(
                  context.l10n,
                  selectedDate,
                );
                return SliverToBoxAdapter(
                  child: HomeSectionCard(
                    title: context.l10n.homeDiarySectionTitleForDate(dateLabel),
                    stripeColor: cs.primary,
                    child: const AppLoadingState(),
                  ),
                );
              },
              error: (Object error, StackTrace _) {
                final String dateLabel = DisplayFormat.formatDateOnly(
                  context.l10n,
                  selectedDate,
                );
                return SliverToBoxAdapter(
                  child: HomeSectionCard(
                    title: context.l10n.homeDiarySectionTitleForDate(dateLabel),
                    stripeColor: cs.primary,
                    child: Text(
                      userFacingErrorMessage(error, l10n: context.l10n),
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
