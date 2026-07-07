import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/providers/core_providers.dart';
import 'package:quill_diary/application/tag/tag_providers.dart';
import 'package:quill_diary/shared/utils/entry_sorting.dart';
import '../../editor/providers/editor_providers.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import '../state/home_state.dart';

final allEntryIndexRecordsProvider = FutureProvider<List<EntryIndexRecord>>((
  Ref ref,
) async {
  ref.watch(entryIndexRevisionProvider);
  if (ref.watch(indexQueryableVaultSessionProvider) == null) {
    return const <EntryIndexRecord>[];
  }

  return ref.read(vaultRepositoryProvider).listEntries();
});
final homePinnedEntryIdsProvider = FutureProvider<Set<EntryId>>((
  Ref ref,
) async {
  if (ref.watch(indexQueryableVaultSessionProvider) == null) {
    return const <EntryId>{};
  }

  return ref.read(vaultRepositoryProvider).listPinnedEntryIds();
});
final homeEntryIndexListProvider = FutureProvider<List<EntryIndexRecord>>((
  Ref ref,
) async {
  ref.watch(entryIndexRevisionProvider);
  if (ref.watch(indexQueryableVaultSessionProvider) == null) {
    return const <EntryIndexRecord>[];
  }

  final String query = ref.watch(homeSearchQueryProvider);
  if (query.trim().isEmpty) {
    return ref.read(vaultRepositoryProvider).listEntries();
  }

  return ref.read(vaultRepositoryProvider).listEntries(searchQuery: query);
});
final homeEntriesProvider = Provider<AsyncValue<List<EntryIndexRecord>>>((
  Ref ref,
) {
  final AsyncValue<List<EntryIndexRecord>> raw = ref.watch(
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
    (List<EntryIndexRecord> list) =>
        sortHomeEntries(list: list, sortState: sortState, pinnedIds: pinnedIds),
  );
});
final calendarEntriesProvider = FutureProvider<List<EntryIndexRecord>>((
  Ref ref,
) async {
  final DateOnly? date = ref.watch(calendarSelectedDateProvider);
  if (date == null) {
    return const <EntryIndexRecord>[];
  }

  if (ref.watch(indexQueryableVaultSessionProvider) == null) {
    return const <EntryIndexRecord>[];
  }

  final List<EntryIndexRecord> entries = await ref
      .read(vaultRepositoryProvider)
      .listEntries(date: date);
  return entries..sort(compareEntriesNewestFirst);
});
final calendarMonthEntryDatesProvider = FutureProvider<List<DateOnly>>((
  Ref ref,
) async {
  final DateTime month = ref.watch(calendarVisibleMonthProvider);
  if (ref.watch(indexQueryableVaultSessionProvider) == null) {
    return const <DateOnly>[];
  }

  return ref.read(vaultRepositoryProvider).monthEntryDates(month);
});
final calendarMonthEntriesProvider = FutureProvider<List<EntryIndexRecord>>((
  Ref ref,
) async {
  final DateTime month = ref.watch(calendarVisibleMonthProvider);
  if (ref.watch(indexQueryableVaultSessionProvider) == null) {
    return const <EntryIndexRecord>[];
  }

  return ref.read(vaultRepositoryProvider).listEntriesForMonth(month);
});
final memoryAvailableYearsProvider = FutureProvider<List<int>>((Ref ref) async {
  final List<EntryIndexRecord> entries = await ref.watch(
    allEntryIndexRecordsProvider.future,
  );
  final List<int> years =
      entries.map((EntryIndexRecord item) => item.date.year).toSet().toList()
        ..sort();
  return years;
});
final memoryEntriesProvider = FutureProvider<List<EntryIndexRecord>>((
  Ref ref,
) async {
  final MemoryScope scope = ref.watch(memoryScopeProvider);
  if (scope == MemoryScope.all) {
    final List<EntryIndexRecord> entries = await ref.watch(
      allEntryIndexRecordsProvider.future,
    );
    return List<EntryIndexRecord>.from(entries)
      ..sort(compareEntriesNewestFirst);
  }
  if (scope == MemoryScope.year) {
    final List<EntryIndexRecord> entries = await ref.watch(
      allEntryIndexRecordsProvider.future,
    );
    final int focusedYear = ref.watch(memoryFocusedYearProvider);
    return entries.where((item) => item.date.year == focusedYear).toList()
      ..sort(compareEntriesNewestFirst);
  }

  final DateTime focusedMonth = ref.watch(memoryFocusedMonthProvider);
  if (ref.watch(indexQueryableVaultSessionProvider) == null) {
    return const <EntryIndexRecord>[];
  }

  final List<EntryIndexRecord> entries = await ref
      .read(vaultRepositoryProvider)
      .listEntriesForMonth(focusedMonth);
  return entries..sort(compareEntriesNewestFirst);
});
void refreshHomeIndexCaches(WidgetRef ref, {EntryId? editedEntryId}) {
  ref
    ..invalidate(homeEntryIndexListProvider)
    ..invalidate(homePinnedEntryIdsProvider)
    ..invalidate(calendarMonthEntryDatesProvider)
    ..invalidate(calendarMonthEntriesProvider)
    ..invalidate(calendarEntriesProvider)
    ..invalidate(allEntryIndexRecordsProvider)
    ..invalidate(tagCatalogProvider);

  ref.read(entryIndexRevisionProvider.notifier).bump();

  final EntryId? id = editedEntryId?.trim();
  if (id != null && id.isNotEmpty) {
    ref.invalidate(entryProvider(id));
  }
}

void refreshEntryIndexCaches(WidgetRef ref, {EntryId? editedEntryId}) {
  refreshHomeIndexCaches(ref, editedEntryId: editedEntryId);
}
