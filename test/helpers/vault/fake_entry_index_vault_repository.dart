import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/security/app_lock_service.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/storage/tag_styles_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../vault/stub_crypto_service.dart';
import '../vault/test_vault_path_strategy.dart';

DateTime _monthKey(DateTime month) => DateTime(month.year, month.month);

class FakeEntryIndexVaultRepository extends VaultRepository {
  FakeEntryIndexVaultRepository({
    List<EntryIndexRecord> allEntries = const <EntryIndexRecord>[],
    this.searchResponses = const <String, List<EntryIndexRecord>>{},
    this.entriesByDate = const <DateOnly, List<EntryIndexRecord>>{},
    this.entriesByMonth = const <DateTime, List<EntryIndexRecord>>{},
    this.tagCatalog = const <TagCatalogItem>[],
  }) : allEntries = List<EntryIndexRecord>.from(allEntries),
       super(
         pathStrategy: DummyVaultPathStrategy(),
         frontMatterCodec: const FrontMatterCodec(),
         cryptoService: StubCryptoService(),
         indexDatabaseManager: IndexDatabaseManager(DummyVaultPathStrategy()),
         deviceKeyManager: const UnsupportedDeviceKeyManager(),
         appLockService: const UnsupportedAppLockService(),
       );

  List<EntryIndexRecord> allEntries;
  final Map<String, List<EntryIndexRecord>> searchResponses;
  final Map<DateOnly, List<EntryIndexRecord>> entriesByDate;
  final Map<DateTime, List<EntryIndexRecord>> entriesByMonth;
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
  Future<List<EntryIndexRecord>> listEntries({
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
      return List<EntryIndexRecord>.from(allEntries);
    }
    return const <EntryIndexRecord>[];
  }

  @override
  Future<List<EntryIndexRecord>> listEntriesForMonth(DateTime month) async {
    listEntriesForMonthCalls++;
    final DateTime key = _monthKey(month);
    listEntriesForMonths.add(key);
    return entriesByMonth[key] ?? const <EntryIndexRecord>[];
  }

  @override
  Future<List<EntryIndexRecord>> listEntriesForDateRange({
    required DateOnly firstDate,
    required DateOnly lastDate,
  }) async {
    listEntryDateRanges.add((first: firstDate, last: lastDate));
    return allEntries
        .where(
          (EntryIndexRecord entry) =>
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
        allEntries.map((EntryIndexRecord entry) => entry.date).toList()
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
}
