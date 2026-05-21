import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_lock_diary/domain/shared/value_objects.dart';
import 'package:quill_lock_diary/features/home/providers/home_providers.dart';
import 'package:quill_lock_diary/features/home/state/home_state.dart';
import 'package:quill_lock_diary/features/session/providers/session_providers.dart';
import 'package:quill_lock_diary/features/session/state/app_session_state.dart';
import 'package:quill_lock_diary/infrastructure/database/index_database.dart';
import 'package:quill_lock_diary/shared/providers/core_providers.dart';

import '../../helpers/entry_index_fixtures.dart';
import '../../helpers/fake_vault_repository.dart';

void main() {
  ProviderContainer buildContainer() {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  ProviderContainer buildUnlockedHomeContainer(FakeVaultRepository repository) {
    const UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: 'vlt_home_provider_test',
      trustedDevice: true,
      recoveryWrapKey: <int>[1, 2, 3],
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        vaultRepositoryProvider.overrideWithValue(repository),
        effectiveAppSessionProvider.overrideWith(
          (Ref ref) async => const AppSessionState(
            status: AppLockStatus.unlocked,
            session: session,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('enterWith 啟動多選並選中一筆', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.enterWith('entry-a');

    final HomeEntrySelectionState state = container.read(homeEntrySelectionProvider);
    expect(state.isActive, isTrue);
    expect(state.selectedIds, <String>{'entry-a'});
  });

  test('enterSelection 啟動多選但不預選', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.enterSelection();

    expect(container.read(homeEntrySelectionProvider).isActive, isTrue);
    expect(container.read(homeEntrySelectionProvider).selectedIds, isEmpty);
  });

  test('toggle 全不選時維持多選模式', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.enterWith('entry-a');
    controller.toggle('entry-a');

    expect(container.read(homeEntrySelectionProvider).isActive, isTrue);
    expect(container.read(homeEntrySelectionProvider).selectedIds, isEmpty);
  });

  test('selectAll 全選後再次呼叫會取消全選但維持多選', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.selectAll(<String>['entry-a', 'entry-b']);
    expect(container.read(homeEntrySelectionProvider).selectedIds,
        containsAll(<String>{'entry-a', 'entry-b'}));

    controller.selectAll(<String>['entry-a', 'entry-b']);
    expect(container.read(homeEntrySelectionProvider).isActive, isTrue);
    expect(container.read(homeEntrySelectionProvider).selectedIds, isEmpty);
  });

  test('clear 重置多選狀態', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.enterWith('entry-a');
    controller.clear();

    expect(container.read(homeEntrySelectionProvider), const HomeEntrySelectionState());
  });

  test('pruneToVisible 移除不在列表中的選取', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.selectAll(<String>['entry-a', 'entry-b', 'entry-c']);
    controller.pruneToVisible(<String>['entry-a', 'entry-c']);

    expect(container.read(homeEntrySelectionProvider).selectedIds,
        containsAll(<String>{'entry-a', 'entry-c'}));
    expect(container.read(homeEntrySelectionProvider).selectedIds, isNot(contains('entry-b')));
  });

  test('pruneToVisible 在全部移除時維持多選模式', () {
    final ProviderContainer container = buildContainer();
    final HomeEntrySelectionController controller =
        container.read(homeEntrySelectionProvider.notifier);

    controller.enterWith('entry-a');
    controller.pruneToVisible(<String>['entry-b']);

    expect(container.read(homeEntrySelectionProvider).isActive, isTrue);
    expect(container.read(homeEntrySelectionProvider).selectedIds, isEmpty);
  });

  test('homeEntriesProvider 空搜尋時沿用全量索引快取', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      entryIndexRecords: <EntryIndexRecord>[
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
    final FakeVaultRepository repository = FakeVaultRepository(
      entryIndexRecords: <EntryIndexRecord>[
        buildEntryIndexRecord(id: 'jrn_MATCH', title: '旅行日記'),
        buildEntryIndexRecord(id: 'jrn_OTHER', title: '工作筆記'),
      ],
    );
    final ProviderContainer container = buildUnlockedHomeContainer(repository);
    container.read(homeSearchQueryProvider.notifier).update('旅行');

    final List<EntryIndexRecord> homeEntries =
        await container.read(homeEntriesProvider.future);

    expect(homeEntries.map((EntryIndexRecord entry) => entry.id), <String>[
      'jrn_MATCH',
    ]);
    expect(repository.listEntriesCalls, 1);
    expect(repository.listEntriesSearchQueries, <String?>['旅行']);
  });

  test('日曆 provider 從全量索引派生日期與月份資料', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      entryIndexRecords: <EntryIndexRecord>[
        buildEntryIndexRecord(
          id: 'jrn_A',
          date: const DateOnly('2026-05-20'),
          updatedAt: DateTime.parse('2026-05-20T08:00:00Z'),
        ),
        buildEntryIndexRecord(
          id: 'jrn_B',
          date: const DateOnly('2026-05-20'),
          updatedAt: DateTime.parse('2026-05-20T09:00:00Z'),
        ),
        buildEntryIndexRecord(
          id: 'jrn_C',
          date: const DateOnly('2026-06-01'),
        ),
      ],
    );
    final ProviderContainer container = buildUnlockedHomeContainer(repository);
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
    expect(repository.listEntriesDates, <DateOnly?>[null]);
  });
}
