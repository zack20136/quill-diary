import 'dart:async' show Timer, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/errors/user_facing_error.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/home_export_actions.dart';
import 'package:quill_diary/presentation/home/home_layout.dart';
import 'package:quill_diary/presentation/home/home_pin_actions.dart';
import 'package:quill_diary/presentation/home/widgets/entry_widgets.dart';
import 'package:quill_diary/presentation/home/widgets/home_chat_diary_draft_card.dart';
import 'package:quill_diary/presentation/home/widgets/home_scroll_affordance.dart';
import 'package:quill_diary/presentation/home/widgets/home_selection_toolbar.dart';
import 'package:quill_diary/presentation/home/widgets/home_shared_widgets.dart';
import 'package:quill_diary/shared/presentation/widgets/app_loading_state.dart';
import 'package:quill_diary/shared/presentation/widgets/app_state_card.dart';

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
  ProviderSubscription<AsyncValue<HomeEntryQueryResult>>?
  _entryIndexListSubscription;
  Timer? _searchDebounce;
  bool _syncingController = false;
  bool _deletingSelection = false;
  String? _pendingSelectionSearchQuery;

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
          _pendingSelectionSearchQuery = next;
          return;
        }
        _pendingSelectionSearchQuery = null;
      },
      fireImmediately: true,
    );
    _entryIndexListSubscription = ref
        .listenManual<AsyncValue<HomeEntryQueryResult>>(
          homeEntryIndexListProvider,
          (_, AsyncValue<HomeEntryQueryResult> next) {
            final String? pendingQuery = _pendingSelectionSearchQuery;
            if (pendingQuery == null ||
                !ref.read(homeEntrySelectionProvider).isActive) {
              return;
            }
            next.whenData((HomeEntryQueryResult result) {
              if (result.query == pendingQuery) {
                _applySearchResync(result.entries);
              }
            });
          },
        );
  }

  void _applySearchResync(List<DiaryEntrySummary> rawEntries) {
    final HomeEntrySelectionState selection = ref.read(
      homeEntrySelectionProvider,
    );
    if (!selection.isActive) {
      _pendingSelectionSearchQuery = null;
      return;
    }
    resyncHomeSelectionDisplayOrder(
      selectionController: ref.read(homeEntrySelectionProvider.notifier),
      selection: selection,
      pinnedIds:
          ref.read(homePinnedEntryIdsProvider).value ?? const <EntryId>{},
      rawEntries: rawEntries,
      chatIds: ref.read(homeSearchQueryProvider).trim().isEmpty
          ? (ref.read(chatDiarySessionsProvider).value ?? [])
                .where((chat) => !chat.finished)
                .map((chat) => chat.id)
          : const [],
    );
    _pendingSelectionSearchQuery = null;
  }

  void _syncSearchController(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = null;
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
    _searchDebounce?.cancel();
    _searchDebounce = null;
    if (ref.read(homeSearchQueryProvider) == value) {
      return;
    }
    if (value.isEmpty) {
      ref.read(homeSearchQueryProvider.notifier).update(value);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _searchDebounce = null;
      if (mounted && ref.read(homeSearchQueryProvider) != value) {
        ref.read(homeSearchQueryProvider.notifier).update(value);
      }
    });
  }

  @override
  void dispose() {
    _searchQuerySubscription?.close();
    _entryIndexListSubscription?.close();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _deleteSelection() async {
    if (_deletingSelection) return;
    final selection = ref.read(homeEntrySelectionProvider);
    setState(() => _deletingSelection = true);
    try {
      await deleteSelectedHomeItems(
        context,
        ref,
        widget.sessionState,
        Set.of(selection.selectedIds),
        chatIds: Set.of(selection.selectedChatIds),
      );
    } finally {
      if (mounted) setState(() => _deletingSelection = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppSessionState sessionState = widget.sessionState;
    final bool canReadEntries =
        sessionState.isUnlocked && sessionState.session != null;
    final AsyncValue<List<DiaryEntrySummary>> entriesAsync = ref.watch(
      homeEntriesProvider,
    );
    final HomeEntrySelectionState selection = ref.watch(
      homeEntrySelectionProvider,
    );
    final String searchQuery = ref.watch(homeSearchQueryProvider).trim();
    final List<DiaryEntrySummary> entries =
        entriesAsync.value ?? const <DiaryEntrySummary>[];
    final bool showSearchResultCount =
        !selection.isActive && searchQuery.isNotEmpty && entriesAsync.hasValue;
    final chatDrafts = canReadEntries && searchQuery.isEmpty
        ? (ref.watch(chatDiarySessionsProvider).value ?? [])
              .where((chat) => !chat.finished)
              .toList()
        : const [];
    final canDeleteSelection =
        selection.selectedCount > 0 && canReadEntries && !_deletingSelection;
    final showEntryActions =
        entries.isNotEmpty && selection.selectedChatIds.isEmpty;
    final canActOnSelectedEntries =
        selection.selectedIds.isNotEmpty &&
        canReadEntries &&
        !_deletingSelection &&
        selection.selectedChatIds.isEmpty;
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
                    selectedCount: selection.selectedCount,
                    allSelected:
                        entries.length + chatDrafts.length > 0 &&
                        selection.selectedCount ==
                            entries.length + chatDrafts.length &&
                        entries.every(
                          (item) => selection.selectedIds.contains(item.id),
                        ) &&
                        chatDrafts.every(
                          (chat) => selection.selectedChatIds.contains(chat.id),
                        ),
                    onCancel: () {
                      if (!_deletingSelection) {
                        ref.read(homeEntrySelectionProvider.notifier).clear();
                      }
                    },
                    onSelectAll: () {
                      if (!_deletingSelection) {
                        ref
                            .read(homeEntrySelectionProvider.notifier)
                            .selectAll(
                              entries.map((item) => item.id),
                              chatIds: chatDrafts.map((chat) => chat.id),
                            );
                      }
                    },
                    allPinned: allSelectedPinned,
                    pinToggleEnabled: canActOnSelectedEntries,
                    onTogglePin: !showEntryActions
                        ? null
                        : () => unawaited(
                            togglePinSelectedHomeEntries(
                              context,
                              ref,
                              sessionState,
                              selection.selectedIds,
                              pinnedEntryIds,
                            ),
                          ),
                    actions: <HomeSelectionAction>[
                      if (showEntryActions)
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
                        enabled: canDeleteSelection,
                        onPressed: canDeleteSelection
                            ? () => unawaited(_deleteSelection())
                            : null,
                      ),
                    ],
                  )
                : SizedBox(
                    key: const ValueKey<String>('home-search-field'),
                    height: HomeLayout.searchRowControlHeight,
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
                          onPressed:
                              canReadEntries &&
                                  (entries.isNotEmpty || chatDrafts.isNotEmpty)
                              ? () => ref
                                    .read(homeEntrySelectionProvider.notifier)
                                    .enterSelection(
                                      entries
                                          .map(
                                            (DiaryEntrySummary item) => item.id,
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
                    data: (List<DiaryEntrySummary> loadedEntries) {
                      if (loadedEntries.isEmpty && chatDrafts.isEmpty) {
                        if (searchQuery.isNotEmpty) {
                          return AppStateCard(
                            icon: Icons.search_off_rounded,
                            title: context.l10n.homeSearchNoResultsTitle,
                            message: context.l10n.homeSearchNoResultsMessage,
                          );
                        }
                        return AppStateCard(
                          icon: Icons.auto_stories_outlined,
                          title: context.l10n.homeEmptyDiaryTitle,
                          message: context.l10n.homeEmptyDiaryMessage,
                        );
                      }
                      return IgnorePointer(
                        ignoring: _deletingSelection,
                        child: HomeEntryList(
                          entries: loadedEntries,
                          draftCards: [
                            for (final chat in chatDrafts)
                              HomeChatDiaryDraftCard(
                                key: ValueKey(chat.id),
                                chat: chat,
                                entryDisplayOrder: loadedEntries
                                    .map((entry) => entry.id)
                                    .toList(),
                              ),
                          ],
                          controller: _scrollController,
                        ),
                      );
                    },
                    loading: () => const AppLoadingState(),
                    error: (Object error, StackTrace _) => AppStateCard(
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
