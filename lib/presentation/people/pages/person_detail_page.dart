import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/widgets/home_shared_widgets.dart';
import 'package:quill_diary/presentation/people/widgets/person_composer_dialog.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/people_labels.dart';
import 'package:quill_diary/shared/presentation/person_visual.dart';
import 'package:quill_diary/shared/utils/user_facing_error.dart';

class PersonDetailPage extends ConsumerWidget {
  const PersonDetailPage({required this.personId, super.key});

  final PersonId personId;

  Future<void> _edit(BuildContext context) async {
    await showPersonComposerDialog(context, personId: personId);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(ctx.l10n.peopleDeleteConfirmTitle),
        content: Text(ctx.l10n.peopleDeleteConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.commonActionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.commonActionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final AppSessionState state = await ref.read(
      effectiveAppSessionProvider.future,
    );
    final session = state.session;
    if (!state.isUnlocked || session == null) {
      return;
    }
    try {
      await ref
          .read(vaultPeopleServiceProvider)
          .deletePerson(session, personId);
      ref.invalidate(peopleCatalogProvider);
      if (context.mounted) {
        context.pop();
      }
    } on Object catch (error) {
      if (context.mounted) {
        showAppFeedbackSnackBar(
          context,
          context.l10n.peopleDeleteFailure(
            userFacingErrorMessage(error, l10n: context.l10n),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Person?> personAsync = ref.watch(
      personDetailProvider(personId),
    );
    final AsyncValue<List<EntryIndexRecord>> relatedAsync = ref.watch(
      personRelatedEntriesProvider(personId),
    );
    final AsyncValue<Map<PersonId, PersonMentionStats>> statsAsync = ref.watch(
      peopleMentionStatsMapProvider,
    );
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      body: personAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => Center(
          child: Text(userFacingErrorMessage(error, l10n: context.l10n)),
        ),
        data: (Person? person) {
          if (person == null) {
            return SafeArea(
              child: Center(child: Text(context.l10n.peopleEmptyTitle)),
            );
          }
          final Color accent = personAccentColor(person);
          final PersonMentionStats? stats = statsAsync.asData?.value[person.id];
          final List<Widget> summaryItems = <Widget>[
            if (stats != null) ...<Widget>[
              _PersonFactChip(
                key: const ValueKey<String>('person-last-mention-fact'),
                icon: Icons.history_rounded,
                label: context.l10n.peopleLastMentionLabel,
                value: stats.lastMentionDate == null
                    ? context.l10n.peopleLastMentionNever
                    : DisplayFormat.formatRelativeDayDistance(
                        context.l10n,
                        stats.lastMentionDate!,
                      ),
              ),
              _PersonFactChip(
                icon: Icons.date_range_outlined,
                label: context.l10n.peopleRecentMentionsLabel,
                value: context.l10n.peopleMentionEntriesValue(
                  stats.recentMentionCount,
                ),
              ),
              _PersonFactChip(
                icon: Icons.menu_book_outlined,
                label: context.l10n.peopleTotalMentionsLabel,
                value: context.l10n.peopleMentionEntriesValue(
                  stats.mentionCount,
                ),
              ),
            ],
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: context.l10n.commonCloseTooltip,
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.close_rounded, size: 26),
                      ),
                      Expanded(
                        child: Text(
                          context.l10n.peopleDetailTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.peopleEditTitle,
                        onPressed: () => unawaited(_edit(context)),
                        color: cs.primary,
                        icon: const Icon(Icons.edit_outlined, size: 26),
                      ),
                      IconButton(
                        tooltip: context.l10n.peopleDeleteAction,
                        onPressed: () => unawaited(_delete(context, ref)),
                        color: cs.error,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AppScrollbar(
                  child: CustomScrollView(
                    slivers: <Widget>[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        sliver: SliverMainAxisGroup(
                          slivers: <Widget>[
                            SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: <Widget>[
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor:
                                            personAvatarBackgroundColor(
                                              person,
                                              context.appColors.sectionInset,
                                            ),
                                        foregroundColor: accent,
                                        child: Text(
                                          personInitials(person.name),
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                color: accent,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              person.name,
                                              style: theme
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                    height: 1.2,
                                                  ),
                                            ),
                                            if (person
                                                .aliases
                                                .isNotEmpty) ...<Widget>[
                                              const SizedBox(height: 4),
                                              Text(
                                                person.aliases.join('、'),
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color:
                                                          cs.onSurfaceVariant,
                                                      height: 1.35,
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (summaryItems.isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 14),
                                    _PersonDetailSectionCard(
                                      key: const ValueKey<String>(
                                        'person-mention-overview-card',
                                      ),
                                      title: context
                                          .l10n
                                          .peopleMentionOverviewTitle,
                                      child: SizedBox(
                                        height: 64,
                                        child: ListView.separated(
                                          key: const ValueKey<String>(
                                            'person-summary-strip',
                                          ),
                                          scrollDirection: Axis.horizontal,
                                          itemCount: summaryItems.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(width: 8),
                                          itemBuilder:
                                              (
                                                BuildContext context,
                                                int index,
                                              ) => summaryItems[index],
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  _PersonProfileBodyCard(person: person),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                            relatedAsync.when<Widget>(
                              loading: () => SliverToBoxAdapter(
                                child: HomeSectionCard(
                                  title: context.l10n.peopleRelatedEntriesTitle,
                                  stripeColor: cs.primary,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                ),
                              ),
                              error: (Object error, StackTrace _) =>
                                  SliverToBoxAdapter(
                                    child: HomeSectionCard(
                                      title: context
                                          .l10n
                                          .peopleRelatedEntriesTitle,
                                      stripeColor: cs.primary,
                                      child: Text(
                                        userFacingErrorMessage(
                                          error,
                                          l10n: context.l10n,
                                        ),
                                      ),
                                    ),
                                  ),
                              data: (List<EntryIndexRecord> entries) {
                                if (entries.isEmpty) {
                                  return SliverToBoxAdapter(
                                    child: HomeSectionCard(
                                      title: context
                                          .l10n
                                          .peopleRelatedEntriesTitle,
                                      stripeColor: cs.primary,
                                      child: HomePaneEmptyHint(
                                        text: context
                                            .l10n
                                            .peopleRelatedEntriesEmpty,
                                      ),
                                    ),
                                  );
                                }
                                return HomeDiarySliverSection(
                                  title: context.l10n.peopleRelatedEntriesTitle,
                                  stripeColor: cs.primary,
                                  entries: entries,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PersonRelationChip extends StatelessWidget {
  const _PersonRelationChip({
    required this.label,
    required this.colors,
    super.key,
  });

  final String label;
  final (Color, Color) colors;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: colors.$2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PersonDetailSectionCard extends StatelessWidget {
  const _PersonDetailSectionCard({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? colors.sectionCard
            : colors.previewPanel,
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
        border: Border.fromBorderSide(colors.outlineBorder()),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// 對齊日記 preview 的白底內容卡。
class _PersonProfileBodyCard extends StatelessWidget {
  const _PersonProfileBodyCard({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;
    final (Color, Color) personColors = personLabelColorPair(
      person,
      context.appColors.sectionInset,
    );

    return _PersonDetailSectionCard(
      key: const ValueKey<String>('person-profile-details-card'),
      title: l10n.peopleProfileDetailsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 64,
            child: ListView.separated(
              key: const ValueKey<String>('person-profile-facts-strip'),
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int index) => switch (index) {
                0 => _PersonFactChip(
                  key: const ValueKey<String>('person-friendliness-fact'),
                  icon: Icons.favorite_outline_rounded,
                  label: l10n.peopleFieldFriendliness,
                  value: personFriendlinessLabel(
                    l10n,
                    person.friendliness.value,
                  ),
                ),
                1 => _PersonFactChip(
                  icon: Icons.history_rounded,
                  label: l10n.peopleFieldAcquaintanceYear,
                  value: person.acquaintanceYear == null
                      ? l10n.peopleNoValue
                      : DisplayFormat.formatYear(
                          l10n,
                          person.acquaintanceYear!,
                        ),
                ),
                _ => _PersonFactChip(
                  icon: Icons.cake_outlined,
                  label: l10n.peopleFieldBirthday,
                  value: person.birthday == null
                      ? l10n.peopleNoValue
                      : DisplayFormat.formatBirthday(
                          l10n,
                          month: person.birthday!.month,
                          day: person.birthday!.day,
                        ),
                ),
              },
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.peopleFieldRelationships,
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (person.relationships.isEmpty)
            Text(
              l10n.peopleNoValue,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final PersonRelationship relationship
                    in PersonRelationship.values)
                  if (person.relationships.contains(relationship))
                    _PersonRelationChip(
                      key: ValueKey<String>(
                        'person-relation-chip-${relationship.name}',
                      ),
                      label: personRelationshipLabel(l10n, relationship),
                      colors: personColors,
                    ),
              ],
            ),
          const SizedBox(height: 16),
          _PersonTextFact(
            label: l10n.peopleFieldRelationshipDescription,
            value: person.relationshipDescription,
            emptyValue: l10n.peopleNoValue,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          _PersonTextFact(
            label: l10n.peopleFieldNotes,
            value: person.notes,
            emptyValue: l10n.peopleNoValue,
          ),
        ],
      ),
    );
  }
}

class _PersonTextFact extends StatelessWidget {
  const _PersonTextFact({
    required this.label,
    required this.value,
    required this.emptyValue,
  });

  final String label;
  final String value;
  final String emptyValue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String displayValue = value.trim().isEmpty ? emptyValue : value;
    final bool isEmpty = value.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          displayValue,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isEmpty ? cs.onSurfaceVariant : cs.onSurface,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _PersonFactChip extends StatelessWidget {
  const _PersonFactChip({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors colors = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? colors.sectionInset
            : cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
