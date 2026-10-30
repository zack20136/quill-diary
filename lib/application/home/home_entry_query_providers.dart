import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/diary/diary_entry_providers.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/home/home_entry_sorting.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/entry_index_sorting.dart';

final allDiaryEntrySummariesProvider = FutureProvider<List<DiaryEntrySummary>>((
  Ref ref,
) async {
  ref.watch(diaryRevisionProvider);
  if (ref.watch(indexQueryableVaultSessionProvider) == null) {
    return const <DiaryEntrySummary>[];
  }

  return ref.read(vaultRepositoryProvider).listEntries();
});

final homePinnedEntryIdsProvider = FutureProvider<Set<EntryId>>((
  Ref ref,
) async {
  ref.watch(diaryRevisionProvider);
  if (ref.watch(indexQueryableVaultSessionProvider) == null) {
    return const <EntryId>{};
  }

  return ref.read(vaultRepositoryProvider).listPinnedEntryIds();
});

final class HomeEntryQueryResult {
  const HomeEntryQueryResult({required this.query, required this.entries});

  final String query;
  final List<DiaryEntrySummary> entries;
}

final homeEntryIndexListProvider = FutureProvider<HomeEntryQueryResult>((
  Ref ref,
) async {
  ref.watch(diaryRevisionProvider);
  if (ref.watch(indexQueryableVaultSessionProvider) == null) {
    return const HomeEntryQueryResult(
      query: '',
      entries: <DiaryEntrySummary>[],
    );
  }

  final String query = ref.watch(homeSearchQueryProvider);
  if (query.trim().isEmpty) {
    return HomeEntryQueryResult(
      query: query,
      entries: await ref.read(vaultRepositoryProvider).listEntries(),
    );
  }

  return HomeEntryQueryResult(
    query: query,
    entries: await ref
        .read(vaultRepositoryProvider)
        .listEntries(searchQuery: query),
  );
});

final homeEntriesProvider = Provider<AsyncValue<List<DiaryEntrySummary>>>((
  Ref ref,
) {
  final AsyncValue<HomeEntryQueryResult> raw = ref.watch(
    homeEntryIndexListProvider,
  );
  final HomeEntrySortState sortState = ref.watch(
    homeEntrySelectionProvider.select(
      (HomeEntrySelectionState state) => (
        isActive: state.isActive,
        frozenDisplayOrder: state.frozenDisplayOrder,
      ),
    ),
  );
  final bool frozenSort =
      sortState.isActive && sortState.frozenDisplayOrder.isNotEmpty;
  final Set<EntryId> pinnedIds = frozenSort
      ? (ref.read(homePinnedEntryIdsProvider).value ?? const <EntryId>{})
      : (ref.watch(homePinnedEntryIdsProvider).value ?? const <EntryId>{});

  return raw.whenData(
    (HomeEntryQueryResult result) => sortHomeEntries(
      list: result.entries,
      sortState: sortState,
      pinnedIds: pinnedIds,
    ),
  );
});

final calendarEntriesProvider = FutureProvider<List<DiaryEntrySummary>>((
  Ref ref,
) async {
  ref.watch(diaryRevisionProvider);
  final DateOnly? date = ref.watch(calendarSelectedDateProvider);
  if (date == null) {
    return const <DiaryEntrySummary>[];
  }

  if (ref.watch(indexQueryableVaultSessionProvider) == null) {
    return const <DiaryEntrySummary>[];
  }

  final List<DiaryEntrySummary> entries = await ref
      .read(vaultRepositoryProvider)
      .listEntries(date: date);
  return entries..sort(compareEntriesNewestFirst);
});

final calendarGridEntriesProvider = FutureProvider<List<DiaryEntrySummary>>((
  Ref ref,
) async {
  ref.watch(diaryRevisionProvider);
  final DateTime month = ref.watch(calendarVisibleMonthProvider);
  if (ref.watch(indexQueryableVaultSessionProvider) == null) {
    return const <DiaryEntrySummary>[];
  }
  final ({DateOnly first, DateOnly last}) range = calendarGridDateRange(month);
  return ref
      .read(vaultRepositoryProvider)
      .listEntriesForDateRange(firstDate: range.first, lastDate: range.last);
});

final entryDateBoundsProvider =
    FutureProvider<({DateOnly earliest, DateOnly latest})?>((Ref ref) async {
      ref.watch(diaryRevisionProvider);
      if (ref.watch(indexQueryableVaultSessionProvider) == null) {
        return null;
      }
      return ref.read(vaultRepositoryProvider).entryDateBounds();
    });

final overviewAvailableYearsProvider = FutureProvider<List<int>>((
  Ref ref,
) async {
  final List<DiaryEntrySummary> entries = await ref.watch(
    allDiaryEntrySummariesProvider.future,
  );
  final List<int> years =
      entries.map((DiaryEntrySummary item) => item.date.year).toSet().toList()
        ..sort();
  return years;
});

final overviewEntriesProvider = FutureProvider<List<DiaryEntrySummary>>((
  Ref ref,
) async {
  ref.watch(diaryRevisionProvider);
  final OverviewScope scope = ref.watch(overviewScopeProvider);
  if (scope == OverviewScope.all) {
    final List<DiaryEntrySummary> entries = await ref.watch(
      allDiaryEntrySummariesProvider.future,
    );
    return List<DiaryEntrySummary>.from(entries)
      ..sort(compareEntriesNewestFirst);
  }
  if (scope == OverviewScope.year) {
    final List<DiaryEntrySummary> entries = await ref.watch(
      allDiaryEntrySummariesProvider.future,
    );
    final int focusedYear = ref.watch(overviewFocusedYearProvider);
    return entries.where((item) => item.date.year == focusedYear).toList()
      ..sort(compareEntriesNewestFirst);
  }

  final DateTime focusedMonth = ref.watch(overviewFocusedMonthProvider);
  if (ref.watch(indexQueryableVaultSessionProvider) == null) {
    return const <DiaryEntrySummary>[];
  }

  final List<DiaryEntrySummary> entries = await ref
      .read(vaultRepositoryProvider)
      .listEntriesForMonth(focusedMonth);
  return entries..sort(compareEntriesNewestFirst);
});
