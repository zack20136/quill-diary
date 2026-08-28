import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/editor/editor_entry_providers.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/relationship_type.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

/// 讀取已快取的名冊（含關係類型）；人物／類型 CRUD 會 invalidate。
final peopleCatalogProvider = FutureProvider.autoDispose<PeopleCatalog>((
  Ref ref,
) async {
  final AppSessionState state = await ref.watch(
    effectiveAppSessionProvider.future,
  );
  if (!state.isUnlocked || state.session == null) {
    return PeopleCatalog.empty();
  }
  return ref.watch(vaultPeopleServiceProvider).readPeopleCatalog(state.session!);
});

/// 名冊中的人物列表（與 [peopleCatalogProvider] 同源）。
final peopleListProvider = Provider.autoDispose<AsyncValue<List<Person>>>((
  Ref ref,
) {
  return ref.watch(peopleCatalogProvider).whenData(
    (PeopleCatalog catalog) => catalog.people,
  );
});

/// 現行關係類型表（與 [peopleCatalogProvider] 同源）。
final peopleRelationshipTypesProvider =
    Provider.autoDispose<AsyncValue<List<RelationshipType>>>((Ref ref) {
      return ref.watch(peopleCatalogProvider).whenData(
        (PeopleCatalog catalog) => catalog.relationshipTypes,
      );
    });

enum PeopleListSort { lastMention, totalMentions, recentMentions, name }

final class PersonListItem {
  const PersonListItem({required this.person, required this.stats});

  final Person person;
  final PersonMentionStats? stats;
}

/// 提及統計 map；過期時會自動 ensure／rebuild。
final peopleMentionStatsMapProvider =
    FutureProvider.autoDispose<Map<PersonId, PersonMentionStats>>((
      Ref ref,
    ) async {
      ref.watch(entryIndexRevisionProvider);
      await ref.watch(peopleCatalogProvider.future);
      final AppSessionState state = await ref.watch(
        effectiveAppSessionProvider.future,
      );
      if (!state.isUnlocked || state.session == null) {
        return const <PersonId, PersonMentionStats>{};
      }
      return ref
          .watch(vaultPeopleServiceProvider)
          .allPersonMentionStats(state.session!);
    });

List<PersonListItem> buildPeopleListItems({
  required List<Person> catalog,
  required Map<PersonId, PersonMentionStats> statsMap,
  bool statsReady = true,
}) {
  return <PersonListItem>[
    for (final Person person in catalog)
      PersonListItem(
        person: person,
        stats:
            statsMap[person.id] ??
            (statsReady
                ? PersonMentionStats(
                    personId: person.id,
                    mentionCount: 0,
                    recentMentionCount: 0,
                  )
                : null),
      ),
  ];
}

List<PersonListItem> filterPeopleListItems({
  required List<PersonListItem> items,
  required String query,
  required Set<String> relationships,
  required PeopleListSort sort,
}) {
  final String q = normalizePersonName(query);
  final List<PersonListItem> filtered = <PersonListItem>[];
  for (final PersonListItem item in items) {
    final Person person = item.person;
    if (relationships.isNotEmpty &&
        person.relationships.intersection(relationships).isEmpty) {
      continue;
    }
    if (q.isNotEmpty) {
      final bool nameHit = person.normalizedName.contains(q);
      final bool aliasHit = person.normalizedAliases.any(
        (String a) => a.contains(q),
      );
      if (!nameHit && !aliasHit) {
        continue;
      }
    }
    filtered.add(item);
  }

  int compareNullableDate(DateOnly? a, DateOnly? b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return 1;
    }
    if (b == null) {
      return -1;
    }
    return b.value.compareTo(a.value);
  }

  filtered.sort((PersonListItem a, PersonListItem b) {
    switch (sort) {
      case PeopleListSort.lastMention:
        final int byDate = compareNullableDate(
          a.stats?.lastMentionDate,
          b.stats?.lastMentionDate,
        );
        if (byDate != 0) {
          return byDate;
        }
        return a.person.name.toLowerCase().compareTo(
          b.person.name.toLowerCase(),
        );
      case PeopleListSort.totalMentions:
        final int byCount = (b.stats?.mentionCount ?? 0).compareTo(
          a.stats?.mentionCount ?? 0,
        );
        if (byCount != 0) {
          return byCount;
        }
        return a.person.name.toLowerCase().compareTo(
          b.person.name.toLowerCase(),
        );
      case PeopleListSort.recentMentions:
        final int byRecent = (b.stats?.recentMentionCount ?? 0).compareTo(
          a.stats?.recentMentionCount ?? 0,
        );
        if (byRecent != 0) {
          return byRecent;
        }
        return a.person.name.toLowerCase().compareTo(
          b.person.name.toLowerCase(),
        );
      case PeopleListSort.name:
        return a.person.name.toLowerCase().compareTo(
          b.person.name.toLowerCase(),
        );
    }
  });
  return filtered;
}

final personDetailProvider = FutureProvider.autoDispose
    .family<Person?, PersonId>((Ref ref, PersonId id) async {
      final PeopleCatalog catalog = await ref.watch(
        peopleCatalogProvider.future,
      );
      for (final Person person in catalog.people) {
        if (person.id == id) {
          return person;
        }
      }
      return null;
    });

final personRelatedEntriesProvider = FutureProvider.autoDispose
    .family<List<EntryIndexRecord>, PersonId>((Ref ref, PersonId id) async {
      ref.watch(entryIndexRevisionProvider);
      await ref.watch(peopleCatalogProvider.future);
      final AppSessionState state = await ref.watch(
        effectiveAppSessionProvider.future,
      );
      if (!state.isUnlocked || state.session == null) {
        return const <EntryIndexRecord>[];
      }
      return ref
          .watch(vaultPeopleServiceProvider)
          .relatedEntriesForPerson(state.session!, id);
    });

final class OverviewPersonRankItem {
  const OverviewPersonRankItem({
    required this.person,
    required this.mentionCount,
    required this.lastMentionDate,
  });

  final Person person;
  final int mentionCount;
  final DateOnly lastMentionDate;
}

final overviewPeopleTop5Provider = FutureProvider.autoDispose
    .family<
      List<OverviewPersonRankItem>,
      ({MemoryScope scope, int focusedYear, int focusedMonth})
    >((
      Ref ref,
      ({MemoryScope scope, int focusedYear, int focusedMonth}) key,
    ) async {
      ref.watch(entryIndexRevisionProvider);
      final AppSessionState state = await ref.watch(
        effectiveAppSessionProvider.future,
      );
      if (!state.isUnlocked || state.session == null) {
        return const <OverviewPersonRankItem>[];
      }

      final PeopleCatalog catalog = await ref.watch(
        peopleCatalogProvider.future,
      );
      if (catalog.people.isEmpty) {
        return const <OverviewPersonRankItem>[];
      }
      final Map<PersonId, Person> byId = <PersonId, Person>{
        for (final Person p in catalog.people) p.id: p,
      };

      String? yearPrefix;
      String? monthPrefix;
      switch (key.scope) {
        case MemoryScope.all:
          break;
        case MemoryScope.year:
          yearPrefix = key.focusedYear.toString().padLeft(4, '0');
        case MemoryScope.month:
          monthPrefix =
              '${key.focusedYear.toString().padLeft(4, '0')}-${key.focusedMonth.toString().padLeft(2, '0')}';
      }

      final List<PersonScopedMentionRank> ranks = await ref
          .watch(vaultPeopleServiceProvider)
          .topMentionedPeople(
            state.session!,
            limit: 5,
            yearPrefix: yearPrefix,
            monthPrefix: monthPrefix,
          );

      final List<OverviewPersonRankItem> items = <OverviewPersonRankItem>[];
      for (final PersonScopedMentionRank rank in ranks) {
        final Person? person = byId[rank.personId];
        if (person == null) {
          continue;
        }
        items.add(
          OverviewPersonRankItem(
            person: person,
            mentionCount: rank.mentionCount,
            lastMentionDate: rank.lastMentionDate,
          ),
        );
      }
      items.sort((OverviewPersonRankItem a, OverviewPersonRankItem b) {
        final int byCount = b.mentionCount.compareTo(a.mentionCount);
        if (byCount != 0) {
          return byCount;
        }
        final int byDate = b.lastMentionDate.value.compareTo(
          a.lastMentionDate.value,
        );
        if (byDate != 0) {
          return byDate;
        }
        return a.person.name.toLowerCase().compareTo(
          b.person.name.toLowerCase(),
        );
      });
      return items.take(5).toList(growable: false);
    });

final peopleAnalyticsProgressProvider =
    StreamProvider.autoDispose<PeopleAnalyticsProgress>((Ref ref) {
      return ref.watch(vaultPeopleServiceProvider).peopleAnalyticsProgress;
    });

final class EditorPersonSuggestion {
  const EditorPersonSuggestion({required this.person, this.matchedAlias});

  final Person person;
  final String? matchedAlias;
}

/// 同步過濾已載入 catalog；勿用 FutureProvider.family 綁 keystroke。
///
/// [mentionCountById] 有值時，優先依提及次數排序（多者在前）。
List<EditorPersonSuggestion> filterEditorPersonSuggestions({
  required List<Person> catalog,
  required String query,
  int limit = 6,
  Map<PersonId, int>? mentionCountById,
}) {
  if (catalog.isEmpty) {
    return const <EditorPersonSuggestion>[];
  }
  final String q = normalizePersonName(query);
  final List<EditorPersonSuggestion> hits = <EditorPersonSuggestion>[];
  for (final Person person in catalog) {
    if (q.isEmpty) {
      hits.add(EditorPersonSuggestion(person: person));
      continue;
    }
    if (person.normalizedName.contains(q)) {
      hits.add(EditorPersonSuggestion(person: person));
      continue;
    }
    String? matchedAlias;
    for (final PersonAliasSearchValue alias in person.aliasSearchValues) {
      if (alias.normalized.contains(q)) {
        matchedAlias = alias.alias;
        break;
      }
    }
    if (matchedAlias != null) {
      hits.add(
        EditorPersonSuggestion(person: person, matchedAlias: matchedAlias),
      );
    }
  }
  hits.sort((EditorPersonSuggestion a, EditorPersonSuggestion b) {
    if (mentionCountById != null) {
      final int byCount = (mentionCountById[b.person.id] ?? 0).compareTo(
        mentionCountById[a.person.id] ?? 0,
      );
      if (byCount != 0) {
        return byCount;
      }
    }
    return a.person.name.toLowerCase().compareTo(b.person.name.toLowerCase());
  });
  return hits.take(limit).toList(growable: false);
}
