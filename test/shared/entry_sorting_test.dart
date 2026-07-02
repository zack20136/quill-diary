import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/shared/utils/entry_sorting.dart';

import '../helpers/shared/entry_index_fixtures.dart';

void main() {
  test('compareHomeEntriesPinnedFirst 會優先排釘選項目且同組內依日期排序', () {
    final EntryIndexRecord olderPinned = buildEntryIndexRecord(
      id: 'pinned_old',
      date: const DateOnly('2026-01-01'),
    );
    final EntryIndexRecord newerPinned = buildEntryIndexRecord(
      id: 'pinned_new',
      date: const DateOnly('2026-06-01'),
    );
    final EntryIndexRecord newerUnpinned = buildEntryIndexRecord(
      id: 'unpinned_new',
      date: const DateOnly('2026-06-01'),
    );

    final List<EntryIndexRecord> pinnedPriority = <EntryIndexRecord>[
      newerUnpinned,
      olderPinned,
    ]..sort(
      (EntryIndexRecord a, EntryIndexRecord b) =>
          compareHomeEntriesPinnedFirst(a, b, <String>{'pinned_old'}),
    );
    final List<EntryIndexRecord> sameGroup = <EntryIndexRecord>[olderPinned, newerPinned]
      ..sort(
        (EntryIndexRecord a, EntryIndexRecord b) =>
            compareHomeEntriesPinnedFirst(
              a,
              b,
              <String>{'pinned_old', 'pinned_new'},
            ),
      );

    expect(
      pinnedPriority.map((EntryIndexRecord item) => item.id).toList(),
      <String>['pinned_old', 'unpinned_new'],
    );
    expect(
      sameGroup.map((EntryIndexRecord item) => item.id).toList(),
      <String>['pinned_new', 'pinned_old'],
    );
  });

  test('orderEntriesByFrozenDisplay 會保留凍結順序，未知項目則依日期排序', () {
    final EntryIndexRecord pinned = buildEntryIndexRecord(
      id: 'pinned',
      date: const DateOnly('2026-01-01'),
    );
    final EntryIndexRecord newer = buildEntryIndexRecord(
      id: 'newer',
      date: const DateOnly('2026-06-01'),
    );
    final EntryIndexRecord older = buildEntryIndexRecord(
      id: 'older',
      date: const DateOnly('2026-03-01'),
    );
    final EntryIndexRecord unknownNewer = buildEntryIndexRecord(
      id: 'unknown_newer',
      date: const DateOnly('2026-06-01'),
    );

    final List<EntryIndexRecord> frozenOrdered = orderEntriesByFrozenDisplay(
      <EntryIndexRecord>[older, newer, pinned],
      <String>['pinned', 'newer', 'older'],
    );
    final List<EntryIndexRecord> fallbackOrdered = orderEntriesByFrozenDisplay(
      <EntryIndexRecord>[older, unknownNewer],
      const <String>[],
    );

    expect(
      frozenOrdered.map((EntryIndexRecord item) => item.id).toList(),
      <String>['pinned', 'newer', 'older'],
    );
    expect(
      fallbackOrdered.map((EntryIndexRecord item) => item.id).toList(),
      <String>['unknown_newer', 'older'],
    );
  });

  test('sortHomeEntries 會在一般模式與選取模式套用對應排序', () {
    final EntryIndexRecord pinned = buildEntryIndexRecord(
      id: 'pinned',
      date: const DateOnly('2026-01-01'),
    );
    final EntryIndexRecord newer = buildEntryIndexRecord(
      id: 'newer',
      date: const DateOnly('2026-06-01'),
    );
    final EntryIndexRecord older = buildEntryIndexRecord(
      id: 'older',
      date: const DateOnly('2026-03-01'),
    );

    final List<EntryIndexRecord> pinnedFirst = sortHomeEntries(
      list: <EntryIndexRecord>[newer, pinned],
      sortState: (isActive: false, frozenDisplayOrder: const <EntryId>[]),
      pinnedIds: <String>{'pinned'},
    );
    final List<EntryIndexRecord> frozenSorted = sortHomeEntries(
      list: <EntryIndexRecord>[older, newer, pinned],
      sortState: (
        isActive: true,
        frozenDisplayOrder: <String>['pinned', 'newer', 'older'],
      ),
      pinnedIds: <String>{},
    );

    expect(
      pinnedFirst.map((EntryIndexRecord item) => item.id).toList(),
      <String>['pinned', 'newer'],
    );
    expect(
      frozenSorted.map((EntryIndexRecord item) => item.id).toList(),
      <String>['pinned', 'newer', 'older'],
    );
  });
}
