import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/diary/diary_presence_tag_counts.dart';
import '../../../domain/shared/value_objects.dart';
import '../../../infrastructure/database/index_database.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/utils/entry_sorting.dart';
import '../../editor/providers/editor_providers.dart';
import '../../session/providers/session_providers.dart';
import '../models/overview_models.dart';
import '../state/home_state.dart';

final allEntryIndexRecordsProvider = FutureProvider<List<EntryIndexRecord>>((Ref ref) async {
  final sessionState = await ref.watch(effectiveAppSessionProvider.future);
  if (!sessionState.isUnlocked || sessionState.session == null) {
    return const <EntryIndexRecord>[];
  }

  return ref.read(vaultRepositoryProvider).listEntries();
});

final homeEntriesProvider = FutureProvider<List<EntryIndexRecord>>((Ref ref) async {
  final sessionState = await ref.watch(effectiveAppSessionProvider.future);
  if (!sessionState.isUnlocked || sessionState.session == null) {
    return const <EntryIndexRecord>[];
  }

  final String query = ref.watch(homeSearchQueryProvider);
  final List<EntryIndexRecord> list = await ref.read(vaultRepositoryProvider).listEntries(
        searchQuery: query.isEmpty ? null : query,
      );
  list.sort(compareEntriesNewestFirst);
  return list;
});

final calendarEntriesProvider = FutureProvider<List<EntryIndexRecord>>((Ref ref) async {
  final sessionState = await ref.watch(effectiveAppSessionProvider.future);
  if (!sessionState.isUnlocked || sessionState.session == null) {
    return const <EntryIndexRecord>[];
  }

  final DateOnly? date = ref.watch(calendarSelectedDateProvider);
  if (date == null) {
    return const <EntryIndexRecord>[];
  }

  return ref.read(vaultRepositoryProvider).listEntries(date: date);
});

final calendarMonthEntryDatesProvider = FutureProvider<List<DateOnly>>((Ref ref) async {
  final sessionState = await ref.watch(effectiveAppSessionProvider.future);
  if (!sessionState.isUnlocked || sessionState.session == null) {
    return const <DateOnly>[];
  }

  return ref.read(vaultRepositoryProvider).monthEntryDates(
        ref.watch(calendarVisibleMonthProvider),
      );
});

final overviewSummaryProvider = FutureProvider<OverviewSummary>((Ref ref) async {
  final List<EntryIndexRecord> entries = await ref.watch(allEntryIndexRecordsProvider.future);
  final Map<String, int> moodCounts = <String, int>{};
  int totalWords = 0;
  int totalCharacters = 0;
  int totalAttachments = 0;
  int entriesWithTags = 0;
  int entriesWithAttachments = 0;
  int entriesWithMoodSet = 0;

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
    final String? mood = entry.mood?.trim();
    if (mood != null && mood.isNotEmpty) {
      entriesWithMoodSet++;
      moodCounts.update(mood, (int count) => count + 1, ifAbsent: () => 1);
    }
  }

  final Map<String, int> tagCounts = diaryPresenceTagCounts(entries);

  final List<OverviewTagStat> topTags = tagCounts.entries
      .map((item) => OverviewTagStat(label: item.key, count: item.value))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));

  final List<OverviewMoodStat> moods = moodCounts.entries
      .map((item) => OverviewMoodStat(label: item.key, count: item.value))
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
    entriesWithMoodSet: entriesWithMoodSet,
    avgWordsPerEntryRounded: avgWordsPerEntryRounded,
    topTags: topTags.take(8).toList(),
    moods: moods.take(6).toList(),
  );
});

final memoryAvailableYearsProvider = FutureProvider<List<int>>((Ref ref) async {
  final List<EntryIndexRecord> entries = await ref.watch(allEntryIndexRecordsProvider.future);
  final List<int> years = entries.map((EntryIndexRecord item) => item.date.year).toSet().toList()
    ..sort();
  return years;
});

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

Future<void> refreshHomeIndexCaches(WidgetRef ref, {EntryId? editedEntryId}) async {
  ref
    ..invalidate(homeEntriesProvider)
    ..invalidate(calendarMonthEntryDatesProvider)
    ..invalidate(calendarEntriesProvider)
    ..invalidate(allEntryIndexRecordsProvider);

  await Future.wait<void>(<Future<void>>[
    ref.read(homeEntriesProvider.future),
    ref.read(calendarMonthEntryDatesProvider.future),
    ref.read(calendarEntriesProvider.future),
    ref.read(allEntryIndexRecordsProvider.future),
  ]);

  ref.read(entryIndexRevisionProvider.notifier).bump();

  final EntryId? id = editedEntryId?.trim();
  if (id != null && id.isNotEmpty) {
    ref.invalidate(entryProvider(id));
  }
}

Future<void> refreshEntryIndexCaches(WidgetRef ref, {EntryId? editedEntryId}) {
  return refreshHomeIndexCaches(ref, editedEntryId: editedEntryId);
}
