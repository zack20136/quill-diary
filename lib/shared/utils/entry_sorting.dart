import '../../domain/shared/value_objects.dart';
import '../../infrastructure/database/index_database.dart';

/// 首頁專用：釘選項目優先，其餘仍依日期新到舊排序。
int compareHomeEntriesPinnedFirst(
  EntryIndexRecord a,
  EntryIndexRecord b,
  Set<EntryId> pinnedEntryIds,
) {
  final bool aPinned = pinnedEntryIds.contains(a.id);
  final bool bPinned = pinnedEntryIds.contains(b.id);
  if (aPinned != bPinned) {
    return aPinned ? -1 : 1;
  }
  return compareEntriesNewestFirst(a, b);
}

/// 依進入選取模式當下的順序排列；未出現在 [frozenOrder] 的項目接在後面並依日期排序。
List<EntryIndexRecord> orderEntriesByFrozenDisplay(
  List<EntryIndexRecord> entries,
  List<EntryId> frozenOrder,
) {
  if (frozenOrder.isEmpty) {
    return List<EntryIndexRecord>.from(entries)
      ..sort(compareEntriesNewestFirst);
  }

  final Map<EntryId, int> indexById = <EntryId, int>{
    for (int i = 0; i < frozenOrder.length; i++) frozenOrder[i]: i,
  };
  final List<EntryIndexRecord> known = <EntryIndexRecord>[];
  final List<EntryIndexRecord> unknown = <EntryIndexRecord>[];
  for (final EntryIndexRecord entry in entries) {
    if (indexById.containsKey(entry.id)) {
      known.add(entry);
    } else {
      unknown.add(entry);
    }
  }
  known.sort(
    (EntryIndexRecord a, EntryIndexRecord b) =>
        indexById[a.id]!.compareTo(indexById[b.id]!),
  );
  unknown.sort(compareEntriesNewestFirst);
  return <EntryIndexRecord>[...known, ...unknown];
}

int compareEntriesNewestFirst(EntryIndexRecord a, EntryIndexRecord b) {
  final int byDate = b.date.value.compareTo(a.date.value);
  if (byDate != 0) {
    return byDate;
  }
  final int byCreated = b.createdAt.compareTo(a.createdAt);
  if (byCreated != 0) {
    return byCreated;
  }
  return b.updatedAt.compareTo(a.updatedAt);
}

typedef HomeEntrySortState = ({bool isActive, List<EntryId> frozenDisplayOrder});

/// 首頁列表排序：選取模式凍結順序，一般模式釘選優先。
List<EntryIndexRecord> sortHomeEntries({
  required List<EntryIndexRecord> list,
  required HomeEntrySortState sortState,
  required Set<EntryId> pinnedIds,
}) {
  if (sortState.isActive && sortState.frozenDisplayOrder.isNotEmpty) {
    return orderEntriesByFrozenDisplay(list, sortState.frozenDisplayOrder);
  }
  return List<EntryIndexRecord>.from(list)
    ..sort(
      (EntryIndexRecord a, EntryIndexRecord b) =>
          compareHomeEntriesPinnedFirst(a, b, pinnedIds),
    );
}

/// 依釘選優先規則計算首頁顯示順序的 ID 列表。
List<EntryId> homeEntryDisplayOrder({
  required List<EntryIndexRecord> entries,
  required Set<EntryId> pinnedIds,
}) {
  return sortHomeEntries(
    list: entries,
    sortState: (isActive: false, frozenDisplayOrder: const <EntryId>[]),
    pinnedIds: pinnedIds,
  ).map((EntryIndexRecord item) => item.id).toList(growable: false);
}
