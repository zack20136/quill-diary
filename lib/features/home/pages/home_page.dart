import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:table_calendar/table_calendar.dart';

import '../../../app/router.dart';
import '../../../domain/security/unlocked_vault_session.dart';
import '../../../domain/shared/value_objects.dart';
import '../../../infrastructure/database/index_database.dart';
import '../../../infrastructure/storage/vault_archive_io.dart';
import '../../../infrastructure/storage/tag_styles_store.dart';
import '../../../infrastructure/storage/vault_repository.dart';
import '../../../shared/copy/common_copy.dart';
import '../../../shared/copy/tag_copy.dart';
import '../../../shared/presentation/display_format.dart';
import '../../../shared/utils/weekday_zh.dart';
import '../../../shared/presentation/page_style.dart';
import '../../../shared/presentation/tag_visual.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/tag_providers.dart';
import '../../../shared/utils/diary_presence_tag_counts.dart';
import '../../../shared/utils/tag_catalog_merge.dart';
import '../../../shared/utils/user_facing_error.dart';
import '../../session/presentation/session_status_copy.dart';
import '../../session/providers/session_providers.dart';
import '../../session/session_messages.dart';
import '../../session/state/app_session_state.dart';
import '../../editor/providers/editor_draft_providers.dart';
import '../home_copy.dart';
import '../models/overview_models.dart';
import '../providers/home_providers.dart';
import '../state/home_state.dart';
import '../widgets/calendar/calendar_helpers.dart';
import '../widgets/home_selection_toolbar.dart';
import '../../../shared/presentation/widgets/entry_cover_thumbnail.dart';
import '../../../shared/presentation/widgets/tag_accent_composer_dialog.dart';

part '../widgets/calendar/calendar_day_cell.dart';
part '../widgets/calendar/calendar_pane.dart';
part '../widgets/home_page_widgets.dart';

const double _kPaneSectionGap = 18;
const ScrollCacheExtent _kHomeEntryListCacheExtent = ScrollCacheExtent.pixels(600);
const int _kHtmlExportImageWarningThresholdBytes = 50 * 1024 * 1024;

List<Widget> _overviewDiarySectionSlivers({
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
      const SliverToBoxAdapter(child: SizedBox(height: _kPaneSectionGap)),
      SliverToBoxAdapter(
        child: _DiaryListSectionCard(
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
      const SliverToBoxAdapter(child: SizedBox(height: _kPaneSectionGap)),
      SliverToBoxAdapter(
        child: _DiaryListSectionCard(
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
      const SliverToBoxAdapter(child: SizedBox(height: _kPaneSectionGap)),
      SliverToBoxAdapter(
        child: _DiaryListSectionCard(
          title: diarySectionTitle,
          stripeColor: cs.primary,
          titleTrail: titleTrail,
          child: _PaneEmptyHint(text: diaryEmptyText),
        ),
      ),
    ];
  }

  return <Widget>[
    const SliverToBoxAdapter(child: SizedBox(height: _kPaneSectionGap)),
    SliverToBoxAdapter(
      child: _DiaryListSectionCard(
        title: diarySectionTitle,
        stripeColor: cs.primary,
        titleTrail: titleTrail,
        child: _ScrollableCompactEntryList(entries: entries),
      ),
    ),
    const SliverToBoxAdapter(child: SizedBox(height: 24)),
  ];
}

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
class _BlockedEntriesPane extends StatelessWidget {
  const _BlockedEntriesPane({required this.sessionState});

  final AppSessionState sessionState;

  @override
  Widget build(BuildContext context) {
    if (sessionState.status == AppLockStatus.unlocking) {
      return _StateCard(
        icon: Icons.sync_rounded,
        title: HomeCopy.unlockingTitle,
        message: sessionState.message ?? kTrustedUnlockInProgressMessage,
      );
    }

    if (sessionState.status == AppLockStatus.locked) {
      final bool autoPending = sessionState.resumeAction != null;
      return _StateCard(
        icon: Icons.lock_outline,
        title: blockedTitleForStatus(sessionState.status),
        message: blockedSubtitleForState(sessionState),
        actionLabel: autoPending ? null : HomeCopy.retryVerification,
        onAction: autoPending
            ? null
            : () => unawaited(
                  ProviderScope.containerOf(context)
                      .read(appSessionProvider.notifier)
                      .unlock(),
                ),
      );
    }

    final bool offerSettings = _blockedOffersSettingsNavigation(sessionState);
    return _StateCard(
      icon: _blockedIcon(sessionState.status),
      title: blockedTitleForStatus(sessionState.status),
      message: blockedSubtitleForState(sessionState),
      actionLabel: offerSettings ? HomeCopy.goToSettings : null,
      onAction: offerSettings ? () => unawaited(context.push(AppRouter.settingsRoute)) : null,
    );
  }
}

bool _blockedOffersSettingsNavigation(AppSessionState sessionState) {
  if (sessionState.status == AppLockStatus.recoveryRequired) {
    return true;
  }
  if (sessionState.status == AppLockStatus.locked) {
    return true;
  }
  return sessionState.status == AppLockStatus.unlocked && sessionState.session == null;
}

/// Main landing page for browsing, searching, and summarizing diary content.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
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
        final HomeEntrySelectionState selection = ref.watch(homeEntrySelectionProvider);
        final HomeTab activeTab = ref.watch(homeTabProvider);
        final bool showFab =
            activeTab == HomeTab.home && !selection.isActive;

        return PopScope(
          canPop: !selection.isActive,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop && selection.isActive) {
              ref.read(homeEntrySelectionProvider.notifier).clear();
            }
          },
          child: Scaffold(
            backgroundColor: PageStyle.scaffoldWash(cs),
            appBar: const PreferredSize(
              preferredSize: Size.fromHeight(76),
              child: _HomeHeader(),
            ),
            body: ColoredBox(
              color: PageStyle.scaffoldWash(cs),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    activeTab == HomeTab.calendar ? 12 : 16,
                    4,
                    activeTab == HomeTab.calendar ? 12 : 16,
                    16,
                  ),
                  child: _HomeContent(sessionState: sessionState),
                ),
              ),
            ),
            floatingActionButton: showFab
                ? FloatingActionButton(
                    tooltip: HomeCopy.tooltipNewEntry,
                    backgroundColor: cs.secondaryContainer,
                    foregroundColor: cs.onSecondaryContainer,
                    onPressed: canCreate
                        ? () => unawaited(context.push(AppRouter.editorRoute))
                        : null,
                    child: const Icon(Icons.add_rounded),
                  )
                : null,
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(userFacingErrorMessage(error))),
      ),
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  void _selectTab(WidgetRef ref, HomeTab tab) {
    ref.read(homeEntrySelectionProvider.notifier).clear();
    ref.read(homeTabProvider.notifier).set(tab);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color pageBackground = PageStyle.scaffoldWash(cs);
    final HomeTab activeTab = ref.watch(homeTabProvider);

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: pageBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 76,
      titleSpacing: 0,
      title: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: <Widget>[
              SizedBox(
                height: kHomeSearchRowControlHeight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: 50,
                      child: _HeaderTabButton(
                        label: HomeCopy.navHome,
                        icon: Icons.home_rounded,
                        active: activeTab == HomeTab.home,
                        onTap: () => _selectTab(ref, HomeTab.home),
                      ),
                    ),
                    const SizedBox(width: 5),
                    SizedBox(
                      width: 50,
                      child: _HeaderTabButton(
                        label: HomeCopy.navCalendar,
                        icon: Icons.calendar_month_rounded,
                        active: activeTab == HomeTab.calendar,
                        onTap: () => _selectTab(ref, HomeTab.calendar),
                      ),
                    ),
                    const SizedBox(width: 5),
                    SizedBox(
                      width: 50,
                      child: _HeaderTabButton(
                        label: HomeCopy.navTags,
                        icon: Icons.sell_rounded,
                        active: activeTab == HomeTab.tags,
                        onTap: () => _selectTab(ref, HomeTab.tags),
                      ),
                    ),
                    const SizedBox(width: 5),
                    SizedBox(
                      width: 50,
                      child: _HeaderTabButton(
                        label: HomeCopy.navOverview,
                        icon: Icons.insights_rounded,
                        active: activeTab == HomeTab.overview,
                        onTap: () => _selectTab(ref, HomeTab.overview),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const SizedBox(width: 12),
              _HeaderIconButton(
                tooltip: HomeCopy.tooltipSettings,
                icon: Icons.tune_rounded,
                onPressed: () => unawaited(context.push(AppRouter.settingsRoute)),
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
        HomeTab.tags => _TagsManagePane(sessionState: sessionState, key: const ValueKey<String>('tags')),
      },
    );
  }
}

class _HomeTimelinePane extends ConsumerStatefulWidget {
  const _HomeTimelinePane({
    required this.sessionState,
    super.key,
  });

  final AppSessionState sessionState;

  @override
  ConsumerState<_HomeTimelinePane> createState() => _HomeTimelinePaneState();
}

class _HomeTimelinePaneState extends ConsumerState<_HomeTimelinePane> {
  late final TextEditingController _searchController;
  ProviderSubscription<String>? _searchQuerySubscription;
  bool _syncingController = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(homeSearchQueryProvider),
    );
    _searchQuerySubscription = ref.listenManual<String>(
      homeSearchQueryProvider,
      (String? previous, String next) {
        _syncSearchController(next);
        final List<EntryIndexRecord>? visible = ref.read(homeEntriesProvider).value;
        if (visible != null) {
          ref
              .read(homeEntrySelectionProvider.notifier)
              .pruneToVisible(visible.map((EntryIndexRecord item) => item.id));
        }
      },
      fireImmediately: true,
    );
  }

  void _syncSearchController(String value) {
    if (_searchController.text == value) {
      return;
    }
    _syncingController = true;
    _searchController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _syncingController = false;
  }

  void _handleSearchChanged(String value) {
    if (_syncingController) {
      return;
    }
    if (ref.read(homeSearchQueryProvider) == value) {
      return;
    }
    ref.read(homeSearchQueryProvider.notifier).update(value);
  }

  @override
  void dispose() {
    _searchQuerySubscription?.close();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppSessionState sessionState = widget.sessionState;
    final bool canReadEntries = sessionState.isUnlocked && sessionState.session != null;
    final AsyncValue<List<EntryIndexRecord>> entriesAsync = ref.watch(homeEntriesProvider);
    final HomeEntrySelectionState selection = ref.watch(homeEntrySelectionProvider);
    final List<EntryIndexRecord> entries = entriesAsync.value ?? const <EntryIndexRecord>[];
    final bool hasSelectedEntries = selection.selectedIds.isNotEmpty;
    final bool canActOnSelectedEntries = hasSelectedEntries && canReadEntries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: selection.isActive
              ? HomeSelectionToolbar(
                  key: const ValueKey<String>('home-selection-toolbar'),
                  selectedCount: selection.selectedIds.length,
                  allSelected: entries.isNotEmpty &&
                      selection.selectedIds.length == entries.length &&
                      entries.every((EntryIndexRecord item) => selection.selectedIds.contains(item.id)),
                  onCancel: () => ref.read(homeEntrySelectionProvider.notifier).clear(),
                  onSelectAll: () => ref.read(homeEntrySelectionProvider.notifier).selectAll(
                        entries.map((EntryIndexRecord item) => item.id),
                      ),
                  actions: <HomeSelectionAction>[
                    HomeSelectionAction(
                      tooltip: HomeCopy.tooltipExportHtml,
                      icon: Icons.html,
                      enabled: canActOnSelectedEntries,
                      onPressed: !canActOnSelectedEntries
                          ? null
                          : () => unawaited(
                                _exportSelectedHomeEntriesAsHtml(
                                  context,
                                  ref,
                                  sessionState,
                                  selection.selectedIds,
                                ),
                              ),
                    ),
                    HomeSelectionAction(
                      tooltip: HomeCopy.tooltipDelete,
                      icon: Icons.delete_outline_rounded,
                      destructive: true,
                      enabled: canActOnSelectedEntries,
                      onPressed: !canActOnSelectedEntries
                          ? null
                          : () => unawaited(
                                _deleteSelectedHomeEntries(
                                  context,
                                  ref,
                                  sessionState,
                                  selection.selectedIds,
                                ),
                              ),
                    ),
                  ],
                )
              : SizedBox(
                  key: const ValueKey<String>('home-search-field'),
                  height: kHomeSearchRowControlHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: HomeSearchTextField(
                          controller: _searchController,
                          enabled: canReadEntries,
                          hintText: HomeCopy.searchHint,
                          onChanged: _handleSearchChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      HomeSearchSelectionToggleButton(
                        onPressed: canReadEntries
                            ? () => ref.read(homeEntrySelectionProvider.notifier).enterSelection()
                            : null,
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: canReadEntries
              ? entriesAsync.when(
                  data: (List<EntryIndexRecord> loadedEntries) {
                    if (loadedEntries.isEmpty) {
                      return const _StateCard(
                        icon: Icons.auto_stories_outlined,
                        title: HomeCopy.emptyDiaryTitle,
                        message: HomeCopy.emptyDiaryMessage,
                      );
                    }
                    return _EntryList(entries: loadedEntries);
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (Object error, StackTrace _) => _StateCard(
                    icon: Icons.error_outline,
                    title: CommonCopy.readFailureTitle,
                    message: userFacingErrorMessage(error),
                  ),
                )
              : _BlockedEntriesPane(sessionState: sessionState),
        ),
      ],
    );
  }
}

Future<void> _exportSelectedHomeEntriesAsHtml(
  BuildContext context,
  WidgetRef ref,
  AppSessionState sessionState,
  Set<EntryId> selectedIds,
) async {
  if (sessionState.session == null || selectedIds.isEmpty) {
    return;
  }

  await _exportEntriesAsHtml(context, ref, selectedIds);
}

Future<void> _exportEntriesAsHtml(
  BuildContext context,
  WidgetRef ref,
  Set<EntryId> selectedIds,
) async {
  if (selectedIds.isEmpty) {
    return;
  }

  final Set<EntryId> exportIds = Set<EntryId>.from(selectedIds);
  final transferService = ref.read(vaultTransferServiceProvider);
  try {
    final HtmlExportEstimate estimate =
        await transferService.estimateSelectedHtmlExport(exportIds);
    if (!context.mounted) {
      return;
    }
    if (estimate.exceedsImageBytes(_kHtmlExportImageWarningThresholdBytes)) {
      final bool confirmed = await _confirmLargeHtmlExport(context, estimate);
      if (!confirmed || !context.mounted) {
        return;
      }
    }

    final String? savedPath = await ref
        .read(appSessionProvider.notifier)
        .runSensitiveTask((UnlockedVaultSession activeSession) {
      return transferService.exportSelectedHtmlWithPicker(activeSession, exportIds);
    });
    if (savedPath == null || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(HomeCopy.htmlExportSuccess(p.basename(savedPath)))),
    );
  } on StateError catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(userFacingErrorMessage(error))),
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(userFacingErrorMessage(error))),
    );
  }
}

String _overviewExportLabel(MemoryScope scope) {
  return switch (scope) {
    MemoryScope.all => HomeCopy.exportRecapAll,
    MemoryScope.year => HomeCopy.exportRecapYear,
    MemoryScope.month => HomeCopy.exportRecapMonth,
  };
}

Future<bool> _confirmLargeHtmlExport(
  BuildContext context,
  HtmlExportEstimate estimate,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text(HomeCopy.htmlExportLargeTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(HomeCopy.htmlExportSelectionSummary(
                estimate.entryCount,
                estimate.imageCount,
              )),
              const SizedBox(height: 8),
              Text(HomeCopy.htmlExportImageSize(
                DisplayFormat.formatBytesForDisplay(estimate.imageBytes),
              )),
              Text(HomeCopy.htmlExportEstimatedSize(
                DisplayFormat.formatBytesForDisplay(estimate.estimatedHtmlBytes),
              )),
              const SizedBox(height: 12),
              const Text(HomeCopy.htmlExportEmbeddedHint),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(CommonCopy.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(HomeCopy.htmlExportProceed),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> _deleteSelectedHomeEntries(
  BuildContext context,
  WidgetRef ref,
  AppSessionState sessionState,
  Set<EntryId> selectedIds,
) async {
  final UnlockedVaultSession? session = sessionState.session;
  if (session == null || selectedIds.isEmpty) {
    return;
  }

  final bool? confirmed = await confirmDeleteHomeEntries(context, selectedIds.length);
  if (confirmed != true || !context.mounted) {
    return;
  }

  final VaultRepository repository = ref.read(vaultRepositoryProvider);
  for (final EntryId id in selectedIds) {
    await repository.deleteEntry(session, id);
  }

  ref.read(homeEntrySelectionProvider.notifier).clear();
  if (!context.mounted) {
    return;
  }
  await refreshHomeIndexCaches(ref);
}

class _TagsManagePane extends ConsumerStatefulWidget {
  const _TagsManagePane({required this.sessionState, super.key});

  final AppSessionState sessionState;

  @override
  ConsumerState<_TagsManagePane> createState() => _TagsManagePaneState();
}

class _TagsManagePaneState extends ConsumerState<_TagsManagePane> {
  final TextEditingController _searchCtrl = TextEditingController();
  /// 用於預覽：已選標籤的顯示字串（見 [normalizeText] 比對實際日記）。
  String? _selectedTagLabel;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _presentComposer({
    required Map<String, int> accentMap,
    String? existingLabel,
  }) async {
    final UnlockedVaultSession? session = widget.sessionState.session;
    final int? initialArgb =
        existingLabel == null ? null : accentMap[normalizeText(existingLabel)];
    await showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black45,
      builder: (BuildContext ctx) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 26,
            bottom: 26 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Align(
            child: Material(
              color: Colors.transparent,
              child: TagAccentComposerDialog(
                titleText: existingLabel == null ? TagCopy.addTitle : TagCopy.editTitle,
                initialDisplayLabel: existingLabel,
                lockLabel: existingLabel != null,
                initialAccentArgb: initialArgb,
                primaryButtonLabel: TagCopy.saveButton,
                onDelete: existingLabel == null || session == null
                    ? null
                    : () => _deleteTag(existingLabel, session: session),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteTag(
    String label, {
    required UnlockedVaultSession session,
  }) async {
    final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text(HomeCopy.deleteTagTitle),
          content: Text(HomeCopy.deleteTagConfirm(label)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(CommonCopy.actionCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: const Text(CommonCopy.actionDelete),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }

    final List<EntryIndexRecord> records =
        ref.read(allEntryIndexRecordsProvider).value ?? const <EntryIndexRecord>[];
    final int entryCount = _entriesMatchingTag(records, label).length;

    await ref.read(vaultRepositoryProvider).removeTagFromAllEntries(session, label);
    ref.invalidate(tagCatalogProvider);
    ref.invalidate(tagAccentArgbMapProvider);
    await refreshHomeIndexCaches(ref);

    if (!mounted) {
      return;
    }

    if (_selectedTagLabel != null && normalizeText(_selectedTagLabel!) == normalizeText(label)) {
      setState(() => _selectedTagLabel = null);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          entryCount == 0
              ? HomeCopy.tagDeleted(label)
              : HomeCopy.tagRemovedFromEntries(entryCount, label),
        ),
      ),
    );
  }

  List<EntryIndexRecord> _entriesMatchingTag(List<EntryIndexRecord> all, String displayLabel) {
    final String norm = normalizeText(displayLabel);
    final List<EntryIndexRecord> out = all
        .where(
          (EntryIndexRecord e) =>
              e.tags.any((String t) => normalizeText(t) == norm),
        )
        .toList();
    out.sort((EntryIndexRecord a, EntryIndexRecord b) {
      final int byDate = b.date.value.compareTo(a.date.value);
      if (byDate != 0) {
        return byDate;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return out;
  }

  void _toggleSelectTag(String label) {
    final String normalized = normalizeText(label);
    if (_selectedTagLabel != null &&
        normalizeText(_selectedTagLabel!) == normalized) {
      setState(() => _selectedTagLabel = null);
    } else {
      setState(() => _selectedTagLabel = label);
    }
  }

  Widget _tagDiaryPreviewPanel(List<EntryIndexRecord> records, ThemeData theme, ColorScheme cs) {
    if (_selectedTagLabel == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.swipe_vertical_rounded, size: 40, color: cs.outline),
              const SizedBox(height: 12),
              Text(
                HomeCopy.tagPreviewTitle,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                HomeCopy.tagListGuide,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.42,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final List<EntryIndexRecord> matched = _entriesMatchingTag(records, _selectedTagLabel!);

    return _DiaryListSectionCard(
      title: HomeCopy.tagFilteredDiaryTitle(_selectedTagLabel!, matched.length),
      stripeColor: cs.primary,
      expandBody: true,
      titleTrail: IconButton(
        tooltip: HomeCopy.tooltipDeselectTag,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        onPressed: () => setState(() => _selectedTagLabel = null),
        icon: const Icon(Icons.close_rounded),
      ),
      child: matched.isEmpty
          ? _PaneEmptyHint(
              text: HomeCopy.tagIndexEmptyForTag(_selectedTagLabel!),
            )
          : _ScrollableCompactEntryList(entries: matched.take(40).toList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.sessionState.isUnlocked || widget.sessionState.session == null) {
      return _BlockedEntriesPane(sessionState: widget.sessionState);
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<List<EntryIndexRecord>> entriesAsync = ref.watch(allEntryIndexRecordsProvider);
    final Map<String, int> accentMap = ref.watch(tagAccentArgbMapProvider).maybeWhen(
          data: (Map<String, int> m) => m,
          orElse: () => const <String, int>{},
        );

    final String q = _searchCtrl.text.trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: kHomeSearchRowControlHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: HomeSearchTextField(
                  controller: _searchCtrl,
                  hintText: HomeCopy.tagSearchHint,
                ),
              ),
              const SizedBox(width: 8),
              HomeCircleIconButton(
                tooltip: HomeCopy.tooltipAddTag,
                onPressed: () => _presentComposer(accentMap: accentMap),
                icon: Icons.add_rounded,
                size: kHomeSearchRowControlHeight,
                backgroundColor: Color.alphaBlend(
                  cs.primaryContainer.withValues(alpha: 0.78),
                  cs.surfaceContainerLow,
                ),
                foregroundColor: cs.onPrimaryContainer,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: entriesAsync.when(
            data: (List<EntryIndexRecord> records) {
              final Map<String, int> freq = diaryPresenceTagCounts(records);
              final List<TagCatalogUsageItem> mergedTags = mergeTagCatalogWithUsage(
                ref.watch(tagCatalogProvider).maybeWhen(
                      data: (List<TagCatalogItem> items) => items,
                      orElse: () => const <TagCatalogItem>[],
                    ),
                freq,
              );
              if (mergedTags.isEmpty) {
                return const _StateCard(
                  icon: Icons.label_outline_rounded,
                  title: HomeCopy.noTagsTitle,
                  message: HomeCopy.noTagsMessage,
                );
              }
              final List<TagCatalogUsageItem> list = mergedTags
                  .where(
                    (TagCatalogUsageItem item) =>
                        q.isEmpty || item.label.toLowerCase().contains(q),
                  )
                  .toList();
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    CommonCopy.noTagSearchResults,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: cs.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }
              return LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool sideBySide = constraints.maxWidth >= 560;

                  Widget tagListView() {
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: list.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int i) {
                        final TagCatalogUsageItem e = list[i];
                        final (Color bg, Color fg) =
                            tagResolvedAccentPair(e.label, cs, accentMap);
                        final bool isRowSelected = _selectedTagLabel != null &&
                            normalizeText(_selectedTagLabel!) == normalizeText(e.label);
                        final UnlockedVaultSession? session = widget.sessionState.session;

                        return Material(
                          color: cs.surface,
                          elevation: isRowSelected ? 1.5 : 1,
                          shadowColor: cs.shadow.withValues(alpha: 0.08),
                          surfaceTintColor: Colors.transparent,
                          borderRadius: BorderRadius.circular(PageStyle.radiusCard),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(PageStyle.radiusCard),
                              side: isRowSelected
                                  ? BorderSide(
                                      color: cs.primary.withValues(alpha: 0.55),
                                      width: 1.4,
                                    )
                                  : BorderSide.none,
                            ),
                            selected: isRowSelected,
                            selectedTileColor: cs.primaryContainer.withValues(alpha: 0.42),
                            onTap: () => _toggleSelectTag(e.label),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: bg.withValues(alpha: 0.95),
                                border: Border.all(color: fg.withValues(alpha: 0.34)),
                              ),
                              alignment: Alignment.center,
                              child: Icon(Icons.sell_rounded, color: fg, size: 22),
                            ),
                            title: Text(
                              e.label,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              HomeCopy.tagRowSummary(
                                e.count,
                                accentMap.containsKey(normalizeText(e.label)),
                              ),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                HomeCircleIconButton(
                                  tooltip: HomeCopy.tooltipEditTag,
                                  onPressed: () => _presentComposer(
                                    accentMap: accentMap,
                                    existingLabel: e.label,
                                  ),
                                  icon: Icons.edit_outlined,
                                  size: kHomeToolbarActionCircleSize,
                                  backgroundColor: Color.alphaBlend(
                                    cs.secondaryContainer.withValues(alpha: 0.65),
                                    cs.surface,
                                  ),
                                  foregroundColor: cs.onSecondaryContainer,
                                ),
                                const SizedBox(width: 6),
                                HomeCircleIconButton(
                                  tooltip: HomeCopy.tooltipDeleteTag,
                                  onPressed: session == null
                                      ? null
                                      : () => _deleteTag(e.label, session: session),
                                  icon: Icons.delete_outline_rounded,
                                  size: kHomeToolbarActionCircleSize,
                                  backgroundColor: cs.errorContainer,
                                  foregroundColor: cs.onErrorContainer,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }

                  final Widget previewPane = DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(PageStyle.radiusCard),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.42),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(PageStyle.radiusCard),
                      child: _tagDiaryPreviewPanel(records, theme, cs),
                    ),
                  );

                  if (sideBySide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          flex: 46,
                          child: tagListView(),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: cs.outlineVariant.withValues(alpha: 0.45),
                          ),
                        ),
                        Expanded(
                          flex: 54,
                          child: previewPane,
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        flex: 53,
                        child: tagListView(),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        flex: 47,
                        child: previewPane,
                      ),
                    ],
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object err, StackTrace _) => _StateCard(
              icon: Icons.error_outline_rounded,
              title: CommonCopy.readFailureTitle,
              message: '$err',
            ),
          ),
        ),
      ],
    );
  }
}
