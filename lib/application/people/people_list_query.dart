import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

enum PeopleListSort {
  lastMentionDate,
  mentionedEntryCount,
  recentMentionedEntryCount,
  name,
}

final class PersonListItem {
  const PersonListItem({required this.person, required this.stats});

  final Person person;
  final PersonMentionStats? stats;
}

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
                    mentionedEntryCount: 0,
                    recentMentionedEntryCount: 0,
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
  final String normalizedQuery = normalizePersonName(query);
  final List<PersonListItem> filtered = <PersonListItem>[];
  for (final PersonListItem item in items) {
    final Person person = item.person;
    if (relationships.isNotEmpty &&
        person.relationships.intersection(relationships).isEmpty) {
      continue;
    }
    if (normalizedQuery.isNotEmpty &&
        !person.normalizedName.contains(normalizedQuery) &&
        !person.normalizedAliases.any(
          (String alias) => alias.contains(normalizedQuery),
        )) {
      continue;
    }
    filtered.add(item);
  }

  filtered.sort((PersonListItem a, PersonListItem b) {
    switch (sort) {
      case PeopleListSort.lastMentionDate:
        final int byDate = _compareNullableDate(
          a.stats?.lastMentionDate,
          b.stats?.lastMentionDate,
        );
        return byDate != 0 ? byDate : _compareNames(a.person, b.person);
      case PeopleListSort.mentionedEntryCount:
        final int byCount = (b.stats?.mentionedEntryCount ?? 0).compareTo(
          a.stats?.mentionedEntryCount ?? 0,
        );
        return byCount != 0 ? byCount : _compareNames(a.person, b.person);
      case PeopleListSort.recentMentionedEntryCount:
        final int byRecent = (b.stats?.recentMentionedEntryCount ?? 0)
            .compareTo(a.stats?.recentMentionedEntryCount ?? 0);
        return byRecent != 0 ? byRecent : _compareNames(a.person, b.person);
      case PeopleListSort.name:
        return _compareNames(a.person, b.person);
    }
  });
  return filtered;
}

int _compareNullableDate(DateOnly? a, DateOnly? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.value.compareTo(a.value);
}

int _compareNames(Person a, Person b) {
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}
