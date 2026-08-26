import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/app/router.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/people/widgets/person_composer_dialog.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/widgets/app_progress.dart';
import 'package:quill_diary/shared/presentation/widgets/app_loading_state.dart';
import 'package:quill_diary/shared/presentation/widgets/app_state_card.dart';
import 'package:quill_diary/shared/presentation/people_labels.dart';
import 'package:quill_diary/shared/presentation/person_visual.dart';
import 'package:quill_diary/shared/utils/user_facing_error.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import '../home_layout.dart';
import 'home_scroll_affordance.dart';
import 'home_selection_toolbar.dart';
import 'home_shared_widgets.dart';

/// 人物分頁；首次開啟後保留名冊、統計與畫面狀態。
class PeoplePane extends ConsumerStatefulWidget {
  const PeoplePane({required this.sessionState, super.key});

  final AppSessionState sessionState;

  @override
  ConsumerState<PeoplePane> createState() => _PeoplePaneState();
}

class _PeoplePaneState extends ConsumerState<PeoplePane> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _listScrollController = ScrollController();
  final Set<PersonRelationship> _relationships = <PersonRelationship>{};
  PeopleListSort _sort = PeopleListSort.lastMention;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.sessionState.isUnlocked ||
        widget.sessionState.session == null) {
      return HomeBlockedEntriesPane(sessionState: widget.sessionState);
    }

    // 名冊優先；統計另載（過期會自動 rebuild）。重載時保留上一份，避免提及數閃 0。
    final AsyncValue<List<Person>> catalogAsync = ref.watch(
      peopleCatalogProvider,
    );
    final AsyncValue<Map<PersonId, PersonMentionStats>> statsAsync = ref.watch(
      peopleMentionStatsMapProvider,
    );
    final Map<PersonId, PersonMentionStats> statsMap = statsAsync.hasValue
        ? statsAsync.requireValue
        : const <PersonId, PersonMentionStats>{};
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HomeScrollbarGutter(
          child: SizedBox(
            height: kHomeSearchRowControlHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: HomeSearchTextField(
                    controller: _searchCtrl,
                    hintText: context.l10n.peopleSearchHint,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<PeopleListSort>(
                  initialValue: _sort,
                  tooltip: context.l10n.peopleSortTooltip,
                  onSelected: (PeopleListSort value) {
                    setState(() => _sort = value);
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<PeopleListSort>>[
                        PopupMenuItem(
                          value: PeopleListSort.lastMention,
                          child: Text(context.l10n.peopleSortLastMention),
                        ),
                        PopupMenuItem(
                          value: PeopleListSort.totalMentions,
                          child: Text(context.l10n.peopleSortTotalMentions),
                        ),
                        PopupMenuItem(
                          value: PeopleListSort.recentMentions,
                          child: Text(context.l10n.peopleSortRecentMentions),
                        ),
                        PopupMenuItem(
                          value: PeopleListSort.name,
                          child: Text(context.l10n.peopleSortName),
                        ),
                      ],
                  child: IgnorePointer(
                    child: HomeCircleIconButton(
                      tooltip: context.l10n.peopleSortTooltip,
                      onPressed: () {},
                      icon: Icons.sort_rounded,
                      size: kHomeSearchRowControlHeight,
                      backgroundColor: cs.secondaryContainer,
                      foregroundColor: cs.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                HomeCircleIconButton(
                  tooltip: context.l10n.peopleCreateAction,
                  onPressed: () => unawaited(showPersonComposerDialog(context)),
                  icon: Icons.person_add_alt_1_rounded,
                  size: kHomeSearchRowControlHeight,
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
              for (final PersonRelationship rel in PersonRelationship.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(personRelationshipLabel(context.l10n, rel)),
                    selected: _relationships.contains(rel),
                    showCheckmark: false,
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _relationships.add(rel);
                        } else {
                          _relationships.remove(rel);
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
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.error),
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
            data: (List<Person> catalog) {
              final List<PersonListItem> items = filterPeopleListItems(
                items: buildPeopleListItems(
                  catalog: catalog,
                  statsMap: statsMap,
                  statsReady: statsAsync.hasValue,
                ),
                query: _searchCtrl.text,
                relationships: _relationships,
                sort: _sort,
              );
              if (items.isEmpty) {
                final bool catalogEmpty = catalog.isEmpty;
                return HomeScrollbarGutter(
                  child: catalogEmpty
                      ? AppStateCard(
                          icon: Icons.people_outline_rounded,
                          title: context.l10n.peopleEmptyTitle,
                          message: context.l10n.peopleEmptyBody,
                          actionLabel: context.l10n.peopleCreateAction,
                          actionIcon: Icons.person_add_alt_1_rounded,
                          onAction: () => unawaited(
                            showPersonComposerDialog(context),
                          ),
                        )
                      : HomeSectionCard(
                          title: context.l10n.peopleSearchNoResultsTitle,
                          stripeColor: cs.primary,
                          child: HomePaneEmptyHint(
                            text: context.l10n.peopleSearchNoResultsMessage,
                          ),
                        ),
                );
              }
              return AppScrollbar(
                controller: _listScrollController,
                child: HomeScrollbarGutter(
                  child: ListView.builder(
                    controller: _listScrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: items.length + 1,
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
                                '${items.length}',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        );
                      }
                      final PersonListItem item = items[index - 1];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: _PersonListTile(
                          item: item,
                          onTap: () => unawaited(
                            context.push(
                              AppRouter.personDetailLocation(item.person.id),
                            ),
                          ),
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
  const _PersonListTile({required this.item, required this.onTap});

  final PersonListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Person person = item.person;
    final PersonMentionStats? stats = item.stats;
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color accent = personAccentColor(person);
    final String lastMention = stats?.lastMentionDate == null
        ? context.l10n.peopleLastMentionNever
        : context.l10n.peopleLastMention(
            DisplayFormat.formatRelativeDayDistance(
              context.l10n,
              stats!.lastMentionDate!,
            ),
          );
    final String relations = PersonRelationship.values
        .where(person.relationships.contains)
        .map(
          (PersonRelationship relationship) =>
              personRelationshipLabel(context.l10n, relationship),
        )
        .join(' · ');

    return Material(
      color: context.appColors.sectionInset,
      elevation: 0,
      borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        minVerticalPadding: 0,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: personAvatarBackgroundColor(
              person,
              context.appColors.sectionInset,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            personInitials(person.name),
            style: theme.textTheme.titleSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              personFriendlinessLabel(context.l10n, person.friendliness.value),
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        subtitle: stats == null && relations.isEmpty
            ? null
            : Text(
                stats == null
                    ? relations
                    : <String>[
                        if (relations.isNotEmpty) relations,
                        context.l10n.peopleMentionCount(stats.mentionCount),
                        lastMention,
                      ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}
