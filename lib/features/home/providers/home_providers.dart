import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/shared/value_objects.dart';
import '../../../infrastructure/database/index_database.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/tag_providers.dart';
import '../../../shared/utils/entry_sorting.dart';
import '../../editor/providers/editor_providers.dart';
import '../../session/providers/session_providers.dart';
import '../state/home_state.dart';

/// 載入目前保險庫的全部索引紀錄，作為首頁各子視圖的基底資料源。
final allEntryIndexRecordsProvider = FutureProvider<List<EntryIndexRecord>>((
  Ref ref,
) async {
  final sessionState = await ref.watch(effectiveAppSessionProvider.future);
  if (!sessionState.isUnlocked || sessionState.session == null) {
    return const <EntryIndexRecord>[];
  }

  return ref.read(vaultRepositoryProvider).listEntries();
});

/// 載入首頁釘選的日記 ID 集合（權威來源為 vault/pinned_entries.json）。
final homePinnedEntryIdsProvider = FutureProvider<Set<EntryId>>((
  Ref ref,
) async {
  final sessionState = await ref.watch(effectiveAppSessionProvider.future);
  if (!sessionState.isUnlocked || sessionState.session == null) {
    return const <EntryId>{};
  }

  return ref.read(vaultRepositoryProvider).listPinnedEntryIds();
});

/// 依搜尋條件載入首頁日記索引（不含釘選排序）。
final homeEntryIndexListProvider = FutureProvider<List<EntryIndexRecord>>((
  Ref ref,
) async {
  final sessionState = await ref.watch(effectiveAppSessionProvider.future);
  if (!sessionState.isUnlocked || sessionState.session == null) {
    return const <EntryIndexRecord>[];
  }

  final String query = ref.watch(homeSearchQueryProvider);
  if (query.trim().isEmpty) {
    return ref.watch(allEntryIndexRecordsProvider.future);
  }

  return ref.read(vaultRepositoryProvider).listEntries(searchQuery: query);
});

/// 首頁時間軸顯示用列表；排序與勾選狀態解耦，避免勾選時重載跳動。
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

/// 取得目前日曆選取日期對應的日記項目。
final calendarEntriesProvider = FutureProvider<List<EntryIndexRecord>>((
  Ref ref,
) async {
  final DateOnly? date = ref.watch(calendarSelectedDateProvider);
  if (date == null) {
    return const <EntryIndexRecord>[];
  }

  final sessionState = await ref.watch(effectiveAppSessionProvider.future);
  if (!sessionState.isUnlocked || sessionState.session == null) {
    return const <EntryIndexRecord>[];
  }

  final List<EntryIndexRecord> entries = await ref
      .read(vaultRepositoryProvider)
      .listEntries(date: date);
  return entries..sort(compareEntriesNewestFirst);
});

/// 取得日曆目前月份中有日記的日期，用於月曆標記。
final calendarMonthEntryDatesProvider = FutureProvider<List<DateOnly>>((
  Ref ref,
) async {
  final DateTime month = ref.watch(calendarVisibleMonthProvider);
  final sessionState = await ref.watch(effectiveAppSessionProvider.future);
  if (!sessionState.isUnlocked || sessionState.session == null) {
    return const <DateOnly>[];
  }

  return ref.read(vaultRepositoryProvider).monthEntryDates(month);
});

/// 取得日曆目前月份的全部日記，供月曆格子顯示標題。
final calendarMonthEntriesProvider = FutureProvider<List<EntryIndexRecord>>((
  Ref ref,
) async {
  final DateTime month = ref.watch(calendarVisibleMonthProvider);
  final sessionState = await ref.watch(effectiveAppSessionProvider.future);
  if (!sessionState.isUnlocked || sessionState.session == null) {
    return const <EntryIndexRecord>[];
  }

  return ref.read(vaultRepositoryProvider).listEntriesForMonth(month);
});

/// 提供「回顧」模式可選的年份清單。
final memoryAvailableYearsProvider = FutureProvider<List<int>>((Ref ref) async {
  final List<EntryIndexRecord> entries = await ref.watch(
    allEntryIndexRecordsProvider.future,
  );
  final List<int> years =
      entries.map((EntryIndexRecord item) => item.date.year).toSet().toList()
        ..sort();
  return years;
});

/// 根據回顧模式的範圍設定，回傳對應的日記集合。
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
  final sessionState = await ref.watch(effectiveAppSessionProvider.future);
  if (!sessionState.isUnlocked || sessionState.session == null) {
    return const <EntryIndexRecord>[];
  }

  final List<EntryIndexRecord> entries = await ref
      .read(vaultRepositoryProvider)
      .listEntriesForMonth(focusedMonth);
  return entries..sort(compareEntriesNewestFirst);
});

/// 統一刷新首頁依賴的索引快取，避免編輯後各區塊資料不同步。
Future<void> refreshHomeIndexCaches(
  WidgetRef ref, {
  EntryId? editedEntryId,
}) async {
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

/// 編輯器／設定等其他功能共用的索引刷新入口。
Future<void> refreshEntryIndexCaches(WidgetRef ref, {EntryId? editedEntryId}) {
  return refreshHomeIndexCaches(ref, editedEntryId: editedEntryId);
}
