import 'dart:io';

import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/security/app_lock_service.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/storage/tag_styles_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import 'stub_crypto_service.dart';
import 'test_vault_path_strategy.dart';

DateTime _monthKey(DateTime month) => DateTime(month.year, month.month);

/// 首頁索引查詢用的 VaultRepository 測試替身；不 reimplement 搜尋/排序規則。
class FakeEntryIndexVaultRepository extends VaultRepository {
  FakeEntryIndexVaultRepository({
    List<EntryIndexRecord> allEntries = const <EntryIndexRecord>[],
    this.searchResponses = const <String, List<EntryIndexRecord>>{},
    this.entriesByDate = const <DateOnly, List<EntryIndexRecord>>{},
    this.entriesByMonth = const <DateTime, List<EntryIndexRecord>>{},
    this.monthDatesByMonth = const <DateTime, List<DateOnly>>{},
    this.tagCatalog = const <TagCatalogItem>[],
  }) : allEntries = List<EntryIndexRecord>.from(allEntries),
       super(
         pathStrategy: DummyVaultPathStrategy(),
         frontMatterCodec: const FrontMatterCodec(),
         cryptoService: StubCryptoService(),
         indexDatabaseManager: IndexDatabaseManager(DummyVaultPathStrategy()),
         deviceKeyManager: const UnsupportedDeviceKeyManager(),
         appLockService: const UnsupportedAppLockService(),
         userPreferences: UserPreferences(storageFile: File('.unused_test_prefs.json')),
       );

  List<EntryIndexRecord> allEntries;
  final Map<String, List<EntryIndexRecord>> searchResponses;
  final Map<DateOnly, List<EntryIndexRecord>> entriesByDate;
  final Map<DateTime, List<EntryIndexRecord>> entriesByMonth;
  final Map<DateTime, List<DateOnly>> monthDatesByMonth;
  final List<TagCatalogItem> tagCatalog;

  int ensureIndexReadyCalls = 0;
  int listEntriesCalls = 0;
  int listEntriesForMonthCalls = 0;
  int monthEntryDatesCalls = 0;
  final List<String?> listEntriesSearchQueries = <String?>[];
  final List<DateOnly?> listEntriesDates = <DateOnly?>[];
  final List<DateTime> listEntriesForMonths = <DateTime>[];
  final List<DateTime> monthEntryDateMonths = <DateTime>[];

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
  Future<List<DateOnly>> monthEntryDates(DateTime month) async {
    monthEntryDatesCalls++;
    final DateTime key = _monthKey(month);
    monthEntryDateMonths.add(key);
    return monthDatesByMonth[key] ?? const <DateOnly>[];
  }

  @override
  Future<List<TagCatalogItem>> listTagCatalog() async => tagCatalog;
}
