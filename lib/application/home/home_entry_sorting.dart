import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/entry_index_sorting.dart';

int compareHomeEntriesPinnedFirst(
  DiaryEntrySummary a,
  DiaryEntrySummary b,
  Set<EntryId> pinnedEntryIds,
) {
  final bool aPinned = pinnedEntryIds.contains(a.id);
  final bool bPinned = pinnedEntryIds.contains(b.id);
  if (aPinned != bPinned) return aPinned ? -1 : 1;
  return compareEntriesNewestFirst(a, b);
}

List<DiaryEntrySummary> orderEntriesByFrozenDisplay(
  List<DiaryEntrySummary> entries,
  List<EntryId> frozenOrder,
) {
  if (frozenOrder.isEmpty) {
    return List<DiaryEntrySummary>.from(entries)
      ..sort(compareEntriesNewestFirst);
  }
  final Map<EntryId, int> indexById = <EntryId, int>{
    for (int index = 0; index < frozenOrder.length; index++)
      frozenOrder[index]: index,
  };
  final List<DiaryEntrySummary> known = <DiaryEntrySummary>[];
  final List<DiaryEntrySummary> unknown = <DiaryEntrySummary>[];
  for (final DiaryEntrySummary entry in entries) {
    (indexById.containsKey(entry.id) ? known : unknown).add(entry);
  }
  known.sort(
    (DiaryEntrySummary a, DiaryEntrySummary b) =>
        indexById[a.id]!.compareTo(indexById[b.id]!),
  );
  unknown.sort(compareEntriesNewestFirst);
  return <DiaryEntrySummary>[...known, ...unknown];
}

typedef HomeEntrySortState = ({
  bool isActive,
  List<EntryId> frozenDisplayOrder,
});

List<DiaryEntrySummary> sortHomeEntries({
  required List<DiaryEntrySummary> list,
  required HomeEntrySortState sortState,
  required Set<EntryId> pinnedIds,
}) {
  if (sortState.isActive && sortState.frozenDisplayOrder.isNotEmpty) {
    return orderEntriesByFrozenDisplay(list, sortState.frozenDisplayOrder);
  }
  return List<DiaryEntrySummary>.from(list)..sort(
    (DiaryEntrySummary a, DiaryEntrySummary b) =>
        compareHomeEntriesPinnedFirst(a, b, pinnedIds),
  );
}

List<EntryId> homeEntryDisplayOrder({
  required List<DiaryEntrySummary> entries,
  required Set<EntryId> pinnedIds,
}) => sortHomeEntries(
  list: entries,
  sortState: (isActive: false, frozenDisplayOrder: const <EntryId>[]),
  pinnedIds: pinnedIds,
).map((DiaryEntrySummary item) => item.id).toList(growable: false);
