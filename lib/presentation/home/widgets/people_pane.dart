import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/errors/user_facing_error.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/people/people_list_query.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/people/person_deletion.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/relationship_type.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/vault_people_service.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/home_layout.dart';
import 'package:quill_diary/presentation/home/widgets/home_scroll_affordance.dart';
import 'package:quill_diary/presentation/home/widgets/home_selection_toolbar.dart';
import 'package:quill_diary/presentation/home/widgets/home_shared_widgets.dart';
import 'package:quill_diary/presentation/people/widgets/person_composer_dialog.dart';
import 'package:quill_diary/presentation/people/widgets/relationship_types_manage_dialog.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_menu_style.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/people_labels.dart';
import 'package:quill_diary/shared/presentation/person_visual.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_loading_state.dart';
import 'package:quill_diary/shared/presentation/widgets/app_progress.dart';
import 'package:quill_diary/shared/presentation/widgets/app_state_card.dart';

/// 人物分頁；首次開啟後保留名冊、統計與畫面狀態。
class PeoplePane extends ConsumerStatefulWidget {
  const PeoplePane({required this.sessionState, super.key});

  final AppSessionState sessionState;

  @override
  ConsumerState<PeoplePane> createState() => _PeoplePaneState();
}

class _PeoplePaneState extends ConsumerState<PeoplePane> {
  final _sortMenuFocus = FocusNode();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _listScrollController = ScrollController();
  final Set<String> _relationships = <String>{};
  PeopleListSort _sort = PeopleListSort.lastMentionDate;
  bool _selectionMode = false;
  final Set<PersonId> _selectedPeople = <PersonId>{};
  bool _deletingPeople = false;

  @override
  void dispose() {
    _sortMenuFocus.dispose();
    _searchCtrl.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _clearSelection() {
    _selectionMode = false;
    _selectedPeople.clear();
  }

  void _clearSearch() {
    setState(() {
      _searchCtrl.clear();
      _relationships.clear();
    });
  }

  void _togglePersonSelection(PersonId id) {
    if (_deletingPeople) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _selectionMode = true;
      if (!_selectedPeople.remove(id)) {
        _selectedPeople.add(id);
      }
    });
  }

  void _onPersonTap(PersonId id) {
    if (_deletingPeople) return;
    if (_selectionMode) {
      _togglePersonSelection(id);
      return;
    }
    unawaited(context.push(AppRoutes.personDetailLocation(id)));
  }

  List<PersonListItem> _visibleItems(
    PeopleCatalog catalog,
    Map<PersonId, PersonMentionStats> statsMap,
    bool statsReady,
  ) {
    return filterPeopleListItems(
      items: buildPeopleListItems(
        catalog: catalog.people,
        statsMap: statsMap,
        statsReady: statsReady,
      ),
      query: _searchCtrl.text,
      relationships: _relationships,
      sort: _sort,
    );
  }

  Future<void> _deleteSelectedPeople(List<PersonId> ids) async {
    final UnlockedVaultSession? session = widget.sessionState.session;
    if (ids.isEmpty || _deletingPeople || session == null) return;
    final bool confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.peopleDeleteSelectedConfirmTitle,
      content: Text(context.l10n.peopleDeleteSelectedConfirmBody(ids.length)),
      cancelLabel: context.l10n.commonActionCancel,
      confirmLabel: context.l10n.commonActionDelete,
      confirmStyle: AppConfirmStyle.destructive,
    );
    if (!confirmed || !mounted) return;

    setState(() => _deletingPeople = true);
    final Set<PersonId> deleted = <PersonId>{};
    Object? failure;
    try {
      for (final PersonId id in ids) {
        await deletePersonWithPersona(ref, session, id);
        deleted.add(id);
      }
    } on Object catch (error) {
      failure = error;
    }
    if (!mounted) return;
    setState(() {
      _deletingPeople = false;
      _selectedPeople.removeAll(deleted);
      if (failure == null) _clearSelection();
    });
    if (failure == null) {
      showAppFeedbackToast(
        context,
        context.l10n.peopleDeletedSelected(deleted.length),
        tone: AppFeedbackTone.success,
      );
    } else {
      showAppFeedbackToast(
        context,
        context.l10n.peopleDeleteSelectedPartial(
          deleted.length,
          ids.length - deleted.length,
          userFacingErrorMessage(failure, l10n: context.l10n),
        ),
        tone: AppFeedbackTone.error,
      );
    }
  }

  void _pruneStaleRelationshipFilters(Iterable<RelationshipType> types) {
    final Set<String> typeIds = <String>{
      for (final RelationshipType type in types) type.id,
    };
    if (!_relationships.any((String id) => !typeIds.contains(id))) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _relationships.removeWhere((String id) => !typeIds.contains(id));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeTabProvider, (_, next) {
      if (next != HomeTab.people && _selectionMode) {
        setState(_clearSelection);
      }
    });
    if (!widget.sessionState.isUnlocked ||
        widget.sessionState.session == null) {
      return HomeBlockedEntriesPane(sessionState: widget.sessionState);
    }

    // 名冊優先；統計另載（過期會自動 rebuild）。重載時保留上一份，避免提及數閃 0。
    final AsyncValue<PeopleCatalog> catalogAsync = ref.watch(
      peopleCatalogProvider,
    );
    final List<RelationshipType> relationshipTypes =
        catalogAsync.asData?.value.relationshipTypes ??
        const <RelationshipType>[];
    _pruneStaleRelationshipFilters(relationshipTypes);
    final AsyncValue<Map<PersonId, PersonMentionStats>> statsAsync = ref.watch(
      peopleMentionStatsMapProvider,
    );
    final Map<PersonId, PersonMentionStats> statsMap = statsAsync.hasValue
        ? statsAsync.requireValue
        : const <PersonId, PersonMentionStats>{};
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String languageCode = Localizations.localeOf(context).languageCode;
    final PeopleCatalog? loadedCatalog = catalogAsync.asData?.value;
    final List<PersonListItem> visibleItems = loadedCatalog == null
        ? const <PersonListItem>[]
        : _visibleItems(loadedCatalog, statsMap, statsAsync.hasValue);
    final List<PersonListItem> selectedItems = visibleItems
        .where(
          (PersonListItem item) => _selectedPeople.contains(item.person.id),
        )
        .toList();

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop && _selectionMode && !_deletingPeople) {
          setState(_clearSelection);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_selectionMode)
            HomeScrollbarGutter(
              child: HomeSelectionToolbar(
                selectedCount: selectedItems.length,
                allSelected:
                    visibleItems.isNotEmpty &&
                    selectedItems.length == visibleItems.length,
                enabled: !_deletingPeople,
                onCancel: () => setState(_clearSelection),
                onSelectAll: () => setState(() {
                  if (selectedItems.length == visibleItems.length) {
                    _selectedPeople.clear();
                  } else {
                    _selectedPeople
                      ..clear()
                      ..addAll(visibleItems.map((item) => item.person.id));
                  }
                }),
                actions: <HomeSelectionAction>[
                  HomeSelectionAction(
                    tooltip: context.l10n.commonActionDelete,
                    icon: Icons.delete_outline_rounded,
                    destructive: true,
                    enabled: selectedItems.isNotEmpty,
                    iconWidget: _deletingPeople
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onPressed: () => unawaited(
                      _deleteSelectedPeople(
                        selectedItems.map((item) => item.person.id).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            HomeScrollbarGutter(
              child: SizedBox(
                height: HomeLayout.searchRowControlHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: HomeSearchTextField(
                        controller: _searchCtrl,
                        hintText: context.l10n.peopleSearchHint,
                        onChanged: (_) => setState(() {}),
                        onClear: _clearSearch,
                        clearFiltersTooltip: _relationships.isEmpty
                            ? null
                            : context.l10n.peopleClearSearchAndFilters,
                      ),
                    ),
                    const SizedBox(width: 8),
                    MenuAnchor(
                      onOpen: _sortMenuFocus.requestFocus,
                      style: appMenuStyle(
                        context,
                        width: (MediaQuery.sizeOf(context).width - 48).clamp(
                          0,
                          280,
                        ),
                      ),
                      menuChildren: [
                        for (final (value, label) in [
                          (
                            PeopleListSort.lastMentionDate,
                            context.l10n.peopleSortLastMentionDate,
                          ),
                          (
                            PeopleListSort.mentionedEntryCount,
                            context.l10n.peopleSortMentionedEntries,
                          ),
                          (
                            PeopleListSort.recentMentionedEntryCount,
                            context.l10n.peopleSortRecentMentionedEntries,
                          ),
                          (PeopleListSort.name, context.l10n.peopleSortName),
                        ])
                          MenuItemButton(
                            focusNode: value == _sort ? _sortMenuFocus : null,
                            overflowAxis: Axis.vertical,
                            style: appMenuItemStyle(
                              context,
                              selected: value == _sort,
                            ),
                            trailingIcon: value == _sort
                                ? const Icon(Icons.check, size: 18)
                                : null,
                            onPressed: () => setState(() => _sort = value),
                            child: Text(label),
                          ),
                      ],
                      builder: (context, controller, child) =>
                          HomeCircleIconButton(
                            tooltip: context.l10n.peopleSortTooltip,
                            onPressed: () {
                              if (controller.isOpen) {
                                controller.close();
                              } else {
                                controller.open();
                              }
                            },
                            icon: Icons.sort_rounded,
                            size: HomeLayout.searchRowControlHeight,
                            backgroundColor: cs.secondaryContainer,
                            foregroundColor: cs.onSecondaryContainer,
                          ),
                    ),
                    const SizedBox(width: 6),
                    HomeCircleIconButton(
                      tooltip: context.l10n.peopleManageRelationshipsTooltip,
                      onPressed: () =>
                          unawaited(showRelationshipTypesManageDialog(context)),
                      icon: kPeopleRelationshipsIcon,
                      size: HomeLayout.searchRowControlHeight,
                      backgroundColor: cs.secondaryContainer,
                      foregroundColor: cs.onSecondaryContainer,
                    ),
                    const SizedBox(width: 6),
                    HomeCircleIconButton(
                      tooltip: context.l10n.peopleCreateAction,
                      onPressed: () =>
                          unawaited(showPersonComposerDialog(context)),
                      icon: Icons.person_add_alt_1_rounded,
                      size: HomeLayout.searchRowControlHeight,
                      backgroundColor: cs.primaryContainer,
                      foregroundColor: cs.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(right: HomeLayout.bodyPadding.right),
              children: <Widget>[
                for (final RelationshipType type in relationshipTypes)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(relationshipTypeLabel(type, languageCode)),
                      selected: _relationships.contains(type.id),
                      showCheckmark: false,
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _relationships.add(type.id);
                          } else {
                            _relationships.remove(type.id);
                          }
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (statsAsync.hasError) ...<Widget>[
            HomeScrollbarGutter(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      userFacingErrorMessage(
                        statsAsync.error!,
                        l10n: context.l10n,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: cs.error),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(peopleMentionStatsMapProvider),
                    child: Text(context.l10n.peopleAnalysisRetry),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ] else ...<Widget>[const _PeopleAnalysisProgress()],
          Expanded(
            child: catalogAsync.when(
              skipLoadingOnReload: true,
              loading: () => const AppLoadingState(),
              error: (Object error, StackTrace _) => HomeScrollbarGutter(
                child: AppStateCard(
                  icon: Icons.error_outline_rounded,
                  title: context.l10n.commonReadFailureTitle,
                  message: userFacingErrorMessage(error, l10n: context.l10n),
                ),
              ),
              data: (PeopleCatalog catalog) {
                if (visibleItems.isEmpty) {
                  final bool catalogEmpty = catalog.people.isEmpty;
                  return HomeScrollbarGutter(
                    child: catalogEmpty
                        ? AppStateCard(
                            icon: Icons.people_outline_rounded,
                            title: context.l10n.peopleEmptyTitle,
                            message: context.l10n.peopleEmptyBody,
                            actionLabel: context.l10n.peopleCreateAction,
                            actionIcon: Icons.person_add_alt_1_rounded,
                            onAction: () =>
                                unawaited(showPersonComposerDialog(context)),
                          )
                        : AppStateCard(
                            icon: Icons.search_off_rounded,
                            title: context.l10n.peopleSearchNoResultsTitle,
                            message: context.l10n.peopleSearchNoResultsMessage,
                            actionLabel: _relationships.isEmpty
                                ? context.l10n.commonClearSearchTooltip
                                : context.l10n.peopleClearSearchAndFilters,
                            actionIcon: Icons.close_rounded,
                            onAction: _clearSearch,
                          ),
                  );
                }
                return HomeScrollAffordance(
                  controller: _listScrollController,
                  child: NotificationListener<OverscrollIndicatorNotification>(
                    onNotification:
                        (OverscrollIndicatorNotification notification) {
                          notification.disallowIndicator();
                          return false;
                        },
                    child: ListView.builder(
                      controller: _listScrollController,
                      physics: appBouncingScrollPhysics,
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: visibleItems.length + 1,
                      itemBuilder: (BuildContext context, int index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                            child: Row(
                              children: <Widget>[
                                Text(
                                  context.l10n.homeNavPeople,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const Spacer(),
                                Text(
                                  '${visibleItems.length}',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          );
                        }
                        final PersonListItem item = visibleItems[index - 1];
                        final PersonId personId = item.person.id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: _PersonListTile(
                            item: item,
                            relationshipTypes: catalog.relationshipTypes,
                            selectionMode: _selectionMode,
                            selected: _selectedPeople.contains(personId),
                            onTap: () => _onPersonTap(personId),
                            onLongPress: () => _togglePersonSelection(personId),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleAnalysisProgress extends ConsumerWidget {
  const _PeopleAnalysisProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PeopleAnalyticsProgress? progress = ref
        .watch(peopleAnalyticsProgressProvider)
        .asData
        ?.value;
    if (progress?.state != PeopleAnalyticsProgressState.analyzing) {
      return const SizedBox.shrink();
    }
    final String label =
        progress!.phase == PeopleAnalyticsProgressPhase.preparingIndex
        ? context.l10n.peopleIndexPreparationProgress(
            progress.processedDocuments,
            progress.totalDocuments,
          )
        : context.l10n.peopleAnalysisProgress(
            progress.processedDocuments,
            progress.totalDocuments,
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HomeScrollbarGutter(
        child: AppProgressPanel(
          label: label,
          value: progress.totalDocuments == 0
              ? null
              : progress.processedDocuments / progress.totalDocuments,
        ),
      ),
    );
  }
}

class _PersonListTile extends StatelessWidget {
  const _PersonListTile({
    required this.item,
    required this.relationshipTypes,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final PersonListItem item;
  final List<RelationshipType> relationshipTypes;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final Person person = item.person;
    final PersonMentionStats? stats = item.stats;
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final avatarColors = personLabelColors(
      person,
      context.appColors.sectionInset,
    );
    final TextStyle? metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );
    final String languageCode = Localizations.localeOf(context).languageCode;
    final String relations = relationshipTypes
        .where(
          (RelationshipType type) => person.relationships.contains(type.id),
        )
        .map(
          (RelationshipType type) => relationshipTypeLabel(type, languageCode),
        )
        .join(' · ');
    final String? subtitle = stats == null
        ? null
        : <String>[
            context.l10n.peopleMentionedEntryCount(stats.mentionedEntryCount),
            stats.lastMentionDate == null
                ? context.l10n.peopleLastMentionNever
                : context.l10n.peopleLastMentionDate(
                    DisplayFormat.formatRelativeDayDistance(
                      context.l10n,
                      stats.lastMentionDate!,
                    ),
                  ),
          ].join(context.l10n.commonListSeparator);

    return Material(
      color: context.appColors.sectionInset,
      elevation: 0,
      borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: ValueKey<String>('person-row-${person.id}'),
        dense: true,
        minVerticalPadding: 0,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
          side: selected
              ? BorderSide(
                  color: context.appColors.selectedRowBorder,
                  width: 1.4,
                )
              : BorderSide.none,
        ),
        selected: selected,
        selectedColor: cs.onSurface,
        selectedTileColor: context.appColors.selectedRowFill,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (selectionMode) ...<Widget>[
              HomeSelectionIndicator(selected: selected),
              const SizedBox(width: 10),
            ],
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatarColors.background,
              ),
              alignment: Alignment.center,
              child: Text(
                personInitials(person.name),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: avatarColors.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: <Widget>[
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (relations.isNotEmpty) ...<Widget>[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        relations,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: metaStyle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              personFriendlinessLabel(context.l10n, person.friendliness.value),
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: metaStyle,
              ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
