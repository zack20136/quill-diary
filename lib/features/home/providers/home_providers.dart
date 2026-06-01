import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/shared/value_objects.dart';
import '../../../infrastructure/database/index_database.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/utils/diary_presence_tag_counts.dart';
import '../../../shared/utils/entry_sorting.dart';
import '../../editor/providers/editor_providers.dart';
import '../../session/providers/session_providers.dart';
import '../models/overview_models.dart';
import '../state/home_state.dart';

/// 載入目前保險庫的全部索引紀錄，作為首頁各子視圖的基底資料源。
final allEntryIndexRecordsProvider = FutureProvider<List<EntryIndexRecord>>((Ref ref) async {
  final sessionState = await ref.watch(effectiveAppSessionProvider.future);
  if (!sessionState.isUnlocked || sessionState.session == null) {
    return const <EntryIndexRecord>[];
  }

  return ref.read(vaultRepositoryProvider).listEntries();
});

/// 依首頁搜尋字串取得排序後的日記列表。
final homeEntriesProvider = FutureProvider<List<EntryIndexRecord>>((Ref ref) async {
  final sessionState = await ref.watch(effectiveAppSessionProvider.future);
  if (!sessionState.isUnlocked || sessionState.session == null) {
    return const <EntryIndexRecord>[];
  }

  final String query = ref.watch(homeSearchQueryProvider);
  if (query.trim().isEmpty) {
    final List<EntryIndexRecord> list =
        List<EntryIndexRecord>.from(await ref.watch(allEntryIndexRecordsProvider.future));
    list.sort(compareEntriesNewestFirst);
    return list;
  }

  final List<EntryIndexRecord> list = await ref.read(vaultRepositoryProvider).listEntries(
        searchQuery: query,
      );
  list.sort(compareEntriesNewestFirst);
  return list;
});

/// 取得目前日曆選取日期對應的日記項目。
final calendarEntriesProvider = FutureProvider<List<EntryIndexRecord>>((Ref ref) async {
  final DateOnly? date = ref.watch(calendarSelectedDateProvider);
  if (date == null) {
    return const <EntryIndexRecord>[];
  }

  final List<EntryIndexRecord> entries = await ref.watch(allEntryIndexRecordsProvider.future);
  return entries
      .where((EntryIndexRecord entry) => entry.date.value == date.value)
      .toList()
    ..sort(compareEntriesNewestFirst);
});

/// 取得日曆目前月份中有日記的日期，用於月曆標記。
final calendarMonthEntryDatesProvider = FutureProvider<List<DateOnly>>((Ref ref) async {
  final DateTime month = ref.watch(calendarVisibleMonthProvider);
  final List<EntryIndexRecord> entries = await ref.watch(allEntryIndexRecordsProvider.future);
  final Set<String> seen = <String>{};
  final List<DateOnly> dates = <DateOnly>[];
  for (final EntryIndexRecord entry in entries) {
    final DateTime date = entry.date.toDateTime();
    if (date.year != month.year || date.month != month.month) {
      continue;
    }
    if (seen.add(entry.date.value)) {
      dates.add(entry.date);
    }
  }
  dates.sort((DateOnly a, DateOnly b) => a.value.compareTo(b.value));
  return dates;
});

/// 取得日曆目前月份的全部日記，供月曆格子顯示標題。
final calendarMonthEntriesProvider = FutureProvider<List<EntryIndexRecord>>((Ref ref) async {
  final DateTime month = ref.watch(calendarVisibleMonthProvider);
  final List<EntryIndexRecord> entries = await ref.watch(allEntryIndexRecordsProvider.future);
  return entries.where((EntryIndexRecord entry) {
    final DateTime date = entry.date.toDateTime();
    return date.year == month.year && date.month == month.month;
  }).toList()
    ..sort((EntryIndexRecord a, EntryIndexRecord b) {
      final int dateOrder = a.date.value.compareTo(b.date.value);
      if (dateOrder != 0) {
        return dateOrder;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
});

/// 將索引紀錄聚合成首頁總覽頁需要的統計資訊。
final overviewSummaryProvider = FutureProvider<OverviewSummary>((Ref ref) async {
  final List<EntryIndexRecord> entries = await ref.watch(allEntryIndexRecordsProvider.future);
  int totalWords = 0;
  int totalCharacters = 0;
  int totalAttachments = 0;
  int entriesWithTags = 0;
  int entriesWithAttachments = 0;

  for (final EntryIndexRecord entry in entries) {
    totalWords += entry.wordCount;
    totalCharacters += entry.charCount;
    totalAttachments += entry.attachmentCount;
    if (entry.tags.isNotEmpty) {
      entriesWithTags++;
    }
    if (entry.attachmentCount > 0) {
      entriesWithAttachments++;
    }
  }

  final Map<String, int> tagCounts = diaryPresenceTagCounts(entries);

  final List<OverviewTagStat> topTags = tagCounts.entries
      .map((item) => OverviewTagStat(label: item.key, count: item.value))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));

  final int avgWordsPerEntryRounded =
      entries.isEmpty ? 0 : (totalWords / entries.length).round();

  return OverviewSummary(
    totalEntries: entries.length,
    totalWords: totalWords,
    totalCharacters: totalCharacters,
    totalAttachments: totalAttachments,
    activeDays: entries.map((EntryIndexRecord item) => item.date.value).toSet().length,
    entriesWithTags: entriesWithTags,
    entriesWithAttachments: entriesWithAttachments,
    avgWordsPerEntryRounded: avgWordsPerEntryRounded,
    topTags: topTags.take(8).toList(),
  );
});

/// 提供「回顧」模式可選的年份清單。
final memoryAvailableYearsProvider = FutureProvider<List<int>>((Ref ref) async {
  final List<EntryIndexRecord> entries = await ref.watch(allEntryIndexRecordsProvider.future);
  final List<int> years = entries.map((EntryIndexRecord item) => item.date.year).toSet().toList()
    ..sort();
  return years;
});

/// 根據回顧模式的範圍設定，回傳對應的日記集合。
final memoryEntriesProvider = FutureProvider<List<EntryIndexRecord>>((Ref ref) async {
  final List<EntryIndexRecord> entries = await ref.watch(allEntryIndexRecordsProvider.future);
  final MemoryScope scope = ref.watch(memoryScopeProvider);
  if (scope == MemoryScope.all) {
    return List<EntryIndexRecord>.from(entries)..sort(compareEntriesNewestFirst);
  }
  if (scope == MemoryScope.year) {
    final int focusedYear = ref.watch(memoryFocusedYearProvider);
    return entries.where((item) => item.date.year == focusedYear).toList()
      ..sort(compareEntriesNewestFirst);
  }

  final DateTime focusedMonth = ref.watch(memoryFocusedMonthProvider);
  return entries.where((item) {
    final DateTime date = item.date.toDateTime();
    return date.year == focusedMonth.year && date.month == focusedMonth.month;
  }).toList()
    ..sort(compareEntriesNewestFirst);
});

/// 統一刷新首頁依賴的索引快取，避免編輯後各區塊資料不同步。
Future<void> refreshHomeIndexCaches(WidgetRef ref, {EntryId? editedEntryId}) async {
  ref
    ..invalidate(homeEntriesProvider)
    ..invalidate(calendarMonthEntryDatesProvider)
    ..invalidate(calendarMonthEntriesProvider)
    ..invalidate(calendarEntriesProvider)
    ..invalidate(allEntryIndexRecordsProvider);

  ref.read(entryIndexRevisionProvider.notifier).bump();

  final EntryId? id = editedEntryId?.trim();
  if (id != null && id.isNotEmpty) {
    ref.invalidate(entryProvider(id));
  }
}

/// editor / settings 等其他 feature 共用的索引刷新入口。
Future<void> refreshEntryIndexCaches(WidgetRef ref, {EntryId? editedEntryId}) {
  return refreshHomeIndexCaches(ref, editedEntryId: editedEntryId);
}
