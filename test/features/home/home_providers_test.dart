import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/features/home/providers/home_providers.dart';
import 'package:quill_diary/features/home/state/home_state.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';

import '../../helpers/entry_index_fixtures.dart';
import '../../helpers/fake_entry_index_vault_repository.dart';
import '../../helpers/home_test_helpers.dart';

void main() {
  test('memory scope defaults to month', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(memoryScopeProvider), MemoryScope.month);
  });

  test('homeEntriesProvider 空搜尋時沿用全量索引快取並排序', () async {
    final FakeEntryIndexVaultRepository repository = FakeEntryIndexVaultRepository(
      allEntries: <EntryIndexRecord>[
        buildEntryIndexRecord(
          id: 'jrn_OLDER',
          date: const DateOnly('2026-05-19'),
          updatedAt: DateTime.parse('2026-05-19T08:00:00Z'),
        ),
        buildEntryIndexRecord(
          id: 'jrn_NEWER',
          date: const DateOnly('2026-05-20'),
          updatedAt: DateTime.parse('2026-05-20T08:00:00Z'),
        ),
      ],
    );
    final ProviderContainer container = buildUnlockedHomeContainer(repository);
    addTearDown(container.dispose);

    final List<EntryIndexRecord> allEntries =
        await container.read(allEntryIndexRecordsProvider.future);
    final List<EntryIndexRecord> homeEntries =
        await container.read(homeEntriesProvider.future);

    expect(allEntries, hasLength(2));
    expect(homeEntries.map((EntryIndexRecord entry) => entry.id), <String>[
      'jrn_NEWER',
      'jrn_OLDER',
    ]);
    expect(repository.listEntriesCalls, 1);
    expect(repository.listEntriesSearchQueries, <String?>[null]);
  });

  test('homeEntriesProvider 有搜尋字串時保留 repository 搜尋查詢', () async {
    final FakeEntryIndexVaultRepository repository = FakeEntryIndexVaultRepository(
      searchResponses: <String, List<EntryIndexRecord>>{
        '旅行': <EntryIndexRecord>[
          buildEntryIndexRecord(id: 'jrn_MATCH', title: '旅行日記'),
        ],
      },
    );
    final ProviderContainer container = buildUnlockedHomeContainer(repository);
    addTearDown(container.dispose);
    container.read(homeSearchQueryProvider.notifier).update('旅行');

    final List<EntryIndexRecord> homeEntries =
        await container.read(homeEntriesProvider.future);

    expect(homeEntries.map((EntryIndexRecord entry) => entry.id), <String>[
      'jrn_MATCH',
    ]);
    expect(repository.listEntriesCalls, 1);
    expect(repository.listEntriesSearchQueries, <String?>['旅行']);
  });

  test('日曆 provider 從 repository 取得日期與月份資料', () async {
    final FakeEntryIndexVaultRepository repository = FakeEntryIndexVaultRepository(
      entriesByDate: <DateOnly, List<EntryIndexRecord>>{
        const DateOnly('2026-05-20'): <EntryIndexRecord>[
          buildEntryIndexRecord(
            id: 'jrn_B',
            date: const DateOnly('2026-05-20'),
            updatedAt: DateTime.parse('2026-05-20T09:00:00Z'),
          ),
          buildEntryIndexRecord(
            id: 'jrn_A',
            date: const DateOnly('2026-05-20'),
            updatedAt: DateTime.parse('2026-05-20T08:00:00Z'),
          ),
        ],
      },
      monthDatesByMonth: <DateTime, List<DateOnly>>{
        DateTime(2026, 5): const <DateOnly>[DateOnly('2026-05-20')],
      },
      entriesByMonth: <DateTime, List<EntryIndexRecord>>{
        DateTime(2026, 5): <EntryIndexRecord>[
          buildEntryIndexRecord(
            id: 'jrn_B',
            date: const DateOnly('2026-05-20'),
            updatedAt: DateTime.parse('2026-05-20T09:00:00Z'),
          ),
          buildEntryIndexRecord(
            id: 'jrn_A',
            date: const DateOnly('2026-05-20'),
            updatedAt: DateTime.parse('2026-05-20T08:00:00Z'),
          ),
        ],
      },
    );
    final ProviderContainer container = buildUnlockedHomeContainer(repository);
    addTearDown(container.dispose);
    container
        .read(calendarSelectedDateProvider.notifier)
        .set(const DateOnly('2026-05-20'));
    container
        .read(calendarVisibleMonthProvider.notifier)
        .set(DateTime(2026, 5));

    final List<EntryIndexRecord> dayEntries =
        await container.read(calendarEntriesProvider.future);
    final List<DateOnly> monthDates =
        await container.read(calendarMonthEntryDatesProvider.future);
    final List<EntryIndexRecord> monthEntries =
        await container.read(calendarMonthEntriesProvider.future);

    expect(dayEntries.map((EntryIndexRecord entry) => entry.id), <String>[
      'jrn_B',
      'jrn_A',
    ]);
    expect(monthDates.map((DateOnly date) => date.value), <String>[
      '2026-05-20',
    ]);
    expect(monthEntries.map((EntryIndexRecord entry) => entry.id), <String>[
      'jrn_B',
      'jrn_A',
    ]);
    expect(repository.listEntriesCalls, 1);
    expect(repository.listEntriesDates, <DateOnly?>[const DateOnly('2026-05-20')]);
    expect(repository.monthEntryDatesCalls, 1);
    expect(repository.listEntriesForMonthCalls, 1);
  });

  test('memoryEntriesProvider 的月份範圍直接查詢 repository 月資料', () async {
    final FakeEntryIndexVaultRepository repository = FakeEntryIndexVaultRepository(
      entriesByMonth: <DateTime, List<EntryIndexRecord>>{
        DateTime(2026, 5): <EntryIndexRecord>[
          buildEntryIndexRecord(
            id: 'jrn_MAY_NEWER',
            date: const DateOnly('2026-05-21'),
            updatedAt: DateTime.parse('2026-05-21T08:00:00Z'),
          ),
          buildEntryIndexRecord(
            id: 'jrn_MAY',
            date: const DateOnly('2026-05-20'),
            updatedAt: DateTime.parse('2026-05-20T08:00:00Z'),
          ),
        ],
      },
    );
    final ProviderContainer container = buildUnlockedHomeContainer(repository);
    addTearDown(container.dispose);
    container.read(memoryScopeProvider.notifier).set(MemoryScope.month);
    container.read(memoryFocusedMonthProvider.notifier).set(DateTime(2026, 5));

    final List<EntryIndexRecord> entries =
        await container.read(memoryEntriesProvider.future);

    expect(
      entries.map((EntryIndexRecord entry) => entry.id),
      <String>['jrn_MAY_NEWER', 'jrn_MAY'],
    );
    expect(repository.listEntriesForMonthCalls, 1);
    expect(repository.listEntriesCalls, 0);
  });
}
