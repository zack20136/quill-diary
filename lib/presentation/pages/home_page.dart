import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../domain/shared/value_objects.dart';
import '../../infrastructure/database/index_database.dart';
import '../widgets/entry_cover_thumbnail.dart';
import '../state/app_session_state.dart';

const double _kPaneSectionGap = 18;

abstract final class _HomePalette {
  static Color metricSurface(ColorScheme cs, int index) {
    return switch (index % 4) {
      0 => Color.alphaBlend(cs.primary.withValues(alpha: 0.12), cs.primaryContainer),
      1 => Color.alphaBlend(cs.tertiary.withValues(alpha: 0.1), cs.tertiaryContainer),
      2 => Color.alphaBlend(cs.secondary.withValues(alpha: 0.08), cs.secondaryContainer),
      _ => cs.surfaceContainerHigh,
    };
  }

  static Color metricOnSurface(ColorScheme cs, int index) {
    return switch (index % 4) {
      0 => cs.onPrimaryContainer,
      1 => cs.onTertiaryContainer,
      2 => cs.onSecondaryContainer,
      _ => cs.onSurface,
    };
  }
}

Widget _blockedEntriesPane(AppSessionState sessionState) {
  return _StateCard(
    icon: _blockedIcon(sessionState.status),
    title: _blockedTitle(sessionState.status),
    message: _blockedMessage(sessionState),
  );
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isSupportedPlatform = ref.watch(supportedPlatformProvider);
    final AsyncValue<AppSessionState> sessionAsync = ref.watch(effectiveAppSessionProvider);

    if (!isSupportedPlatform) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text(kAndroidOnlyMessage)),
      );
    }

    return sessionAsync.when(
      data: (AppSessionState sessionState) {
        final bool canCreate = sessionState.isUnlocked && sessionState.session != null;
        final ColorScheme cs = Theme.of(context).colorScheme;
        return Scaffold(
          backgroundColor: Color.alphaBlend(cs.primary.withValues(alpha: 0.04), cs.surface),
          appBar: const PreferredSize(
            preferredSize: Size.fromHeight(82),
            child: _HomeHeader(),
          ),
          body: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _HomeContent(sessionState: sessionState),
            ),
          ),
          floatingActionButton: FloatingActionButton.small(
            tooltip: '新增日記',
            backgroundColor: cs.secondaryContainer,
            foregroundColor: cs.onSecondaryContainer,
            onPressed: canCreate ? () => context.push(AppRouter.editorRoute) : null,
            child: const Icon(Icons.add_rounded),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$error')),
      ),
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final HomeTab activeTab = ref.watch(homeTabProvider);

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 82,
      titleSpacing: 0,
      title: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Color.alphaBlend(theme.colorScheme.primary.withValues(alpha: 0.06),
                            theme.colorScheme.surfaceContainerLow),
                        theme.colorScheme.surfaceContainerLow,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Color.alphaBlend(
                        theme.colorScheme.primary.withValues(alpha: 0.18),
                        theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: <Widget>[
                        _HeaderTabButton(
                          label: '首頁',
                          active: activeTab == HomeTab.home,
                          onTap: () => ref.read(homeTabProvider.notifier).set(HomeTab.home),
                        ),
                        _HeaderTabButton(
                          label: '日曆',
                          active: activeTab == HomeTab.calendar,
                          onTap: () => ref.read(homeTabProvider.notifier).set(HomeTab.calendar),
                        ),
                        _HeaderTabButton(
                          label: '總覽',
                          active: activeTab == HomeTab.overview,
                          onTap: () => ref.read(homeTabProvider.notifier).set(HomeTab.overview),
                        ),
                        _HeaderTabButton(
                          label: '回憶',
                          active: activeTab == HomeTab.memories,
                          onTap: () => ref.read(homeTabProvider.notifier).set(HomeTab.memories),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _HeaderIconButton(
                tooltip: '設定與備份',
                icon: Icons.tune_rounded,
                onPressed: () => context.push(AppRouter.settingsRoute),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.sessionState});

  final AppSessionState sessionState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HomeTab activeTab = ref.watch(homeTabProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: switch (activeTab) {
        HomeTab.home => _HomeTimelinePane(sessionState: sessionState, key: const ValueKey<String>('home')),
        HomeTab.calendar => _CalendarPane(sessionState: sessionState, key: const ValueKey<String>('calendar')),
        HomeTab.overview => _OverviewPane(sessionState: sessionState, key: const ValueKey<String>('overview')),
        HomeTab.memories => _MemoriesPane(sessionState: sessionState, key: const ValueKey<String>('memories')),
      },
    );
  }
}

class _HomeTimelinePane extends ConsumerWidget {
  const _HomeTimelinePane({
    required this.sessionState,
    super.key,
  });

  final AppSessionState sessionState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canReadEntries = sessionState.isUnlocked && sessionState.session != null;
    final AsyncValue<List<EntryIndexRecord>> entriesAsync = ref.watch(homeEntriesProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          enabled: canReadEntries,
          decoration: InputDecoration(
            hintText: '搜尋標題、內文或標籤',
            prefixIcon: Icon(Icons.search_rounded, color: cs.primary.withValues(alpha: 0.85)),
            filled: true,
            fillColor: Color.alphaBlend(cs.tertiary.withValues(alpha: 0.05), cs.surfaceContainerLowest),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide(
                color: Color.alphaBlend(cs.primary.withValues(alpha: 0.12), cs.outlineVariant),
              ),
            ),
          ),
          onChanged: (String value) {
            ref.read(homeSearchQueryProvider.notifier).update(value);
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: canReadEntries
              ? entriesAsync.when(
                  data: (List<EntryIndexRecord> entries) {
                    if (entries.isEmpty) {
                      return const _StateCard(
                        icon: Icons.auto_stories_outlined,
                        title: '目前沒有日記',
                        message: '建立第一篇日記後，就會在這裡看到你的首頁列表。',
                      );
                    }
                    return _EntryList(entries: entries);
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (Object error, StackTrace _) => _StateCard(
                    icon: Icons.error_outline,
                    title: '讀取失敗',
                    message: '$error',
                  ),
                )
              : _blockedEntriesPane(sessionState),
        ),
      ],
    );
  }
}

class _CalendarPane extends ConsumerWidget {
  const _CalendarPane({
    required this.sessionState,
    super.key,
  });

  final AppSessionState sessionState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canReadEntries = sessionState.isUnlocked && sessionState.session != null;
    final AsyncValue<List<DateOnly>> datesAsync = ref.watch(calendarMonthEntryDatesProvider);
    final AsyncValue<List<EntryIndexRecord>> entriesAsync = ref.watch(calendarEntriesProvider);
    final DateTime visibleMonth = ref.watch(calendarVisibleMonthProvider);
    final DateOnly? selectedDate = ref.watch(calendarSelectedDateProvider);

    if (!canReadEntries) {
      return _blockedEntriesPane(sessionState);
    }

    return datesAsync.when(
      data: (List<DateOnly> dates) {
        final Set<String> eventDates = dates.map((DateOnly item) => item.value).toSet();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SectionShell(
              child: TableCalendar<Object>(
                firstDay: DateTime(2020),
                lastDay: DateTime(2100),
                focusedDay: visibleMonth,
                selectedDayPredicate: (DateTime day) =>
                    selectedDate?.value == DateOnly.fromDateTime(day).value,
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
                eventLoader: (DateTime day) {
                  return eventDates.contains(DateOnly.fromDateTime(day).value)
                      ? const <Object>[true]
                      : const <Object>[];
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: selectedDate == null
                  ? const _StateCard(
                      icon: Icons.calendar_month_outlined,
                      title: '選擇日期',
                      message: '點一下日曆上的日期，就能查看當天的日記。',
                    )
                  : _SectionShell(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              _FilterChip(label: selectedDate.value),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => ref
                                    .read(calendarSelectedDateProvider.notifier)
                                    .set(null),
                                child: const Text('清除日期'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: entriesAsync.when(
                              data: (List<EntryIndexRecord> entries) {
                                if (entries.isEmpty) {
                                  return _StateCard(
                                    icon: Icons.event_note_outlined,
                                    title: selectedDate.value,
                                    message: '這一天目前沒有日記。',
                                  );
                                }
                                return _EntryList(entries: entries);
                              },
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (Object error, StackTrace _) => _StateCard(
                                icon: Icons.error_outline,
                                title: '讀取失敗',
                                message: '$error',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace _) => _StateCard(
        icon: Icons.error_outline,
        title: '讀取失敗',
        message: '$error',
      ),
    );
  }
}

class _OverviewPane extends ConsumerWidget {
  const _OverviewPane({
    required this.sessionState,
    super.key,
  });

  final AppSessionState sessionState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canReadEntries = sessionState.isUnlocked && sessionState.session != null;
    final AsyncValue<OverviewSummary> summaryAsync = ref.watch(overviewSummaryProvider);
    final AsyncValue<List<EntryIndexRecord>> taggedEntriesAsync =
        ref.watch(overviewTaggedEntriesProvider);
    final String? selectedTag = ref.watch(overviewTagFilterProvider);

    if (!canReadEntries) {
      return _blockedEntriesPane(sessionState);
    }

    return summaryAsync.when(
      data: (OverviewSummary summary) {
        if (summary.totalEntries == 0) {
          return const _StateCard(
            icon: Icons.insights_outlined,
            title: '尚無可分析內容',
            message: '建立幾篇日記後，這裡會顯示標籤、心情與內容統計。',
          );
        }

        final ColorScheme cs = Theme.of(context).colorScheme;

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            _OverviewMetricPanel(
              child: _MetricGrid(
                items: <Widget>[
                  _MetricCard(label: '篇數', value: '${summary.totalEntries}', toneIndex: 0),
                  _MetricCard(label: '活躍天數', value: '${summary.activeDays}', toneIndex: 1),
                  _MetricCard(label: '總字數', value: '${summary.totalWords}', toneIndex: 2),
                  _MetricCard(label: '附件', value: '${summary.totalAttachments}', toneIndex: 3),
                ],
              ),
            ),
            const SizedBox(height: _kPaneSectionGap),
            _SectionCard(
              title: '熱門標籤',
              stripeColor: cs.tertiary,
              child: summary.topTags.isEmpty
                  ? _PaneEmptyHint(text: '目前沒有標籤資料。')
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: summary.topTags
                          .map(
                            (OverviewTagStat item) => FilterChip(
                              label: Text('${item.label} ${item.count}'),
                              selected: selectedTag == item.label,
                              showCheckmark: false,
                              selectedColor: cs.primaryContainer,
                              checkmarkColor: cs.onPrimaryContainer,
                              onSelected: (_) {
                                final notifier = ref.read(overviewTagFilterProvider.notifier);
                                notifier.set(selectedTag == item.label ? null : item.label);
                              },
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: _kPaneSectionGap),
            _SectionCard(
              title: '心情分布',
              stripeColor: cs.secondary,
              child: summary.moods.isEmpty
                  ? _PaneEmptyHint(text: '目前沒有心情資料。')
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: summary.moods
                          .map(
                            (OverviewMoodStat item) =>
                                _MetaChip(label: '${item.label} ${item.count}'),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: _kPaneSectionGap),
            _SectionCard(
              title: '內容密度',
              stripeColor: cs.primary,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _MetaChip(label: '${summary.totalCharacters} 字元'),
                  _MetaChip(
                    label: summary.totalEntries == 0
                        ? '平均 0 字'
                        : '平均 ${(summary.totalWords / summary.totalEntries).round()} 字',
                  ),
                ],
              ),
            ),
            const SizedBox(height: _kPaneSectionGap),
            _SectionCard(
              listSection: true,
              title: selectedTag == null ? '最近更新' : '標籤：$selectedTag',
              stripeColor: cs.primary,
              child: selectedTag == null
                  ? _CompactEntryList(entries: summary.recentEntries)
                  : taggedEntriesAsync.when(
                      data: (List<EntryIndexRecord> entries) {
                        if (entries.isEmpty) {
                          return _PaneEmptyHint(text: '這個標籤目前沒有對應的日記。');
                        }
                        return _CompactEntryList(entries: entries.take(8).toList());
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (Object error, StackTrace _) => Text('$error'),
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace _) => _StateCard(
        icon: Icons.error_outline,
        title: '讀取失敗',
        message: '$error',
      ),
    );
  }
}

class _MemoryFocusedPeriodBar extends ConsumerWidget {
  const _MemoryFocusedPeriodBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MemoryScope scope = ref.watch(memoryScopeProvider);
    final DateTime focusedMonth = ref.watch(memoryFocusedMonthProvider);
    final int focusedYear = ref.watch(memoryFocusedYearProvider);

    return ref.watch(memoryAvailableYearsProvider).when(
          data: (List<int> years) {
            final int? minYear = years.isEmpty ? null : years.first;
            final int? maxYear = years.isEmpty ? null : years.last;
            final ThemeData theme = Theme.of(context);
            final ColorScheme cs = theme.colorScheme;
            return Material(
              color: Color.alphaBlend(cs.secondary.withValues(alpha: 0.06), cs.surfaceContainerLow),
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Color.alphaBlend(cs.primary.withValues(alpha: 0.14), cs.outlineVariant),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: scope == MemoryScope.month
                            ? () => ref.read(memoryFocusedMonthProvider.notifier).set(
                                  DateTime(focusedMonth.year, focusedMonth.month - 1),
                                )
                            : (minYear != null && focusedYear > minYear)
                                ? () => ref
                                    .read(memoryFocusedYearProvider.notifier)
                                    .set(focusedYear - 1)
                                : null,
                        icon: Icon(Icons.chevron_left_rounded, color: cs.primary),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            scope == MemoryScope.month
                                ? '${focusedMonth.year} 年 ${focusedMonth.month.toString().padLeft(2, '0')} 月'
                                : '$focusedYear 年',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: scope == MemoryScope.month
                            ? () => ref.read(memoryFocusedMonthProvider.notifier).set(
                                  DateTime(focusedMonth.year, focusedMonth.month + 1),
                                )
                            : (maxYear != null && focusedYear < maxYear)
                                    ? () => ref
                                        .read(memoryFocusedYearProvider.notifier)
                                        .set(focusedYear + 1)
                                    : null,
                        icon: Icon(Icons.chevron_right_rounded, color: cs.primary),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object error, StackTrace _) => Text('$error'),
        );
  }
}

class _MemoriesPane extends ConsumerWidget {
  const _MemoriesPane({
    required this.sessionState,
    super.key,
  });

  final AppSessionState sessionState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canReadEntries = sessionState.isUnlocked && sessionState.session != null;
    final MemoryScope scope = ref.watch(memoryScopeProvider);
    final AsyncValue<MemorySummary> summaryAsync = ref.watch(memorySummaryProvider);
    final AsyncValue<List<EntryIndexRecord>> entriesAsync = ref.watch(memoryEntriesProvider);
    final ColorScheme cs = Theme.of(context).colorScheme;

    if (!canReadEntries) {
      return _blockedEntriesPane(sessionState);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        _SectionCard(
          title: '回憶範圍',
          stripeColor: cs.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SegmentedButton<MemoryScope>(
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  side: const WidgetStatePropertyAll<BorderSide>(BorderSide.none),
                  shape: WidgetStatePropertyAll<OutlinedBorder>(
                    RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return cs.primaryContainer;
                    }
                    return cs.surfaceContainerHighest.withValues(alpha: 0.55);
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return cs.onPrimaryContainer;
                    }
                    return cs.onSurfaceVariant;
                  }),
                ),
                segments: const <ButtonSegment<MemoryScope>>[
                  ButtonSegment<MemoryScope>(
                    value: MemoryScope.month,
                    label: Text('月回顧'),
                  ),
                  ButtonSegment<MemoryScope>(
                    value: MemoryScope.year,
                    label: Text('年回顧'),
                  ),
                ],
                selected: <MemoryScope>{scope},
                onSelectionChanged: (Set<MemoryScope> next) {
                  if (next.isEmpty) {
                    return;
                  }
                  ref.read(memoryScopeProvider.notifier).set(next.first);
                },
              ),
              const SizedBox(height: 14),
              const _MemoryFocusedPeriodBar(),
            ],
          ),
        ),
        const SizedBox(height: _kPaneSectionGap),
        summaryAsync.when(
          data: (MemorySummary summary) {
            return Column(
              children: <Widget>[
                _OverviewMetricPanel(
                  child: _MetricGrid(
                    items: <Widget>[
                      _MetricCard(label: '篇數', value: '${summary.totalEntries}', toneIndex: 0),
                      _MetricCard(label: '字數', value: '${summary.totalWords}', toneIndex: 1),
                      _MetricCard(label: '附件', value: '${summary.totalAttachments}', toneIndex: 2),
                      _MetricCard(label: '重點日期', value: '${summary.highlightDates.length}', toneIndex: 3),
                    ],
                  ),
                ),
                const SizedBox(height: _kPaneSectionGap),
                _SectionCard(
                  title: summary.title,
                  stripeColor: cs.secondary,
                  child: summary.topTags.isEmpty
                      ? _PaneEmptyHint(text: '這個回顧範圍目前沒有標籤資料。')
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: summary.topTags
                              .map(
                                (OverviewTagStat item) =>
                                    _MetaChip(label: '${item.label} ${item.count}'),
                              )
                              .toList(),
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace _) => _StateCard(
            icon: Icons.error_outline,
            title: '讀取失敗',
            message: '$error',
          ),
        ),
        const SizedBox(height: _kPaneSectionGap),
        entriesAsync.when(
          data: (List<EntryIndexRecord> entries) => _SectionCard(
            listSection: true,
            title: '回顧日記',
            stripeColor: cs.tertiary,
            child: entries.isEmpty
                ? _PaneEmptyHint(text: '這個回顧範圍目前沒有日記。')
                : _CompactEntryList(entries: entries.take(12).toList()),
          ),
          loading: () => _SectionCard(
            listSection: true,
            title: '回顧日記',
            stripeColor: cs.tertiary,
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (Object error, StackTrace _) => _SectionCard(
            listSection: true,
            title: '回顧日記',
            stripeColor: cs.tertiary,
            child: Text('$error'),
          ),
        ),
      ],
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries});

  final List<EntryIndexRecord> entries;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 20),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (BuildContext context, int index) {
        return _TimelineEntryShell(
          child: _EntryCard(entry: entries[index]),
        );
      },
    );
  }
}

/// One elevated card per diary row (replaces the old single outer bordered box).
class _TimelineEntryShell extends StatelessWidget {
  const _TimelineEntryShell({
    required this.child,
    this.tintedCard = false,
  });

  final Widget child;
  final bool tintedCard;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color =
        tintedCard ? theme.colorScheme.surfaceContainerLow : theme.colorScheme.surface;
    return Material(
      color: color,
      elevation: tintedCard ? 0 : 1,
      surfaceTintColor: Colors.transparent,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: tintedCard ? 0 : 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tintedCard ? 18 : 22),
        side: tintedCard
            ? BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45))
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _CompactEntryList extends StatelessWidget {
  const _CompactEntryList({required this.entries});

  final List<EntryIndexRecord> entries;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: entries
          .map(
            (EntryIndexRecord entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TimelineEntryShell(
                tintedCard: true,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => context.push('/editor/${entry.id}'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: _EntryTitleAndTagsRow(
                                  titleText: _entryListHeadline(entry),
                                  tags: entry.tags,
                                  titleStyle: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  compactTags: true,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _EntryCardRightDateTime(entry: entry, compact: true),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: theme.colorScheme.primary.withValues(alpha: 0.55),
                                size: 22,
                              ),
                            ],
                          ),
                          if (entry.previewText.trim().isNotEmpty &&
                              (entry.title ?? '').trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: 6),
                            Text(
                              entry.previewText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                          if (entry.previewImagePaths.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 8),
                            _EntryPreviewImageStrip(
                              paths: entry.previewImagePaths,
                              thumbSize: 52,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _EntryTitleAndTagsRow extends StatelessWidget {
  const _EntryTitleAndTagsRow({
    required this.titleText,
    required this.tags,
    required this.titleStyle,
    this.compactTags = false,
  });

  final String titleText;
  final List<String> tags;
  final TextStyle? titleStyle;
  final bool compactTags;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? tagStyle =
        (compactTags ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Flexible(
          child: Text(
            titleText,
            style: titleStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
          ),
        ),
        if (tags.isNotEmpty) ...<Widget>[
          const SizedBox(width: 8),
          Flexible(
            child: Wrap(
              spacing: compactTags ? 5 : 6,
              runSpacing: 4,
              children: tags
                  .take(4)
                  .map((String tag) => Text('#$tag', style: tagStyle))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _EntryCardRightDateTime extends StatelessWidget {
  const _EntryCardRightDateTime({required this.entry, this.compact = false});

  final EntryIndexRecord entry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? base = compact ? theme.textTheme.labelSmall : theme.textTheme.labelMedium;
    final TextStyle? muted = base?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          _entryListTimeLabel(entry.updatedAt),
          style: muted,
          textAlign: TextAlign.right,
        ),
        Text(
          '${entry.date.value} ${_weekdayZhFromDateOnly(entry.date)}',
          style: muted,
          textAlign: TextAlign.right,
        ),
      ],
    );
  }
}

class _EntryPreviewImageStrip extends StatelessWidget {
  const _EntryPreviewImageStrip({
    required this.paths,
    this.thumbSize = 72,
  });

  final List<String> paths;
  final double thumbSize;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: <Widget>[
          for (int i = 0; i < paths.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i < paths.length - 1 ? 10 : 0),
              child: EntryCoverThumbnail(
                encryptedFilePath: paths[i],
                size: thumbSize,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final EntryIndexRecord entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? trimmedTitle = entry.title?.trim();
    final bool hasTitle = trimmedTitle != null && trimmedTitle.isNotEmpty;
    final bool showAttachmentChip = entry.attachmentCount > entry.previewImagePaths.length;

    return InkWell(
      onTap: () => context.push('/editor/${entry.id}'),
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _EntryTitleAndTagsRow(
                      titleText: _entryListHeadline(entry),
                      tags: entry.tags,
                      titleStyle: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _EntryCardRightDateTime(entry: entry),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: entry.isDeleted
                        ? Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 22)
                        : Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 22,
                          ),
                  ),
                ],
              ),
              if (hasTitle && entry.previewText.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  entry.previewText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                ),
              ],
              if (showAttachmentChip ||
                  (entry.mood != null && entry.mood!.trim().isNotEmpty)) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    if (entry.mood != null && entry.mood!.trim().isNotEmpty)
                      _MetaChip(label: entry.mood!),
                    if (showAttachmentChip)
                      _MetaChip(label: '${entry.attachmentCount} 個附件'),
                  ],
                ),
              ],
              if (entry.previewImagePaths.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _EntryPreviewImageStrip(
                  paths: entry.previewImagePaths,
                  thumbSize: 76,
                ),
              ],
            ],
          ),
        ),
    );
  }
}

class _HeaderTabButton extends StatelessWidget {
  const _HeaderTabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minWidth: 72),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: active ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: active ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(18),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: theme.colorScheme.primary),
      ),
    );
  }
}

class _OverviewMetricPanel extends StatelessWidget {
  const _OverviewMetricPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      surfaceTintColor: Colors.transparent,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.insights_rounded,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '資料概覽',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _PaneEmptyHint extends StatelessWidget {
  const _PaneEmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.4,
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int columns = width >= 980
            ? 4
            : width >= 720
                ? 3
                : 2;
        final double gap = 12;
        final double itemWidth = (width - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map((Widget child) => SizedBox(width: math.max(140, itemWidth), child: child))
              .toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.toneIndex = 0,
  });

  final String label;
  final String value;
  final int toneIndex;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color fill = _HomePalette.metricSurface(cs, toneIndex);
    final Color onFill = _HomePalette.metricOnSurface(cs, toneIndex);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: onFill.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: onFill,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.listSection = false,
    this.stripeColor,
  });

  final String title;
  final Widget child;
  final bool listSection;
  final Color? stripeColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color bg = listSection
        ? (theme.brightness == Brightness.light
            ? Colors.white
            : cs.surfaceContainerLowest)
        : cs.surface;
    final Color stripe = stripeColor ?? cs.primary;

    return Material(
      color: bg,
      elevation: 1,
      surfaceTintColor: Colors.transparent,
      shadowColor: cs.shadow.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 4,
                  height: 22,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: stripe,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _SectionShell(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(icon, size: 32, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 12),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(cs.tertiary.withValues(alpha: 0.12), cs.tertiaryContainer),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cs.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String _entryListHeadline(EntryIndexRecord entry) {
  final String trimmed = entry.title?.trim() ?? '';
  return trimmed.isNotEmpty ? trimmed : entry.previewText;
}

String _entryListTimeLabel(DateTime at) => DateFormat('HH:mm').format(at);

String _weekdayZhFromDateOnly(DateOnly date) {
  const List<String> names = <String>['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
  return names[date.toDateTime().weekday - 1];
}

String _blockedTitle(AppLockStatus status) {
  return switch (status) {
    AppLockStatus.locked => '目前已鎖定',
    AppLockStatus.recoveryRequired => '需要 Recovery Key',
    AppLockStatus.fatalError => '無法讀取日記庫',
    _ => '尚未完成設定',
  };
}

String _blockedMessage(AppSessionState sessionState) {
  if (sessionState.status == AppLockStatus.unlocked && sessionState.session == null) {
    return '請先建立 Recovery Key，之後才能開始建立與解鎖日記。';
  }
  if (sessionState.status == AppLockStatus.recoveryRequired) {
    return '請先使用 Recovery Key 解鎖，才能讀取與編輯日記。';
  }
  if (sessionState.status == AppLockStatus.fatalError) {
    return sessionState.message ?? '發生錯誤，暫時無法讀取日記庫。';
  }
  return sessionState.message ?? '請先完成設定後再開始使用。';
}

IconData _blockedIcon(AppLockStatus status) {
  return switch (status) {
    AppLockStatus.locked => Icons.lock_outline,
    AppLockStatus.recoveryRequired => Icons.key_outlined,
    AppLockStatus.fatalError => Icons.error_outline,
    _ => Icons.info_outline,
  };
}
