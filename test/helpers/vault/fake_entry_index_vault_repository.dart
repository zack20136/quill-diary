import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/domain/tag/tag.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/security/app_lock_service.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import 'stub_crypto_service.dart';
import 'test_vault_path_strategy.dart';

DateTime _monthKey(DateTime month) => DateTime(month.year, month.month);

class FakeEntryIndexVaultRepository extends VaultRepository {
  FakeEntryIndexVaultRepository({
    List<DiaryEntrySummary> allEntries = const <DiaryEntrySummary>[],
    this.searchResponses = const <String, List<DiaryEntrySummary>>{},
    this.entriesByDate = const <DateOnly, List<DiaryEntrySummary>>{},
    this.entriesByMonth = const <DateTime, List<DiaryEntrySummary>>{},
    this.tagCatalog = const <TagCatalogItem>[],
  }) : allEntries = List<DiaryEntrySummary>.from(allEntries),
       super(
         pathStrategy: DummyVaultPathStrategy(),
         frontMatterCodec: const FrontMatterCodec(),
         cryptoService: StubCryptoService(),
         indexDatabaseManager: IndexDatabaseManager(DummyVaultPathStrategy()),
         deviceKeyManager: const UnsupportedDeviceKeyManager(),
         appLockService: const UnsupportedAppLockService(),
       );

  List<DiaryEntrySummary> allEntries;
  final Map<String, List<DiaryEntrySummary>> searchResponses;
  final Map<DateOnly, List<DiaryEntrySummary>> entriesByDate;
  final Map<DateTime, List<DiaryEntrySummary>> entriesByMonth;
  final List<TagCatalogItem> tagCatalog;

  int ensureIndexReadyCalls = 0;
  int listEntriesCalls = 0;
  int listEntriesForMonthCalls = 0;
  final List<String?> listEntriesSearchQueries = <String?>[];
  final List<DateOnly?> listEntriesDates = <DateOnly?>[];
  final List<DateTime> listEntriesForMonths = <DateTime>[];
  final List<({DateOnly first, DateOnly last})> listEntryDateRanges =
      <({DateOnly first, DateOnly last})>[];

  @override
  Future<void> ensureIndexReady(UnlockedVaultSession session) async {
    ensureIndexReadyCalls++;
  }

  @override
  Future<List<DiaryEntrySummary>> listEntries({
    String? searchQuery,
    DateOnly? date,
  }) async {
    listEntriesCalls++;
    listEntriesSearchQueries.add(searchQuery);
    listEntriesDates.add(date);

    if (searchQuery != null && searchResponses.containsKey(searchQuery)) {
      return searchResponses[searchQuery]!;
    }
    if (date != null && entriesByDate.containsKey(date)) {
      return entriesByDate[date]!;
    }
    if (searchQuery == null && date == null) {
      return List<DiaryEntrySummary>.from(allEntries);
    }
    return const <DiaryEntrySummary>[];
  }

  @override
  Future<List<DiaryEntrySummary>> listEntriesForMonth(DateTime month) async {
    listEntriesForMonthCalls++;
    final DateTime key = _monthKey(month);
    listEntriesForMonths.add(key);
    return entriesByMonth[key] ?? const <DiaryEntrySummary>[];
  }

  @override
  Future<List<DiaryEntrySummary>> listEntriesForDateRange({
    required DateOnly firstDate,
    required DateOnly lastDate,
  }) async {
    listEntryDateRanges.add((first: firstDate, last: lastDate));
    return allEntries
        .where(
          (DiaryEntrySummary entry) =>
              entry.date.value.compareTo(firstDate.value) >= 0 &&
              entry.date.value.compareTo(lastDate.value) <= 0,
        )
        .toList();
  }

  @override
  Future<({DateOnly earliest, DateOnly latest})?> entryDateBounds() async {
    if (allEntries.isEmpty) {
      return null;
    }
    final List<DateOnly> dates =
        allEntries.map((DiaryEntrySummary entry) => entry.date).toList()
          ..sort((DateOnly a, DateOnly b) => a.value.compareTo(b.value));
    return (earliest: dates.first, latest: dates.last);
  }

  @override
  Future<List<TagCatalogItem>> listTagCatalog() async => tagCatalog;

  Set<EntryId> pinnedEntryIds = <EntryId>{};

  @override
  Future<Set<EntryId>> listPinnedEntryIds() async =>
      Set<EntryId>.from(pinnedEntryIds);

  @override
  Future<void> setEntriesPinned(
    Iterable<EntryId> entryIds, {
    required bool pinned,
  }) async {
    for (final EntryId id in entryIds) {
      if (pinned) {
        pinnedEntryIds.add(id);
      } else {
        pinnedEntryIds.remove(id);
      }
    }
  }

  @override
  Future<void> deleteEntry(
    UnlockedVaultSession session,
    EntryId entryId,
  ) async {
    allEntries.removeWhere((entry) => entry.id == entryId);
  }
}
