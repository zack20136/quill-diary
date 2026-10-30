import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/home/home_entry_sorting.dart';
import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

import '../helpers/shared/entry_index_fixtures.dart';

void main() {
  test('compareHomeEntriesPinnedFirst 會優先排釘選項目且同組內依日期排序', () {
    final DiaryEntrySummary olderPinned = buildDiaryEntrySummary(
      id: 'pinned_old',
      date: const DateOnly('2026-01-01'),
    );
    final DiaryEntrySummary newerPinned = buildDiaryEntrySummary(
      id: 'pinned_new',
      date: const DateOnly('2026-06-01'),
    );
    final DiaryEntrySummary newerUnpinned = buildDiaryEntrySummary(
      id: 'unpinned_new',
      date: const DateOnly('2026-06-01'),
    );

    final List<DiaryEntrySummary> pinnedPriority =
        <DiaryEntrySummary>[newerUnpinned, olderPinned]..sort(
          (DiaryEntrySummary a, DiaryEntrySummary b) =>
              compareHomeEntriesPinnedFirst(a, b, <String>{'pinned_old'}),
        );
    final List<DiaryEntrySummary> sameGroup =
        <DiaryEntrySummary>[olderPinned, newerPinned]..sort(
          (DiaryEntrySummary a, DiaryEntrySummary b) =>
              compareHomeEntriesPinnedFirst(a, b, <String>{
                'pinned_old',
                'pinned_new',
              }),
        );

    expect(
      pinnedPriority.map((DiaryEntrySummary item) => item.id).toList(),
      <String>['pinned_old', 'unpinned_new'],
    );
    expect(
      sameGroup.map((DiaryEntrySummary item) => item.id).toList(),
      <String>['pinned_new', 'pinned_old'],
    );
  });

  test('orderEntriesByFrozenDisplay 會保留凍結順序，未知項目則依日期排序', () {
    final DiaryEntrySummary pinned = buildDiaryEntrySummary(
      id: 'pinned',
      date: const DateOnly('2026-01-01'),
    );
    final DiaryEntrySummary newer = buildDiaryEntrySummary(
      id: 'newer',
      date: const DateOnly('2026-06-01'),
    );
    final DiaryEntrySummary older = buildDiaryEntrySummary(
      id: 'older',
      date: const DateOnly('2026-03-01'),
    );
    final DiaryEntrySummary unknownNewer = buildDiaryEntrySummary(
      id: 'unknown_newer',
      date: const DateOnly('2026-06-01'),
    );

    final List<DiaryEntrySummary> frozenOrdered = orderEntriesByFrozenDisplay(
      <DiaryEntrySummary>[older, newer, pinned],
      <String>['pinned', 'newer', 'older'],
    );
    final List<DiaryEntrySummary> fallbackOrdered = orderEntriesByFrozenDisplay(
      <DiaryEntrySummary>[older, unknownNewer],
      const <String>[],
    );

    expect(
      frozenOrdered.map((DiaryEntrySummary item) => item.id).toList(),
      <String>['pinned', 'newer', 'older'],
    );
    expect(
      fallbackOrdered.map((DiaryEntrySummary item) => item.id).toList(),
      <String>['unknown_newer', 'older'],
    );
  });

  test('sortHomeEntries 會在一般模式與選取模式套用對應排序', () {
    final DiaryEntrySummary pinned = buildDiaryEntrySummary(
      id: 'pinned',
      date: const DateOnly('2026-01-01'),
    );
    final DiaryEntrySummary newer = buildDiaryEntrySummary(
      id: 'newer',
      date: const DateOnly('2026-06-01'),
    );
    final DiaryEntrySummary older = buildDiaryEntrySummary(
      id: 'older',
      date: const DateOnly('2026-03-01'),
    );

    final List<DiaryEntrySummary> pinnedFirst = sortHomeEntries(
      list: <DiaryEntrySummary>[newer, pinned],
      sortState: (isActive: false, frozenDisplayOrder: const <EntryId>[]),
      pinnedIds: <String>{'pinned'},
    );
    final List<DiaryEntrySummary> frozenSorted = sortHomeEntries(
      list: <DiaryEntrySummary>[older, newer, pinned],
      sortState: (
        isActive: true,
        frozenDisplayOrder: <String>['pinned', 'newer', 'older'],
      ),
      pinnedIds: <String>{},
    );

    expect(
      pinnedFirst.map((DiaryEntrySummary item) => item.id).toList(),
      <String>['pinned', 'newer'],
    );
    expect(
      frozenSorted.map((DiaryEntrySummary item) => item.id).toList(),
      <String>['pinned', 'newer', 'older'],
    );
  });
}
