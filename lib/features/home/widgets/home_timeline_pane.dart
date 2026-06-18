import 'dart:async' show unawaited;
import '../../../l10n/l10n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../infrastructure/database/index_database.dart';
import '../../../shared/utils/user_facing_error.dart';
import '../../session/state/app_session_state.dart';
import '../home_export_actions.dart';
import '../providers/home_providers.dart';
import '../state/home_state.dart';
import 'entry_widgets.dart';
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
        final List<EntryIndexRecord>? visible = ref
            .read(homeEntriesProvider)
            .value;
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
    final bool canReadEntries =
        sessionState.isUnlocked && sessionState.session != null;
    final AsyncValue<List<EntryIndexRecord>> entriesAsync = ref.watch(
      homeEntriesProvider,
    );
    final HomeEntrySelectionState selection = ref.watch(
      homeEntrySelectionProvider,
    );
    final List<EntryIndexRecord> entries =
        entriesAsync.value ?? const <EntryIndexRecord>[];
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
                                  .enterSelection()
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
                      return HomeStateCard(
                        icon: Icons.auto_stories_outlined,
                        title: context.l10n.homeEmptyDiaryTitle,
                        message: context.l10n.homeEmptyDiaryMessage,
                      );
                    }
                    return HomeEntryList(entries: loadedEntries);
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (Object error, StackTrace _) => HomeStateCard(
                    icon: Icons.error_outline,
                    title: context.l10n.commonReadFailureTitle,
                    message: userFacingErrorMessage(error, l10n: context.l10n),
                  ),
                )
              : HomeBlockedEntriesPane(sessionState: sessionState),
        ),
      ],
    );
  }
}
