import 'dart:async' show unawaited;
import 'package:quill_diary/l10n/l10n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/shared/utils/user_facing_error.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import '../home_export_actions.dart';
import '../home_pin_actions.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'entry_widgets.dart';
import 'home_scroll_affordance.dart';
import 'home_selection_toolbar.dart';
import 'home_shared_widgets.dart';

class HomeTimelinePane extends ConsumerStatefulWidget {
  const HomeTimelinePane({required this.sessionState, super.key});

  final AppSessionState sessionState;

  @override
  ConsumerState<HomeTimelinePane> createState() => _HomeTimelinePaneState();
}

class _HomeTimelinePaneState extends ConsumerState<HomeTimelinePane> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  ProviderSubscription<String>? _searchQuerySubscription;
  ProviderSubscription<AsyncValue<List<EntryIndexRecord>>>?
  _entryIndexListSubscription;
  bool _syncingController = false;
  bool _awaitingSearchResync = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(homeSearchQueryProvider),
    );
    _scrollController = ScrollController();
    _searchQuerySubscription = ref.listenManual<String>(
      homeSearchQueryProvider,
      (String? previous, String next) {
        _syncSearchController(next);
        if (previous == next) {
          return;
        }
        if (ref.read(homeEntrySelectionProvider).isActive) {
          _awaitingSearchResync = true;
          final List<EntryIndexRecord>? current = ref
              .read(homeEntryIndexListProvider)
              .value;
          if (current != null) {
            _applySearchResync(current);
          }
          return;
        }
        _pruneSelectionToVisibleEntries();
      },
      fireImmediately: true,
    );
    _entryIndexListSubscription = ref
        .listenManual<AsyncValue<List<EntryIndexRecord>>>(
          homeEntryIndexListProvider,
          (_, AsyncValue<List<EntryIndexRecord>> next) {
            if (!_awaitingSearchResync ||
                !ref.read(homeEntrySelectionProvider).isActive) {
              return;
            }
            next.whenData(_applySearchResync);
          },
        );
  }

  void _applySearchResync(List<EntryIndexRecord> rawEntries) {
    final HomeEntrySelectionState selection = ref.read(
      homeEntrySelectionProvider,
    );
    if (!selection.isActive) {
      _awaitingSearchResync = false;
      return;
    }
    resyncHomeSelectionDisplayOrder(
      selectionController: ref.read(homeEntrySelectionProvider.notifier),
      selection: selection,
      pinnedIds:
          ref.read(homePinnedEntryIdsProvider).value ?? const <EntryId>{},
      rawEntries: rawEntries,
    );
    _awaitingSearchResync = false;
  }

  void _pruneSelectionToVisibleEntries() {
    final List<EntryIndexRecord>? visible = ref.read(homeEntriesProvider).value;
    if (visible == null) {
      return;
    }
    ref
        .read(homeEntrySelectionProvider.notifier)
        .pruneToVisible(visible.map((EntryIndexRecord item) => item.id));
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
    _entryIndexListSubscription?.close();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppSessionState sessionState = widget.sessionState;
    final bool canReadEntries =
        sessionState.isUnlocked && sessionState.session != null;
    final AsyncValue<List<EntryIndexRecord>> entriesAsync = ref.watch(
      homeEntriesProvider,
    );
    final HomeEntrySelectionState selection = ref.watch(
      homeEntrySelectionProvider,
    );
    final String searchQuery = ref.watch(homeSearchQueryProvider).trim();
    final List<EntryIndexRecord> entries =
        entriesAsync.value ?? const <EntryIndexRecord>[];
    final bool showSearchResultCount =
        !selection.isActive && searchQuery.isNotEmpty && entriesAsync.hasValue;
    final bool hasSelectedEntries = selection.selectedIds.isNotEmpty;
    final bool canActOnSelectedEntries = hasSelectedEntries && canReadEntries;
    final Set<EntryId> pinnedEntryIds = ref
        .watch(homePinnedEntryIdsProvider)
        .maybeWhen(
          data: (Set<EntryId> ids) => ids,
          orElse: () => const <EntryId>{},
        );
    final bool allSelectedPinned = homeSelectionAllPinned(
      selection.selectedIds,
      pinnedEntryIds,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        HomeScrollbarGutter(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: selection.isActive
                ? HomeSelectionToolbar(
                    key: const ValueKey<String>('home-selection-toolbar'),
                    selectedCount: selection.selectedIds.length,
                    allSelected:
                        entries.isNotEmpty &&
                        selection.selectedIds.length == entries.length &&
                        entries.every(
                          (EntryIndexRecord item) =>
                              selection.selectedIds.contains(item.id),
                        ),
                    onCancel: () =>
                        ref.read(homeEntrySelectionProvider.notifier).clear(),
                    onSelectAll: () => ref
                        .read(homeEntrySelectionProvider.notifier)
                        .selectAll(
                          entries.map((EntryIndexRecord item) => item.id),
                        ),
                    allPinned: allSelectedPinned,
                    pinToggleEnabled: canActOnSelectedEntries,
                    onTogglePin: () => unawaited(
                      togglePinSelectedHomeEntries(
                        context,
                        ref,
                        sessionState,
                        selection.selectedIds,
                        pinnedEntryIds,
                      ),
                    ),
                    actions: <HomeSelectionAction>[
                      HomeSelectionAction(
                        tooltip: context.l10n.homeTooltipExportHtml,
                        icon: Icons.html,
                        enabled: canActOnSelectedEntries,
                        onPressed: !canActOnSelectedEntries
                            ? null
                            : () => unawaited(
                                exportSelectedHomeEntriesAsHtml(
                                  context,
                                  ref,
                                  sessionState,
                                  selection.selectedIds,
                                ),
                              ),
                      ),
                      HomeSelectionAction(
                        tooltip: context.l10n.homeTooltipDelete,
                        icon: Icons.delete_outline_rounded,
                        destructive: true,
                        enabled: canActOnSelectedEntries,
                        onPressed: !canActOnSelectedEntries
                            ? null
                            : () => unawaited(
                                deleteSelectedHomeEntries(
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
                            hintText: context.l10n.homeSearchHint,
                            onChanged: _handleSearchChanged,
                          ),
                        ),
                        const SizedBox(width: 8),
                        HomeSearchSelectionToggleButton(
                          onPressed: canReadEntries
                              ? () => ref
                                    .read(homeEntrySelectionProvider.notifier)
                                    .enterSelection(
                                      entries
                                          .map(
                                            (EntryIndexRecord item) => item.id,
                                          )
                                          .toList(),
                                    )
                              : null,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        if (showSearchResultCount) ...<Widget>[
          const SizedBox(height: 6),
          HomeScrollbarGutter(
            child: Text(
              context.l10n.homeSearchResultCount(entries.length),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        SizedBox(height: showSearchResultCount ? 6 : 12),
        Expanded(
          child: canReadEntries
              ? HomeScrollAffordance(
                  controller: _scrollController,
                  child: entriesAsync.when(
                    skipLoadingOnReload: true,
                    data: (List<EntryIndexRecord> loadedEntries) {
                      if (loadedEntries.isEmpty) {
                        if (searchQuery.isNotEmpty) {
                          return HomeStateCard(
                            icon: Icons.search_off_rounded,
                            title: context.l10n.homeSearchNoResultsTitle,
                            message: context.l10n.homeSearchNoResultsMessage,
                          );
                        }
                        return HomeStateCard(
                          icon: Icons.auto_stories_outlined,
                          title: context.l10n.homeEmptyDiaryTitle,
                          message: context.l10n.homeEmptyDiaryMessage,
                        );
                      }
                      return HomeEntryList(
                        entries: loadedEntries,
                        controller: _scrollController,
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (Object error, StackTrace _) => HomeStateCard(
                      icon: Icons.error_outline,
                      title: context.l10n.commonReadFailureTitle,
                      message: userFacingErrorMessage(
                        error,
                        l10n: context.l10n,
                      ),
                    ),
                  ),
                )
              : HomeBlockedEntriesPane(sessionState: sessionState),
        ),
      ],
    );
  }
}
