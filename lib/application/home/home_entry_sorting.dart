import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/entry_index_sorting.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';

int compareHomeEntriesPinnedFirst(
  EntryIndexRecord a,
  EntryIndexRecord b,
  Set<EntryId> pinnedEntryIds,
) {
  final bool aPinned = pinnedEntryIds.contains(a.id);
  final bool bPinned = pinnedEntryIds.contains(b.id);
  if (aPinned != bPinned) return aPinned ? -1 : 1;
  return compareEntriesNewestFirst(a, b);
}

List<EntryIndexRecord> orderEntriesByFrozenDisplay(
  List<EntryIndexRecord> entries,
  List<EntryId> frozenOrder,
) {
  if (frozenOrder.isEmpty) {
    return List<EntryIndexRecord>.from(entries)
      ..sort(compareEntriesNewestFirst);
  }
  final Map<EntryId, int> indexById = <EntryId, int>{
    for (int index = 0; index < frozenOrder.length; index++)
      frozenOrder[index]: index,
  };
  final List<EntryIndexRecord> known = <EntryIndexRecord>[];
  final List<EntryIndexRecord> unknown = <EntryIndexRecord>[];
  for (final EntryIndexRecord entry in entries) {
    (indexById.containsKey(entry.id) ? known : unknown).add(entry);
  }
  known.sort(
    (EntryIndexRecord a, EntryIndexRecord b) =>
        indexById[a.id]!.compareTo(indexById[b.id]!),
  );
  unknown.sort(compareEntriesNewestFirst);
  return <EntryIndexRecord>[...known, ...unknown];
}

typedef HomeEntrySortState = ({
  bool isActive,
  List<EntryId> frozenDisplayOrder,
});

List<EntryIndexRecord> sortHomeEntries({
  required List<EntryIndexRecord> list,
  required HomeEntrySortState sortState,
  required Set<EntryId> pinnedIds,
}) {
  if (sortState.isActive && sortState.frozenDisplayOrder.isNotEmpty) {
    return orderEntriesByFrozenDisplay(list, sortState.frozenDisplayOrder);
  }
  return List<EntryIndexRecord>.from(list)..sort(
    (EntryIndexRecord a, EntryIndexRecord b) =>
        compareHomeEntriesPinnedFirst(a, b, pinnedIds),
  );
}

List<EntryId> homeEntryDisplayOrder({
  required List<EntryIndexRecord> entries,
  required Set<EntryId> pinnedIds,
}) => sortHomeEntries(
  list: entries,
  sortState: (isActive: false, frozenDisplayOrder: const <EntryId>[]),
  pinnedIds: pinnedIds,
).map((EntryIndexRecord item) => item.id).toList(growable: false);
