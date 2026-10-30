import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/errors/user_facing_error.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import 'package:quill_diary/application/home/overview_statistics.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/tag/tag_catalog_usage.dart';
import 'package:quill_diary/application/tag/tag_providers.dart';
import 'package:quill_diary/domain/diary/diary_date_policy.dart';
import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/home_export_actions.dart';
import 'package:quill_diary/presentation/home/home_formatters.dart';
import 'package:quill_diary/presentation/home/home_layout.dart';
import 'package:quill_diary/presentation/home/widgets/home_scroll_affordance.dart';
import 'package:quill_diary/presentation/home/widgets/home_shared_widgets.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/date_picker/app_date_picker_dialog.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/person_visual.dart';
import 'package:quill_diary/shared/presentation/tag_visual.dart';
import 'package:quill_diary/shared/presentation/widgets/app_loading_state.dart';
import 'package:quill_diary/shared/presentation/widgets/app_state_card.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';

const double kOverviewScopeControlHeight = 40;

String overviewMetricRangeCaption(
  BuildContext context,
  OverviewScope scope,
  DateTime focusedMonth,
  int focusedYear,
) {
  return switch (scope) {
    OverviewScope.all => context.l10n.homeOverviewScopeAll,
    OverviewScope.year => context.l10n.homeOverviewScopeYear(focusedYear),
    OverviewScope.month => context.l10n.homeOverviewScopeMonth(
      focusedMonth.year,
      focusedMonth.month,
    ),
  };
}

int overviewScopeTotalDays({
  required OverviewScope scope,
  required DateTime focusedMonth,
  required int focusedYear,
  required List<DiaryEntrySummary> entries,
}) {
  switch (scope) {
    case OverviewScope.month:
      return DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    case OverviewScope.year:
      final DateTime start = DateTime(focusedYear, 1, 1);
      final DateTime end = DateTime(focusedYear + 1, 1, 1);
      return end.difference(start).inDays;
    case OverviewScope.all:
      if (entries.isEmpty) {
        return 0;
      }
      final List<DateTime> dates =
          entries
              .map((DiaryEntrySummary item) => item.date.toDateTime())
              .toList()
            ..sort();
      return dates.last.difference(dates.first).inDays + 1;
  }
}

String overviewScopedDiarySectionTitle(
  BuildContext context,
  OverviewScope scope, {
  String? selectedTag,
}) {
  final String base = switch (scope) {
    OverviewScope.all => context.l10n.homeDiarySectionAll,
    OverviewScope.year => context.l10n.homeDiarySectionByYear,
    OverviewScope.month => context.l10n.homeDiarySectionByMonth,
  };
  if (selectedTag == null || selectedTag.isEmpty) {
    return base;
  }
  return context.l10n.homeDiarySectionWithTag(base, selectedTag);
}

List<Widget> overviewDiarySectionSlivers({
  required BuildContext context,
  required ColorScheme cs,
  required String diarySectionTitle,
  required String diaryEmptyText,
  required List<DiaryEntrySummary>? diaryEntries,
  required bool diaryLoading,
  Object? diaryError,
}) {
  if (diaryLoading) {
    return <Widget>[
      const SliverToBoxAdapter(child: SizedBox(height: HomeLayout.sectionGap)),
      SliverToBoxAdapter(
        child: HomeSectionCard(
          title: diarySectionTitle,
          stripeColor: cs.primary,
          child: const AppLoadingState(),
        ),
      ),
    ];
  }

  if (diaryError != null) {
    return <Widget>[
      const SliverToBoxAdapter(child: SizedBox(height: HomeLayout.sectionGap)),
      SliverToBoxAdapter(
        child: HomeSectionCard(
          title: diarySectionTitle,
          stripeColor: cs.primary,
          child: Text(userFacingErrorMessage(diaryError, l10n: context.l10n)),
        ),
      ),
    ];
  }

  final List<DiaryEntrySummary> entries =
      diaryEntries ?? const <DiaryEntrySummary>[];
  if (entries.isEmpty) {
    return <Widget>[
      const SliverToBoxAdapter(child: SizedBox(height: HomeLayout.sectionGap)),
      SliverToBoxAdapter(
        child: HomeSectionCard(
          title: diarySectionTitle,
          stripeColor: cs.primary,
          child: HomePaneEmptyHint(text: diaryEmptyText),
        ),
      ),
    ];
  }

  return <Widget>[
    const SliverToBoxAdapter(child: SizedBox(height: HomeLayout.sectionGap)),
    HomeDiarySliverSection(
      title: diarySectionTitle,
      stripeColor: cs.primary,
      entries: entries,
    ),
    const SliverToBoxAdapter(child: SizedBox(height: 24)),
  ];
}

class OverviewPane extends ConsumerStatefulWidget {
  const OverviewPane({required this.sessionState, super.key});

  final AppSessionState sessionState;

  @override
  ConsumerState<OverviewPane> createState() => _OverviewPaneState();
}

class _OverviewPaneState extends ConsumerState<OverviewPane> {
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

  @override
  Widget build(BuildContext context) {
    final bool canReadEntries =
        widget.sessionState.isUnlocked && widget.sessionState.session != null;
    final AsyncValue<List<DiaryEntrySummary>> allEntriesAsync = ref.watch(
      allDiaryEntrySummariesProvider,
    );
    final AsyncValue<List<DiaryEntrySummary>> scopedEntriesAsync = ref.watch(
      overviewEntriesProvider,
    );
    final String? selectedTag = ref.watch(overviewTagFilterProvider);
    final OverviewScope scope = ref.watch(overviewScopeProvider);
    final DateTime focusedMonthForPeople = ref.watch(
      overviewFocusedMonthProvider,
    );
    final int focusedYearForPeople = ref.watch(overviewFocusedYearProvider);
    final peopleTopKey = (
      scope: scope,
      focusedYear: focusedYearForPeople,
      focusedMonth: focusedMonthForPeople.month,
    );
    final AsyncValue<List<OverviewPersonRankItem>> peopleTopAsync = ref.watch(
      overviewPeopleTop5Provider(peopleTopKey),
    );

    if (!canReadEntries) {
      return HomeBlockedEntriesPane(sessionState: widget.sessionState);
    }

    return allEntriesAsync.when(
      data: (List<DiaryEntrySummary> allEntries) {
        if (allEntries.isEmpty) {
          return HomeScrollbarGutter(
            child: AppStateCard(
              icon: Icons.insights_outlined,
              title: context.l10n.homeNoAnalysisTitle,
              message: context.l10n.homeNoAnalysisMessage,
            ),
          );
        }

        final ColorScheme cs = Theme.of(context).colorScheme;
        final Map<String, int> tagAccents = ref
            .watch(tagAccentArgbMapProvider)
            .maybeWhen(
              data: (Map<String, int> m) => m,
              orElse: () => const <String, int>{},
            );
        final DateTime focusedMonth = ref.watch(overviewFocusedMonthProvider);
        final int focusedYear = ref.watch(overviewFocusedYearProvider);
        final String diarySectionTitle = overviewScopedDiarySectionTitle(
          context,
          scope,
          selectedTag: selectedTag,
        );
        final String diaryEmptyText = selectedTag == null
            ? context.l10n.homeScopeEmptyDiary
            : context.l10n.homeScopeEmptyDiaryForTag(selectedTag);

        return scopedEntriesAsync.when(
          data: (List<DiaryEntrySummary> raw) {
            final List<DiaryEntrySummary> diaryEntries = selectedTag == null
                ? raw
                : raw
                      .where(
                        (DiaryEntrySummary e) => e.tags.any(
                          (String t) =>
                              normalizeText(t) == normalizeText(selectedTag),
                        ),
                      )
                      .toList(growable: false);
            final Set<EntryId> exportEntryIds =
                (scope == OverviewScope.all ? allEntries : raw)
                    .map((entry) => entry.id)
                    .toSet();
            final List<TagCatalogUsageItem> scopedTopTags =
                rankedTagUsageFromEntries(raw);
            final Widget exportButton = Tooltip(
              message: overviewExportLabel(context, scope),
              child: FilledButton.icon(
                onPressed: exportEntryIds.isEmpty
                    ? null
                    : () => unawaited(
                        exportEntriesAsHtml(
                          context,
                          ref,
                          exportEntryIds,
                          scopeLabel: overviewMetricRangeCaption(
                            context,
                            scope,
                            focusedMonth,
                            focusedYear,
                          ),
                        ),
                      ),
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
                    EdgeInsets.symmetric(horizontal: 12),
                  ),
                  shape: WidgetStatePropertyAll<OutlinedBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(context.l10n.homeExportRecapLabel),
              ),
            );

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
                            title: context.l10n.homePopularTagsTitle,
                            stripeColor: cs.tertiary,
                            child: scopedTopTags.isEmpty
                                ? HomePaneEmptyHint(
                                    text: context.l10n.homeScopeEmptyTags,
                                  )
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: scopedTopTags.map((
                                      TagCatalogUsageItem item,
                                    ) {
                                      final (
                                        Color chipBg,
                                        Color chipFg,
                                      ) = tagResolvedAccentPair(
                                        item.label,
                                        cs,
                                        tagAccents,
                                        context.appColors,
                                      );
                                      final bool isSelected =
                                          selectedTag == item.label;
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
                                        backgroundColor: chipBg,
                                        selectedColor: chipBg,
                                        checkmarkColor: chipFg,
                                        side: accentChipBorderSide(
                                          context.appColors,
                                          cs,
                                          chipBg,
                                          chipFg,
                                          width: isSelected ? 1.05 : 0.92,
                                          accentBorderAlpha: isSelected
                                              ? 0.48
                                              : kAccentBorderAlpha,
                                        ),
                                        onSelected: (_) {
                                          final notifier = ref.read(
                                            overviewTagFilterProvider.notifier,
                                          );
                                          notifier.set(
                                            selectedTag == item.label
                                                ? null
                                                : item.label,
                                          );
                                        },
                                      );
                                    }).toList(),
                                  ),
                          ),
                          peopleTopAsync.when(
                            data: (List<OverviewPersonRankItem> people) {
                              if (people.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  const SizedBox(height: HomeLayout.sectionGap),
                                  HomeSectionCard(
                                    title: context.l10n.homePopularPeopleTitle,
                                    stripeColor: cs.primary,
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: people.map((
                                        OverviewPersonRankItem item,
                                      ) {
                                        final (
                                          Color chipBg,
                                          Color chipFg,
                                        ) = personLabelColorPair(
                                          item.person,
                                          context.appColors.sectionInset,
                                        );
                                        return FilterChip(
                                          label: Text(
                                            '${item.person.name} ${item.mentionedEntryCount}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  color: chipFg,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          selected: false,
                                          showCheckmark: false,
                                          backgroundColor: chipBg,
                                          selectedColor: chipBg,
                                          side: accentChipBorderSide(
                                            context.appColors,
                                            cs,
                                            chipBg,
                                            chipFg,
                                            width: 0.92,
                                            accentBorderAlpha:
                                                kAccentBorderAlpha,
                                          ),
                                          onSelected: (_) => unawaited(
                                            context.push(
                                              AppRoutes.personDetailLocation(
                                                item.person.id,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (Object error, StackTrace _) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                const SizedBox(height: HomeLayout.sectionGap),
                                HomeSectionCard(
                                  title: context.l10n.homePopularPeopleTitle,
                                  stripeColor: cs.primary,
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          userFacingErrorMessage(
                                            error,
                                            l10n: context.l10n,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () => ref.invalidate(
                                          overviewPeopleTop5Provider(
                                            peopleTopKey,
                                          ),
                                        ),
                                        child: Text(
                                          context.l10n.peopleAnalysisRetry,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => HomeScrollAffordance(
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
                  ),
                ],
              ),
            ),
          ),
          error: (Object error, StackTrace _) => HomeScrollAffordance(
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
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const HomeScrollbarGutter(child: AppLoadingState()),
      error: (Object error, StackTrace _) => HomeScrollbarGutter(
        child: AppStateCard(
          icon: Icons.error_outline,
          title: context.l10n.commonReadFailureTitle,
          message: userFacingErrorMessage(error, l10n: context.l10n),
        ),
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

  final OverviewScope scope;
  final DateTime focusedMonth;
  final int focusedYear;
  final AsyncValue<List<DiaryEntrySummary>> entriesAsync;

  @override
  Widget build(BuildContext context) {
    final String caption = overviewMetricRangeCaption(
      context,
      scope,
      focusedMonth,
      focusedYear,
    );

    return OverviewMetricShell(
      rangeCaption: caption,
      child: entriesAsync.when(
        data: (List<DiaryEntrySummary> entries) {
          final OverviewScopeMetrics metrics = OverviewScopeMetrics.fromEntries(
            entries,
          );
          final int scopeTotalDays = overviewScopeTotalDays(
            scope: scope,
            focusedMonth: focusedMonth,
            focusedYear: focusedYear,
            entries: entries,
          );
          return Column(
            children: <Widget>[
              OverviewNumericTile(
                label: context.l10n.homeOverviewWritingDaysLabel,
                value: homeOverviewWritingDaysRatio(
                  context.l10n,
                  metrics.activeDays,
                  scopeTotalDays,
                ),
                detail: [
                  metrics.mostEntriesInSingleDayDetail(context.l10n),
                  homeOverviewLongestStreak(
                    context.l10n,
                    metrics.longestWritingStreakDays,
                  ),
                ].whereType<String>().join('\n'),
              ),
              const SizedBox(height: 13),
              OverviewNumericTile(
                label: context.l10n.homeOverviewAvgLengthLabel,
                value: context.l10n.homeOverviewAvgLengthValue(
                  metrics.avgCharactersPerEntryRounded,
                ),
                detail: homeOverviewEntryStats(
                  context.l10n,
                  metrics.totalEntries,
                  metrics.totalCharacters,
                ),
              ),
              const SizedBox(height: 13),
              OverviewNumericTile(
                label: context.l10n.homeOverviewAttachmentsLabel,
                value: homeOverviewAttachmentCount(
                  context.l10n,
                  metrics.totalAttachments,
                ),
                detail: metrics.attachmentDetail(context.l10n),
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
          child: Text(userFacingErrorMessage(error, l10n: context.l10n)),
        ),
      ),
    );
  }
}

class OverviewFocusedPeriodBar extends ConsumerWidget {
  const OverviewFocusedPeriodBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OverviewScope scope = ref.watch(overviewScopeProvider);
    if (scope == OverviewScope.all) {
      return const SizedBox.shrink();
    }
    final DateTime focusedMonth = ref.watch(overviewFocusedMonthProvider);
    final int focusedYear = ref.watch(overviewFocusedYearProvider);

    return ref
        .watch(overviewAvailableYearsProvider)
        .when(
          data: (List<int> years) {
            final int? minYear = years.isEmpty ? null : years.first;
            final int? maxYear = years.isEmpty ? null : years.last;
            final ThemeData theme = Theme.of(context);
            final ColorScheme cs = theme.colorScheme;
            Future<void> pickFocusedPeriod() async {
              if (scope == OverviewScope.month) {
                final ({DateTime first, DateTime last}) policyRange =
                    DiaryDatePolicy.selectableRange();
                DateTime firstMonth = DateTime(
                  policyRange.first.year,
                  policyRange.first.month,
                );
                DateTime lastMonth = DateTime(
                  policyRange.last.year,
                  policyRange.last.month,
                );
                if (minYear != null && minYear < firstMonth.year) {
                  firstMonth = DateTime(minYear);
                }
                if (maxYear != null && maxYear > lastMonth.year) {
                  lastMonth = DateTime(maxYear, DateTime.december);
                }
                if (focusedMonth.isBefore(firstMonth)) {
                  firstMonth = DateTime(focusedMonth.year, focusedMonth.month);
                }
                if (focusedMonth.isAfter(lastMonth)) {
                  lastMonth = DateTime(focusedMonth.year, focusedMonth.month);
                }
                final DateTime? picked = await showAppYearMonthPickerDialog(
                  context: context,
                  initialMonth: focusedMonth,
                  firstMonth: firstMonth,
                  lastMonth: lastMonth,
                );
                if (picked != null && context.mounted) {
                  ref.read(overviewFocusedMonthProvider.notifier).set(picked);
                }
                return;
              }
              if (minYear == null || maxYear == null) {
                return;
              }
              final int firstYear = focusedYear < minYear
                  ? focusedYear
                  : minYear;
              final int lastYear = focusedYear > maxYear
                  ? focusedYear
                  : maxYear;
              final int? picked = await showAppYearPickerDialog(
                context: context,
                initialYear: focusedYear,
                firstYear: firstYear,
                lastYear: lastYear,
              );
              if (picked != null && context.mounted) {
                ref.read(overviewFocusedYearProvider.notifier).set(picked);
              }
            }

            return Material(
              color: Color.alphaBlend(
                cs.secondary.withValues(alpha: 0.06),
                cs.surfaceContainerLow,
              ),
              borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
                  border: Border.all(color: context.appColors.outlineMuted),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        key: const Key('overview-period-previous'),
                        onPressed: scope == OverviewScope.month
                            ? () => ref
                                  .read(overviewFocusedMonthProvider.notifier)
                                  .set(
                                    DateTime(
                                      focusedMonth.year,
                                      focusedMonth.month - 1,
                                    ),
                                  )
                            : (minYear != null && focusedYear > minYear)
                            ? () => ref
                                  .read(overviewFocusedYearProvider.notifier)
                                  .set(focusedYear - 1)
                            : null,
                        icon: Icon(
                          Icons.chevron_left_rounded,
                          color: cs.primary,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: TextButton(
                            key: const Key('overview-focused-period-button'),
                            onPressed:
                                scope == OverviewScope.month || years.isNotEmpty
                                ? () => unawaited(pickFocusedPeriod())
                                : null,
                            style: TextButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              foregroundColor: cs.onSurface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    scope == OverviewScope.month
                                        ? DisplayFormat.formatYearMonth(
                                            context.l10n,
                                            focusedMonth.year,
                                            focusedMonth.month,
                                          )
                                        : DisplayFormat.formatYear(
                                            context.l10n,
                                            focusedYear,
                                          ),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.arrow_drop_down, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('overview-period-next'),
                        onPressed: scope == OverviewScope.month
                            ? () => ref
                                  .read(overviewFocusedMonthProvider.notifier)
                                  .set(
                                    DateTime(
                                      focusedMonth.year,
                                      focusedMonth.month + 1,
                                    ),
                                  )
                            : (maxYear != null && focusedYear < maxYear)
                            ? () => ref
                                  .read(overviewFocusedYearProvider.notifier)
                                  .set(focusedYear + 1)
                            : null,
                        icon: Icon(
                          Icons.chevron_right_rounded,
                          color: cs.primary,
                        ),
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
          error: (Object error, StackTrace _) =>
              Text(userFacingErrorMessage(error, l10n: context.l10n)),
        );
  }
}

class OverviewScopePicker extends ConsumerWidget {
  const OverviewScopePicker({this.exportButton, super.key});

  final Widget? exportButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OverviewScope scope = ref.watch(overviewScopeProvider);
    final ColorScheme cs = Theme.of(context).colorScheme;

    return HomeSectionCard(
      title: context.l10n.homeScopeTitle,
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
                  child: SegmentedButton<OverviewScope>(
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      side: const WidgetStatePropertyAll<BorderSide>(
                        BorderSide.none,
                      ),
                      shape: WidgetStatePropertyAll<OutlinedBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith((
                        Set<WidgetState> states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return cs.primaryContainer;
                        }
                        return cs.surfaceContainerHighest.withValues(
                          alpha: 0.55,
                        );
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((
                        Set<WidgetState> states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return cs.onPrimaryContainer;
                        }
                        return cs.onSurfaceVariant;
                      }),
                    ),
                    segments: <ButtonSegment<OverviewScope>>[
                      ButtonSegment<OverviewScope>(
                        value: OverviewScope.all,
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            context.l10n.homeScopeAllLabel,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      ButtonSegment<OverviewScope>(
                        value: OverviewScope.year,
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            context.l10n.homeScopeYearLabel,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      ButtonSegment<OverviewScope>(
                        value: OverviewScope.month,
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            context.l10n.homeScopeMonthLabel,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                    selected: <OverviewScope>{scope},
                    onSelectionChanged: (Set<OverviewScope> next) {
                      if (next.isEmpty) {
                        return;
                      }
                      final OverviewScope picked = next.first;
                      if (picked == scope) {
                        return;
                      }
                      ref.read(overviewTagFilterProvider.notifier).set(null);
                      ref.read(overviewScopeProvider.notifier).set(picked);
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
          const OverviewFocusedPeriodBar(),
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

    return AppCard(
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
                child: Icon(
                  Icons.insights_rounded,
                  color: cs.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.homeOverviewDataTitle,
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
    final AppColors colors = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.metricTile,
        borderRadius: BorderRadius.circular(18),
        border: Border.fromBorderSide(colors.outlineBorder(opacity: 0.48)),
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
                  color: colors.metricTileTitle,
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
                                color: colors.metricTileDetail,
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
                              color: colors.metricTileValue,
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
