import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/diary/diary_entry_providers.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

import '../../helpers/presentation/home/home_test_helpers.dart';
import '../../helpers/shared/entry_index_fixtures.dart';
import '../../helpers/vault/fake_entry_index_vault_repository.dart';

void main() {
  group('homeEntryIndexListProvider', () {
    late FakeEntryIndexVaultRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeEntryIndexVaultRepository(
        allEntries: <DiaryEntrySummary>[
          buildDiaryEntrySummary(id: 'jrn_RESTORED'),
        ],
        searchResponses: const <String, List<DiaryEntrySummary>>{
          'query-miss': <DiaryEntrySummary>[],
        },
      );
      container = buildUnlockedHomeContainer(repository);
    });

    tearDown(() {
      container.dispose();
    });

    test('快取為空時仍會回頭查 vault 取得最新索引', () async {
      final ProviderContainer staleCacheContainer = buildUnlockedHomeContainer(
        repository,
        overrides: [
          allDiaryEntrySummariesProvider.overrideWith(
            (Ref ref) async => const <DiaryEntrySummary>[],
          ),
        ],
      );
      addTearDown(staleCacheContainer.dispose);

      final HomeEntryQueryResult result = await staleCacheContainer.read(
        homeEntryIndexListProvider.future,
      );
      final List<DiaryEntrySummary> entries = result.entries;

      expect(entries, hasLength(1));
      expect(entries.first.id, 'jrn_RESTORED');
      expect(repository.listEntriesSearchQueries.last, isNull);
    });

    test('entryIndexRevision 更新後會重新抓取索引', () async {
      await container.read(allDiaryEntrySummariesProvider.future);
      repository.allEntries = <DiaryEntrySummary>[
        buildDiaryEntrySummary(id: 'jrn_AFTER_BUMP'),
      ];

      container.read(diaryRevisionProvider.notifier).bump();

      final List<DiaryEntrySummary> entries = await container.read(
        allDiaryEntrySummariesProvider.future,
      );

      expect(entries, hasLength(1));
      expect(entries.first.id, 'jrn_AFTER_BUMP');
    });
  });

  group('indexQueryableVaultSessionProvider', () {
    late FakeEntryIndexVaultRepository repository;
    late MutableHomeTestAppSession sessionController;
    late ProviderContainer container;

    setUp(() {
      repository = FakeEntryIndexVaultRepository(
        allEntries: <DiaryEntrySummary>[buildDiaryEntrySummary(id: 'jrn_HELD')],
      );
      final UnlockedVaultSession session = UnlockedVaultSession(
        vaultId: 'vlt_unlocking_hold_test',
        trustedDevice: true,
        recoveryWrapKey: const <int>[1, 2, 3],
      );
      sessionController = MutableHomeTestAppSession(
        AppSessionState(status: AppLockStatus.unlocked, session: session),
      );
      container = buildMutableHomeContainer(
        repository: repository,
        sessionController: sessionController,
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('轉入 unlocking 期間仍保留上一個可查詢 session', () async {
      final List<DiaryEntrySummary> before = (await container.read(
        homeEntryIndexListProvider.future,
      )).entries;
      expect(before, hasLength(1));

      sessionController.adopt(
        const AppSessionState(status: AppLockStatus.unlocking),
      );

      expect(container.read(indexQueryableVaultSessionProvider), isNotNull);
      final List<DiaryEntrySummary> duringUnlocking = (await container.read(
        homeEntryIndexListProvider.future,
      )).entries;
      expect(duringUnlocking, hasLength(1));
    });
  });

  group('日曆索引查詢', () {
    test('日期邊界保留基準範圍外的既有日記', () async {
      final FakeEntryIndexVaultRepository repository =
          FakeEntryIndexVaultRepository(
            allEntries: <DiaryEntrySummary>[
              buildDiaryEntrySummary(
                id: 'legacy',
                date: const DateOnly('1988-02-29'),
              ),
              buildDiaryEntrySummary(
                id: 'future',
                date: const DateOnly('2035-06-01'),
              ),
            ],
          );
      final ProviderContainer container = buildUnlockedHomeContainer(
        repository,
      );
      addTearDown(container.dispose);

      final bounds = await container.read(entryDateBoundsProvider.future);

      expect(bounds?.earliest.value, '1988-02-29');
      expect(bounds?.latest.value, '2035-06-01');
    });

    test('月份查詢使用畫面六週的起訖日期', () async {
      final FakeEntryIndexVaultRepository repository =
          FakeEntryIndexVaultRepository();
      final ProviderContainer container = buildUnlockedHomeContainer(
        repository,
      );
      addTearDown(container.dispose);
      container
          .read(calendarVisibleMonthProvider.notifier)
          .set(DateTime(2026, 8));

      await container.read(calendarGridEntriesProvider.future);

      expect(repository.listEntryDateRanges, hasLength(1));
      expect(repository.listEntryDateRanges.single.first.value, '2026-07-26');
      expect(repository.listEntryDateRanges.single.last.value, '2026-09-05');
    });
  });
}
