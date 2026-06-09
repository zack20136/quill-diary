part of '../../pages/home_page.dart';

class _CalendarSectionShell extends StatelessWidget {
  const _CalendarSectionShell({required this.child});

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

class _CalendarPane extends ConsumerWidget {
  const _CalendarPane({
    required this.sessionState,
    super.key,
  });

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
  }) {
    return _CalendarDayCell(
      day: day,
      entries: entriesByDate[DateOnly.fromDateTime(day).value] ?? const <EntryIndexRecord>[],
      isSelected: isSelected,
      isToday: isToday,
      isOutside: isOutside,
      rowHeight: rowHeight,
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

    if (!canReadEntries) {
      return _BlockedEntriesPane(sessionState: sessionState);
    }

    return monthEntriesAsync.when(
      data: (List<EntryIndexRecord> monthEntries) {
        final Map<String, List<EntryIndexRecord>> entriesByDate =
            <String, List<EntryIndexRecord>>{};
        for (final EntryIndexRecord entry in monthEntries) {
          entriesByDate.putIfAbsent(entry.date.value, () => <EntryIndexRecord>[]).add(entry);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Flexible(
              flex: 12,
              fit: FlexFit.tight,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints shellConstraints) {
                  final double textScale = MediaQuery.textScalerOf(context).scale(1);
                  final double viewportHeight =
                      shellConstraints.maxHeight - kCalendarShellVerticalInset;
                  final double rowHeight = calendarRowHeightForAvailableHeight(
                    viewportHeight,
                    textScale: textScale,
                  );
                  final double calendarHeight = calendarContentHeight(rowHeight);

                  return _CalendarSectionShell(
                    child: SizedBox(
                      height: calendarHeight,
                      child: TableCalendar<Object>(
                          firstDay: DateTime(2020),
                          lastDay: DateTime(2100),
                          focusedDay: visibleMonth,
                          calendarFormat: CalendarFormat.month,
                          availableCalendarFormats: const <CalendarFormat, String>{
                            CalendarFormat.month: '月',
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
                                isToday: calendarIsSameDay(day, DateTime.now()),
                                isOutside: day.month != focusedDay.month,
                                rowHeight: rowHeight,
                              );
                            },
                            selectedBuilder: (BuildContext context, DateTime day, DateTime focusedDay) {
                              return _buildDayCell(
                                day: day,
                                focusedDay: focusedDay,
                                entriesByDate: entriesByDate,
                                selectedDate: selectedDate,
                                isSelected: true,
                                isToday: calendarIsSameDay(day, DateTime.now()),
                                isOutside: day.month != focusedDay.month,
                                rowHeight: rowHeight,
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
                              );
                            },
                            outsideBuilder: (BuildContext context, DateTime day, DateTime focusedDay) {
                              return _buildDayCell(
                                day: day,
                                focusedDay: focusedDay,
                                entriesByDate: entriesByDate,
                                selectedDate: selectedDate,
                                isSelected: selectedDate.value == DateOnly.fromDateTime(day).value,
                                isToday: calendarIsSameDay(day, DateTime.now()),
                                isOutside: true,
                                rowHeight: rowHeight,
                              );
                            },
                          ),
                        ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: kCalendarPaneSectionGap),
            Expanded(
              flex: 8,
              child: entriesAsync.when(
                    data: (List<EntryIndexRecord> entries) {
                      final String dateLabel =
                          DisplayFormat.formatDateOnlyZh(selectedDate);
                      return _DiaryListSectionCard(
                        title: HomeCopy.diarySectionTitleForDate(dateLabel),
                        stripeColor: cs.primary,
                        expandBody: true,
                        child: entries.isEmpty
                            ? _PaneEmptyHint(
                                text: HomeCopy.emptyDayMessage(dateLabel),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _CompactEntryList(entries: entries),
                              ),
                      );
                    },
                    loading: () {
                      final String dateLabel =
                          DisplayFormat.formatDateOnlyZh(selectedDate);
                      return _DiaryListSectionCard(
                        title: HomeCopy.diarySectionTitleForDate(dateLabel),
                        stripeColor: cs.primary,
                        expandBody: true,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    error: (Object error, StackTrace _) {
                      final String dateLabel =
                          DisplayFormat.formatDateOnlyZh(selectedDate);
                      return _DiaryListSectionCard(
                        title: HomeCopy.diarySectionTitleForDate(dateLabel),
                        stripeColor: cs.primary,
                        expandBody: true,
                        child: Text(userFacingErrorMessage(error)),
                      );
                    },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace _) => _StateCard(
        icon: Icons.error_outline,
        title: CommonCopy.readFailureTitle,
        message: userFacingErrorMessage(error),
      ),
    );
  }
}
