import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/shared/value_objects.dart';
import '../../../infrastructure/database/index_database.dart';
import '../../../shared/copy/common_copy.dart';
import '../../../shared/presentation/display_format.dart';
import '../../../shared/presentation/page_style.dart';
import '../../../shared/presentation/tag_visual.dart';
import '../../../shared/providers/tag_providers.dart';
import '../../../shared/utils/tag_catalog_merge.dart';
import '../../../shared/utils/user_facing_error.dart';
import '../../session/state/app_session_state.dart';
import '../home_copy.dart';
import '../home_export_actions.dart';
import '../home_layout.dart';
import '../home_palette.dart';
import '../models/overview_models.dart';
import '../overview_export.dart';
import '../providers/home_providers.dart';
import '../state/home_state.dart';
import 'entry_widgets.dart';
import 'home_shared_widgets.dart';

const double kOverviewScopeControlHeight = 40;

String overviewMetricRangeCaption(MemoryScope scope, DateTime focusedMonth, int focusedYear) {
  return switch (scope) {
    MemoryScope.all => HomeCopy.overviewScopeAll,
    MemoryScope.year => HomeCopy.overviewScopeYear(focusedYear),
    MemoryScope.month => HomeCopy.overviewScopeMonth(focusedMonth.year, focusedMonth.month),
  };
}

int overviewScopeTotalDays({
  required MemoryScope scope,
  required DateTime focusedMonth,
  required int focusedYear,
  required List<EntryIndexRecord> entries,
}) {
  switch (scope) {
    case MemoryScope.month:
      return DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    case MemoryScope.year:
      final DateTime start = DateTime(focusedYear, 1, 1);
      final DateTime end = DateTime(focusedYear + 1, 1, 1);
      return end.difference(start).inDays;
    case MemoryScope.all:
      if (entries.isEmpty) {
        return 0;
      }
      final List<DateTime> dates = entries
          .map((EntryIndexRecord item) => item.date.toDateTime())
          .toList()
        ..sort();
      return dates.last.difference(dates.first).inDays + 1;
  }
}

String overviewScopedDiarySectionTitle(MemoryScope scope, {String? selectedTag}) {
  final String base = switch (scope) {
    MemoryScope.all => HomeCopy.diarySectionAll,
    MemoryScope.year => HomeCopy.diarySectionByYear,
    MemoryScope.month => HomeCopy.diarySectionByMonth,
  };
  if (selectedTag == null || selectedTag.isEmpty) {
    return base;
  }
  return HomeCopy.diarySectionWithTag(base, selectedTag);
}

List<Widget> overviewDiarySectionSlivers({
  required BuildContext context,
  required ColorScheme cs,
  required String diarySectionTitle,
  required String diaryEmptyText,
  required List<EntryIndexRecord>? diaryEntries,
  required bool diaryLoading,
  Widget? titleTrail,
  Object? diaryError,
}) {
  if (diaryLoading) {
    return <Widget>[
      const SliverToBoxAdapter(child: SizedBox(height: HomeLayout.sectionGap)),
      SliverToBoxAdapter(
        child: HomeDiaryListSectionCard(
          title: diarySectionTitle,
          stripeColor: cs.primary,
          titleTrail: titleTrail,
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
    ];
  }

  if (diaryError != null) {
    return <Widget>[
      const SliverToBoxAdapter(child: SizedBox(height: HomeLayout.sectionGap)),
      SliverToBoxAdapter(
        child: HomeDiaryListSectionCard(
          title: diarySectionTitle,
          stripeColor: cs.primary,
          titleTrail: titleTrail,
          child: Text('$diaryError'),
        ),
      ),
    ];
  }

  final List<EntryIndexRecord> entries = diaryEntries ?? const <EntryIndexRecord>[];
  if (entries.isEmpty) {
    return <Widget>[
      const SliverToBoxAdapter(child: SizedBox(height: HomeLayout.sectionGap)),
      SliverToBoxAdapter(
        child: HomeDiaryListSectionCard(
          title: diarySectionTitle,
          stripeColor: cs.primary,
          titleTrail: titleTrail,
          child: HomePaneEmptyHint(text: diaryEmptyText),
        ),
      ),
    ];
  }

  return <Widget>[
    const SliverToBoxAdapter(child: SizedBox(height: HomeLayout.sectionGap)),
    SliverToBoxAdapter(
      child: HomeDiaryListSectionCard(
        title: diarySectionTitle,
        stripeColor: cs.primary,
        titleTrail: titleTrail,
        child: HomeCompactEntryList(entries: entries),
      ),
    ),
    const SliverToBoxAdapter(child: SizedBox(height: 24)),
  ];
}

class OverviewPane extends ConsumerWidget {
  const OverviewPane({
    required this.sessionState,
    super.key,
  });

  final AppSessionState sessionState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canReadEntries = sessionState.isUnlocked && sessionState.session != null;
    final AsyncValue<List<EntryIndexRecord>> allEntriesAsync =
        ref.watch(allEntryIndexRecordsProvider);
    final AsyncValue<List<EntryIndexRecord>> scopedEntriesAsync = ref.watch(memoryEntriesProvider);
    final String? selectedTag = ref.watch(overviewTagFilterProvider);
    final MemoryScope scope = ref.watch(memoryScopeProvider);

    if (!canReadEntries) {
      return HomeBlockedEntriesPane(sessionState: sessionState);
    }

    return allEntriesAsync.when(
      data: (List<EntryIndexRecord> allEntries) {
        if (allEntries.isEmpty) {
          return const HomeStateCard(
            icon: Icons.insights_outlined,
            title: HomeCopy.noAnalysisTitle,
            message: HomeCopy.noAnalysisMessage,
          );
        }

        final ColorScheme cs = Theme.of(context).colorScheme;
        final Map<String, int> tagAccents = ref.watch(tagAccentArgbMapProvider).maybeWhen(
              data: (Map<String, int> m) => m,
              orElse: () => const <String, int>{},
            );
        final DateTime focusedMonth = ref.watch(memoryFocusedMonthProvider);
        final int focusedYear = ref.watch(memoryFocusedYearProvider);
        final String diarySectionTitle =
            overviewScopedDiarySectionTitle(scope, selectedTag: selectedTag);
        final String diaryEmptyText = selectedTag == null
            ? HomeCopy.scopeEmptyDiary
            : HomeCopy.scopeEmptyDiaryForTag(selectedTag);
        final Widget? diarySectionTitleTrail = selectedTag == null
            ? null
            : HomeDiarySectionCloseButton(
                onPressed: () => ref.read(overviewTagFilterProvider.notifier).set(null),
              );

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
            final Set<EntryId> exportEntryIds = resolveOverviewExportEntryIds(
              scope: scope,
              allEntries: allEntries,
              scopedEntries: raw,
            );
            final List<TagCatalogUsageItem> scopedTopTags = rankedTagUsageFromEntries(raw);
            final Widget exportButton = Tooltip(
              message: overviewExportLabel(scope),
              child: FilledButton.icon(
                onPressed: exportEntryIds.isEmpty
                    ? null
                    : () => unawaited(exportEntriesAsHtml(context, ref, exportEntryIds)),
                style: const ButtonStyle(
                  fixedSize: WidgetStatePropertyAll<Size>(
                    Size.fromHeight(kOverviewScopeControlHeight),
                  ),
                  minimumSize: WidgetStatePropertyAll<Size>(
                    Size(0, kOverviewScopeControlHeight),
                  ),
                  maximumSize: WidgetStatePropertyAll<Size>(
                    Size(double.infinity, kOverviewScopeControlHeight),
                  ),
                  padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
                    EdgeInsets.symmetric(horizontal: 18),
                  ),
                  shape: WidgetStatePropertyAll<OutlinedBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text(HomeCopy.exportRecapLabel),
              ),
            );

            return NotificationListener<OverscrollIndicatorNotification>(
              onNotification: (OverscrollIndicatorNotification notification) {
                notification.disallowIndicator();
                return false;
              },
              child: CustomScrollView(
                scrollCacheExtent: HomeLayout.entryListCacheExtent,
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        OverviewScopePicker(exportButton: exportButton),
                        const SizedBox(height: HomeLayout.sectionGap),
                        OverviewScopedMetricPanel(
                          scope: scope,
                          focusedMonth: focusedMonth,
                          focusedYear: focusedYear,
                          entriesAsync: scopedEntriesAsync,
                        ),
                        const SizedBox(height: HomeLayout.sectionGap),
                        HomeSectionCard(
                          title: HomeCopy.popularTagsTitle,
                          stripeColor: cs.tertiary,
                          child: scopedTopTags.isEmpty
                              ? HomePaneEmptyHint(text: HomeCopy.scopeEmptyTags)
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: scopedTopTags
                                      .map(
                                        (TagCatalogUsageItem item) {
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
                      ],
                    ),
                  ),
                  ...overviewDiarySectionSlivers(
                    context: context,
                    cs: cs,
                    diarySectionTitle: diarySectionTitle,
                    diaryEmptyText: diaryEmptyText,
                    diaryEntries: diaryEntries,
                    diaryLoading: false,
                    titleTrail: diarySectionTitleTrail,
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
              scrollCacheExtent: HomeLayout.entryListCacheExtent,
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const OverviewScopePicker(),
                      const SizedBox(height: HomeLayout.sectionGap),
                      OverviewScopedMetricPanel(
                        scope: scope,
                        focusedMonth: focusedMonth,
                        focusedYear: focusedYear,
                        entriesAsync: scopedEntriesAsync,
                      ),
                    ],
                  ),
                ),
                ...overviewDiarySectionSlivers(
                  context: context,
                  cs: cs,
                  diarySectionTitle: diarySectionTitle,
                  diaryEmptyText: diaryEmptyText,
                  diaryEntries: null,
                  diaryLoading: true,
                  titleTrail: diarySectionTitleTrail,
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
              scrollCacheExtent: HomeLayout.entryListCacheExtent,
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const OverviewScopePicker(),
                      const SizedBox(height: HomeLayout.sectionGap),
                      OverviewScopedMetricPanel(
                        scope: scope,
                        focusedMonth: focusedMonth,
                        focusedYear: focusedYear,
                        entriesAsync: scopedEntriesAsync,
                      ),
                    ],
                  ),
                ),
                ...overviewDiarySectionSlivers(
                  context: context,
                  cs: cs,
                  diarySectionTitle: diarySectionTitle,
                  diaryEmptyText: diaryEmptyText,
                  diaryEntries: null,
                  diaryLoading: false,
                  diaryError: error,
                  titleTrail: diarySectionTitleTrail,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace _) => HomeStateCard(
        icon: Icons.error_outline,
        title: CommonCopy.readFailureTitle,
        message: userFacingErrorMessage(error),
      ),
    );
  }
}

class OverviewScopedMetricPanel extends StatelessWidget {
  const OverviewScopedMetricPanel({
    required this.scope,
    required this.focusedMonth,
    required this.focusedYear,
    required this.entriesAsync,
    super.key,
  });

  final MemoryScope scope;
  final DateTime focusedMonth;
  final int focusedYear;
  final AsyncValue<List<EntryIndexRecord>> entriesAsync;

  @override
  Widget build(BuildContext context) {
    final String caption = overviewMetricRangeCaption(scope, focusedMonth, focusedYear);

    return OverviewMetricShell(
      rangeCaption: caption,
      child: entriesAsync.when(
        data: (List<EntryIndexRecord> entries) {
          final OverviewScopeMetrics metrics = OverviewScopeMetrics.fromEntries(entries);
          final int scopeTotalDays = overviewScopeTotalDays(
            scope: scope,
            focusedMonth: focusedMonth,
            focusedYear: focusedYear,
            entries: entries,
          );
          return Column(
            children: <Widget>[
              OverviewNumericTile(
                label: HomeCopy.overviewWritingDaysLabel,
                value: DisplayFormat.formatRatio(metrics.activeDays, scopeTotalDays, '天'),
                detail: [
                  metrics.mostEntriesInSingleDayDetail(),
                  HomeCopy.overviewLongestStreak(metrics.longestWritingStreakDays),
                ].whereType<String>().join('\n'),
              ),
              const SizedBox(height: 13),
              OverviewNumericTile(
                label: HomeCopy.overviewAvgLengthLabel,
                value: HomeCopy.overviewAvgLengthValue(
                  metrics.avgCharactersPerEntryRounded,
                ),
                detail: HomeCopy.overviewEntryStats(
                  metrics.totalEntries,
                  metrics.totalCharacters,
                ),
              ),
              const SizedBox(height: 13),
              OverviewNumericTile(
                label: HomeCopy.overviewAttachmentsLabel,
                value: HomeCopy.overviewAttachmentCount(metrics.totalAttachments),
                detail: metrics.attachmentDetail(),
              ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (Object error, StackTrace _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(userFacingErrorMessage(error)),
        ),
      ),
    );
  }
}

class MemoryFocusedPeriodBar extends ConsumerWidget {
  const MemoryFocusedPeriodBar({super.key});

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
                                ? DisplayFormat.formatYearMonthZh(
                                    focusedMonth.year,
                                    focusedMonth.month,
                                  )
                                : DisplayFormat.formatYearZh(focusedYear),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
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
          error: (Object error, StackTrace _) => Text(userFacingErrorMessage(error)),
        );
  }
}

class OverviewScopePicker extends ConsumerWidget {
  const OverviewScopePicker({this.exportButton, super.key});

  final Widget? exportButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MemoryScope scope = ref.watch(memoryScopeProvider);
    final ColorScheme cs = Theme.of(context).colorScheme;

    return HomeSectionCard(
      title: HomeCopy.scopeTitle,
      stripeColor: cs.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: kOverviewScopeControlHeight,
                  child: SegmentedButton<MemoryScope>(
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
                        label: Text(HomeCopy.scopeAllLabel),
                      ),
                      ButtonSegment<MemoryScope>(
                        value: MemoryScope.year,
                        label: Text(HomeCopy.scopeYearLabel),
                      ),
                      ButtonSegment<MemoryScope>(
                        value: MemoryScope.month,
                        label: Text(HomeCopy.scopeMonthLabel),
                      ),
                    ],
                    selected: <MemoryScope>{scope},
                    onSelectionChanged: (Set<MemoryScope> next) {
                      if (next.isEmpty) {
                        return;
                      }
                      final MemoryScope picked = next.first;
                      if (picked == scope) {
                        return;
                      }
                      ref.read(overviewTagFilterProvider.notifier).set(null);
                      ref.read(memoryScopeProvider.notifier).set(picked);
                    },
                  ),
                ),
              ),
              if (exportButton != null) ...<Widget>[
                const SizedBox(width: 10),
                exportButton!,
              ],
            ],
          ),
          const SizedBox(height: 14),
          const MemoryFocusedPeriodBar(),
        ],
      ),
    );
  }
}

class OverviewMetricShell extends StatelessWidget {
  const OverviewMetricShell({
    required this.rangeCaption,
    required this.child,
    super.key,
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
                        HomeCopy.overviewDataTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
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

class OverviewNumericTile extends StatelessWidget {
  const OverviewNumericTile({
    required this.label,
    required this.value,
    this.detail,
    super.key,
  });

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomePalette.metricTileFill(cs),
        borderRadius: BorderRadius.circular(18),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs, opacity: 0.48)),
      ),
      child: SizedBox(
        height: 92,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 14, 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: HomePalette.metricTileTitle(cs),
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 1),
              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -3),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (detail != null && detail!.trim().isNotEmpty)
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 92),
                            child: Text(
                              detail!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.left,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: HomePalette.metricTileDetail(cs),
                                height: 1.1,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            value,
                            textAlign: TextAlign.right,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                              color: HomePalette.metricTileValue(cs),
                            ),
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
