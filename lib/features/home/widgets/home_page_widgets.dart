part of '../pages/home_page.dart';

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
    final AsyncValue<List<EntryIndexRecord>> scopedEntriesAsync = ref.watch(memoryEntriesProvider);
    final String? selectedTag = ref.watch(overviewTagFilterProvider);
    final MemoryScope scope = ref.watch(memoryScopeProvider);

    if (!canReadEntries) {
      return _BlockedEntriesPane(sessionState: sessionState);
    }

    return summaryAsync.when(
      data: (OverviewSummary summary) {
        if (summary.totalEntries == 0) {
          return const _StateCard(
            icon: Icons.insights_outlined,
            title: '尚無可分析內容',
            message: '寫下一篇後，就可以在這裡看到統計、標籤與範圍內的日記。',
          );
        }

        final ColorScheme cs = Theme.of(context).colorScheme;
        final Map<String, int> tagAccents = ref.watch(tagAccentArgbMapProvider).maybeWhen(
              data: (Map<String, int> m) => m,
              orElse: () => const <String, int>{},
            );
        final DateTime focusedMonth = ref.watch(memoryFocusedMonthProvider);
        final int focusedYear = ref.watch(memoryFocusedYearProvider);
        final String diarySectionTitle = _overviewScopedDiarySectionTitle(scope, selectedTag);
        final String diaryEmptyText = selectedTag == null
            ? '此範圍內沒有符合的日記。'
            : '此範圍內沒有套用「$selectedTag」的日記。';

        return scopedEntriesAsync.when(
          data: (List<EntryIndexRecord> raw) {
            final List<EntryIndexRecord> diaryEntries = selectedTag == null
                ? raw
                : raw
                    .where(
                      (EntryIndexRecord e) => e.tags.any(
                        (String t) => normalizeText(t) == normalizeText(selectedTag),
                      ),
                    )
                    .toList(growable: false);

            return NotificationListener<OverscrollIndicatorNotification>(
              onNotification: (OverscrollIndicatorNotification notification) {
                notification.disallowIndicator();
                return false;
              },
              child: CustomScrollView(
                cacheExtent: _kHomeEntryListCacheExtent,
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const _OverviewScopePicker(),
                        const SizedBox(height: _kPaneSectionGap),
                        _OverviewScopedMetricPanel(
                          scope: scope,
                          focusedMonth: focusedMonth,
                          focusedYear: focusedYear,
                          entriesAsync: scopedEntriesAsync,
                        ),
                        const SizedBox(height: _kPaneSectionGap),
                        _SectionCard(
                          title: '熱門標籤',
                          stripeColor: cs.tertiary,
                          child: summary.topTags.isEmpty
                              ? _PaneEmptyHint(text: '目前沒有標籤。')
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: summary.topTags
                                      .map(
                                        (OverviewTagStat item) {
                                          final (Color chipBg, Color chipFg) =
                                              tagResolvedAccentPair(item.label, cs, tagAccents);
                                          final bool isSelected = selectedTag == item.label;
                                          final Color bg = isSelected
                                              ? Color.alphaBlend(
                                                  cs.primary.withValues(alpha: 0.2),
                                                  chipBg,
                                                )
                                              : chipBg;
                                          return FilterChip(
                                            label: Text(
                                              '${item.label} ${item.count}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelMedium
                                                  ?.copyWith(
                                                    color: chipFg,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            selected: isSelected,
                                            showCheckmark: false,
                                            backgroundColor: bg.withValues(alpha: 0.94),
                                            selectedColor: bg.withValues(alpha: 0.98),
                                            checkmarkColor: chipFg,
                                            side: BorderSide(
                                              color: chipFg.withValues(
                                                alpha: isSelected ? 0.48 : 0.3,
                                              ),
                                              width: isSelected ? 1.05 : 0.92,
                                            ),
                                            onSelected: (_) {
                                              final notifier = ref.read(overviewTagFilterProvider.notifier);
                                              notifier.set(
                                                selectedTag == item.label ? null : item.label,
                                              );
                                            },
                                          );
                                        },
                                      )
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: _kPaneSectionGap),
                        _SectionCard(
                          title: '心情紀錄',
                          stripeColor: cs.secondary,
                          child: summary.moods.isEmpty
                              ? _PaneEmptyHint(text: '目前沒有心情標註。')
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
                      ],
                    ),
                  ),
                  ..._overviewDiarySectionSlivers(
                    context: context,
                    cs: cs,
                    diarySectionTitle: diarySectionTitle,
                    diaryEmptyText: diaryEmptyText,
                    diaryEntries: diaryEntries,
                    diaryLoading: false,
                  ),
                ],
              ),
            );
          },
          loading: () => NotificationListener<OverscrollIndicatorNotification>(
            onNotification: (OverscrollIndicatorNotification notification) {
              notification.disallowIndicator();
              return false;
            },
            child: CustomScrollView(
              cacheExtent: _kHomeEntryListCacheExtent,
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _OverviewScopePicker(),
                      const SizedBox(height: _kPaneSectionGap),
                      _OverviewScopedMetricPanel(
                        scope: scope,
                        focusedMonth: focusedMonth,
                        focusedYear: focusedYear,
                        entriesAsync: scopedEntriesAsync,
                      ),
                    ],
                  ),
                ),
                ..._overviewDiarySectionSlivers(
                  context: context,
                  cs: cs,
                  diarySectionTitle: diarySectionTitle,
                  diaryEmptyText: diaryEmptyText,
                  diaryEntries: null,
                  diaryLoading: true,
                ),
              ],
            ),
          ),
          error: (Object error, StackTrace _) => NotificationListener<OverscrollIndicatorNotification>(
            onNotification: (OverscrollIndicatorNotification notification) {
              notification.disallowIndicator();
              return false;
            },
            child: CustomScrollView(
              cacheExtent: _kHomeEntryListCacheExtent,
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _OverviewScopePicker(),
                      const SizedBox(height: _kPaneSectionGap),
                      _OverviewScopedMetricPanel(
                        scope: scope,
                        focusedMonth: focusedMonth,
                        focusedYear: focusedYear,
                        entriesAsync: scopedEntriesAsync,
                      ),
                    ],
                  ),
                ),
                ..._overviewDiarySectionSlivers(
                  context: context,
                  cs: cs,
                  diarySectionTitle: diarySectionTitle,
                  diaryEmptyText: diaryEmptyText,
                  diaryEntries: null,
                  diaryLoading: false,
                  diaryError: error,
                ),
              ],
            ),
          ),
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

String _overviewMetricRangeCaption(MemoryScope scope, DateTime focusedMonth, int focusedYear) {
  return switch (scope) {
    MemoryScope.all => '目前範圍 · 全部日記',
    MemoryScope.year => '目前範圍 · $focusedYear 年',
    MemoryScope.month =>
      '目前範圍 · ${focusedMonth.year} 年 ${focusedMonth.month.toString().padLeft(2, '0')} 月',
  };
}

class _OverviewScopedMetricPanel extends StatelessWidget {
  const _OverviewScopedMetricPanel({
    required this.scope,
    required this.focusedMonth,
    required this.focusedYear,
    required this.entriesAsync,
  });

  final MemoryScope scope;
  final DateTime focusedMonth;
  final int focusedYear;
  final AsyncValue<List<EntryIndexRecord>> entriesAsync;

  @override
  Widget build(BuildContext context) {
    final String caption = _overviewMetricRangeCaption(scope, focusedMonth, focusedYear);

    return _OverviewMetricShell(
      rangeCaption: caption,
      child: entriesAsync.when(
        data: (List<EntryIndexRecord> entries) {
          final OverviewScopeMetrics metrics = OverviewScopeMetrics.fromEntries(entries);
          final String? density = metrics.writingDensitySubtitle();
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth;
              final int columns = width >= 880 ? 4 : 2;
              const double gap = 13;
              final double itemWidth = (width - (gap * (columns - 1))) / columns;

              final List<_OverviewNumericTile> tiles = <_OverviewNumericTile>[
                _OverviewNumericTile(
                  label: '總篇數',
                  value: '${metrics.totalEntries}',
                  toneIndex: 0,
                ),
                _OverviewNumericTile(
                  label: '撰寫天數',
                  value: '${metrics.activeDays}',
                  toneIndex: 1,
                  detail: density,
                ),
                _OverviewNumericTile(
                  label: '平均篇幅',
                  value: '${metrics.avgWordsPerEntryRounded} 字／篇',
                  toneIndex: 2,
                  detail: '累計 ${metrics.totalWords} 字 · ${metrics.totalCharacters} 字元',
                ),
                _OverviewNumericTile(
                  label: '標記與素材',
                  value: '${metrics.totalAttachments} 個附件',
                  toneIndex: 3,
                  detail: metrics.annotationMixedDetail(),
                ),
              ];

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: tiles
                    .map(
                      (Widget t) =>
                          SizedBox(width: math.max(148.0, itemWidth), child: t),
                    )
                    .toList(),
              );
            },
          );
        },
        loading: () => const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (Object error, StackTrace _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text('$error'),
        ),
      ),
    );
  }
}

class _MemoryFocusedPeriodBar extends ConsumerWidget {
  const _MemoryFocusedPeriodBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MemoryScope scope = ref.watch(memoryScopeProvider);
    if (scope == MemoryScope.all) {
      return const SizedBox.shrink();
    }
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
              borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
                  border: Border.all(color: PageStyle.primaryMutedOutline(cs)),
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

class _OverviewScopePicker extends ConsumerWidget {
  const _OverviewScopePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MemoryScope scope = ref.watch(memoryScopeProvider);
    final ColorScheme cs = Theme.of(context).colorScheme;

    return _SectionCard(
      title: '範圍',
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
                value: MemoryScope.all,
                label: Text('全部'),
              ),
              ButtonSegment<MemoryScope>(
                value: MemoryScope.year,
                label: Text('年'),
              ),
              ButtonSegment<MemoryScope>(
                value: MemoryScope.month,
                label: Text('月'),
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
    );
  }
}

/// 總覽式日記列表區塊：`listSection` 外層卡片 + 標題列（可選標題尾端元件）+ 內文。
class _DiaryListSectionCard extends StatelessWidget {
  const _DiaryListSectionCard({
    required this.title,
    required this.child,
    this.stripeColor,
    this.titleTrail,
    this.expandBody = false,
  });

  final String title;
  final Widget child;
  final Color? stripeColor;
  final Widget? titleTrail;
  final bool expandBody;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      listSection: true,
      title: title,
      stripeColor: stripeColor,
      titleTrail: titleTrail,
      expandChild: expandBody,
      child: child,
    );
  }
}

class _ScrollableCompactEntryList extends StatelessWidget {
  const _ScrollableCompactEntryList({required this.entries});

  final List<EntryIndexRecord> entries;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: _CompactEntryList(entries: entries),
      ),
    );
  }
}

/// One elevated card per diary row (replaces the old single outer bordered box).
class _TimelineEntryShell extends StatelessWidget {
  const _TimelineEntryShell({
    required this.child,
    this.tintedCard = false,
    this.selected = false,
  });

  final Widget child;
  final bool tintedCard;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color color =
        tintedCard ? cs.surfaceContainerLow : cs.surface;
    return Material(
      color: color,
      elevation: tintedCard ? 0 : 1,
      surfaceTintColor: Colors.transparent,
      shadowColor: cs.shadow.withValues(alpha: tintedCard ? 0 : 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tintedCard ? PageStyle.radiusPanel : PageStyle.radiusEntry),
        side: selected
            ? BorderSide(color: cs.primary.withValues(alpha: 0.72), width: 1.5)
            : tintedCard
                ? BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))
                : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _EntryList extends ConsumerWidget {
  const _EntryList({required this.entries});

  final List<EntryIndexRecord> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HomeEntrySelectionState selection = ref.watch(homeEntrySelectionProvider);
    final Color pageBackground = PageStyle.scaffoldWash(Theme.of(context).colorScheme);

    return NotificationListener<OverscrollIndicatorNotification>(
      onNotification: (OverscrollIndicatorNotification notification) {
        notification.disallowIndicator();
        return false;
      },
      child: ColoredBox(
        color: pageBackground,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 20),
          cacheExtent: _kHomeEntryListCacheExtent,
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (BuildContext context, int index) {
            final EntryIndexRecord entry = entries[index];
            final bool selected = selection.selectedIds.contains(entry.id);
            return _TimelineEntryShell(
              selected: selection.isActive && selected,
              child: _EntryCard(
                entry: entry,
                selectionActive: selection.isActive,
                selected: selected,
                onTap: () {
                  if (selection.isActive) {
                    ref.read(homeEntrySelectionProvider.notifier).toggle(entry.id);
                    return;
                  }
                  context.push('/editor/${entry.id}');
                },
                onLongPress: () {
                  if (selection.isActive) {
                    ref.read(homeEntrySelectionProvider.notifier).toggle(entry.id);
                    return;
                  }
                  ref.read(homeEntrySelectionProvider.notifier).enterWith(entry.id);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.selectionActive,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final EntryIndexRecord entry;
  final bool selectionActive;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String? trimmedTitle = entry.title?.trim();
    final bool hasTitle = trimmedTitle != null && trimmedTitle.isNotEmpty;
    final bool showPreview = hasTitle && entry.previewText.trim().isNotEmpty;
    final double selectionLeadingWidth = selectionActive ? 34 : 0;

    return Material(
      color: selectionActive && selected
          ? Color.alphaBlend(cs.primaryContainer.withValues(alpha: 0.34), cs.surface)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(PageStyle.radiusEntry),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (selectionActive) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: selected ? cs.primary : cs.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: _EntryTitleAndTagsRow(
                      titleText: _entryListHeadline(entry),
                      tags: entry.tags,
                      titleStyle: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (entry.isDeleted) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 2),
                      child: Icon(Icons.delete_outline, color: cs.error, size: 20),
                    ),
                  ],
                  const SizedBox(width: 10),
                  _EntryCardRightDateTime(entry: entry),
                ],
              ),
              if (showPreview) ...<Widget>[
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.only(left: selectionLeadingWidth),
                  child: Text(
                    entry.previewText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                  ),
                ),
              ],
              if (entry.mood != null && entry.mood!.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.only(left: selectionLeadingWidth),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: <Widget>[
                      _MetaChip(label: entry.mood!),
                    ],
                  ),
                ),
              ],
              if (entry.previewImagePaths.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.only(left: selectionLeadingWidth),
                  child: _EntryPreviewImageStrip(
                    paths: entry.previewImagePaths,
                    thumbSize: 76,
                    lazyLoad: true,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
            (EntryIndexRecord entry) {
              final String? trimmedTitle = entry.title?.trim();
              final bool hasTitle = trimmedTitle != null && trimmedTitle.isNotEmpty;
              final bool showPreview = hasTitle && entry.previewText.trim().isNotEmpty;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TimelineEntryShell(
                  tintedCard: true,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.push('/editor/${entry.id}'),
                      borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                                    compactTags: true,
                                  ),
                                ),
                                if (entry.isDeleted) ...<Widget>[
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, top: 2),
                                    child: Icon(
                                      Icons.delete_outline,
                                      color: theme.colorScheme.error,
                                      size: 18,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 10),
                                _EntryCardRightDateTime(entry: entry, compact: true),
                              ],
                            ),
                            if (showPreview) ...<Widget>[
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
              );
            },
          )
          .toList(),
    );
  }
}

class _EntryTitleAndTagsRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final Map<String, int> accents = ref.watch(tagAccentArgbMapProvider).maybeWhen(
          data: (Map<String, int> m) => m,
          orElse: () => const <String, int>{},
        );
    final List<String> trimmedTags =
        tags.map((String t) => t.trim()).where((String t) => t.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          titleText,
          style: titleStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
        ),
        if (trimmedTags.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: compactTags ? 4 : 5),
            child: Wrap(
              spacing: compactTags ? 5 : 6,
              runSpacing: 4,
              children: trimmedTags
                  .take(4)
                  .map((String tag) {
                    final (Color bg, Color fg) =
                        tagResolvedAccentPair(tag, theme.colorScheme, accents);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: bg.withValues(alpha: 0.92),
                        border: Border.all(
                          color: fg.withValues(alpha: 0.32),
                          width: 0.9,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: (compactTags
                                ? theme.textTheme.labelSmall
                                : theme.textTheme.labelMedium)
                            ?.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
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
          '${entry.date.value} ${_weekdayZhFromDateOnly(entry.date)}',
          style: muted,
          textAlign: TextAlign.right,
        ),
        Text(
          _entryListTimeLabel(entry.createdAt),
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
    this.lazyLoad = false,
  });

  final List<String> paths;
  final double thumbSize;
  final bool lazyLoad;

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
              child: lazyLoad
                  ? LazyEntryCoverThumbnail(
                      encryptedFilePath: paths[i],
                      size: thumbSize,
                      staggerIndex: i,
                      borderRadius: BorderRadius.circular(PageStyle.radiusThumbSmall),
                    )
                  : EntryCoverThumbnail(
                      encryptedFilePath: paths[i],
                      size: thumbSize,
                      borderRadius: BorderRadius.circular(PageStyle.radiusThumbSmall),
                    ),
            ),
        ],
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
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minWidth: 72),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: active ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color foregroundColor = cs.onPrimaryContainer;
    final Color backgroundColor = Color.alphaBlend(
      cs.primaryContainer.withValues(alpha: 0.78),
      cs.surfaceContainerLow,
    );

    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
          side: BorderSide(color: foregroundColor.withValues(alpha: 0.14)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
          child: SizedBox(
            width: kHomeSearchRowControlHeight,
            height: kHomeSearchRowControlHeight,
            child: Icon(icon, size: 22, color: foregroundColor),
          ),
        ),
      ),
    );
  }
}

class _OverviewMetricShell extends StatelessWidget {
  const _OverviewMetricShell({
    required this.rangeCaption,
    required this.child,
  });

  final String rangeCaption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs, opacity: 0.42)),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: <Color>[
            Color.alphaBlend(cs.primary.withValues(alpha: 0.07), cs.surfaceContainerLow),
            Color.alphaBlend(cs.surfaceContainerHigh.withValues(alpha: 0.48), cs.surface),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: cs.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(Icons.insights_rounded, color: cs.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '資料概覽',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: cs.onSurface.withValues(alpha: 0.94),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rangeCaption,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.82),
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _OverviewNumericTile extends StatelessWidget {
  const _OverviewNumericTile({
    required this.label,
    required this.value,
    required this.toneIndex,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;
  final int toneIndex;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color fillBase = _HomePalette.metricSurface(cs, toneIndex);
    final Color onFill = _HomePalette.metricOnSurface(cs, toneIndex);

    final Color tileFill =
        Color.alphaBlend(onFill.withValues(alpha: 0.09), Color.alphaBlend(cs.surface, fillBase));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tileFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs, opacity: 0.48)),
      ),
      child: SizedBox(
        height: 126,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: onFill.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        value,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1.05,
                          color: onFill,
                        ),
                      ),
                      if (detail != null && detail!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            detail!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: onFill.withValues(alpha: 0.74),
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
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
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
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
    this.titleTrail,
    this.expandChild = false,
  });

  final String title;
  final Widget child;
  final bool listSection;
  final Color? stripeColor;
  final Widget? titleTrail;
  final bool expandChild;

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
      borderRadius: BorderRadius.circular(PageStyle.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: expandChild ? MainAxisSize.max : MainAxisSize.min,
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?titleTrail,
              ],
            ),
            const SizedBox(height: 14),
            if (expandChild) Expanded(child: child) else child,
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
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

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
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(actionLabel!),
                ),
              ],
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

String _overviewScopedDiarySectionTitle(MemoryScope scope, String? selectedTag) {
  if (selectedTag != null && selectedTag.isNotEmpty) {
    return '日記 · $selectedTag';
  }
  return switch (scope) {
    MemoryScope.all => '日記 · 全部',
    MemoryScope.year => '日記 · 依年',
    MemoryScope.month => '日記 · 依月',
  };
}

String _entryListHeadline(EntryIndexRecord entry) {
  final String trimmed = entry.title?.trim() ?? '';
  return trimmed.isNotEmpty ? trimmed : entry.previewText;
}

String _firstNonemptyTag(List<String> tags) {
  for (final String tag in tags) {
    final String trimmed = tag.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return '';
}

String _entryListTimeLabel(DateTime at) => DateFormat('HH:mm').format(at);

String _weekdayZhFromDateOnly(DateOnly date) {
  const List<String> names = <String>['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
  return names[date.toDateTime().weekday - 1];
}

IconData _blockedIcon(AppLockStatus status) {
  return switch (status) {
    AppLockStatus.locked => Icons.lock_outline,
    AppLockStatus.recoveryRequired => Icons.key_outlined,
    AppLockStatus.fatalError => Icons.error_outline,
    _ => Icons.info_outline,
  };
}

