import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/features/editor/providers/editor_providers.dart';
import 'package:quill_diary/features/home/providers/home_providers.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';

import '../../helpers/features/home/home_test_helpers.dart';
import '../../helpers/shared/entry_index_fixtures.dart';
import '../../helpers/vault/fake_entry_index_vault_repository.dart';

void main() {
  group('homeEntryIndexListProvider', () {
    late FakeEntryIndexVaultRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeEntryIndexVaultRepository(
        allEntries: <EntryIndexRecord>[
          buildEntryIndexRecord(id: 'jrn_RESTORED'),
        ],
        searchResponses: const <String, List<EntryIndexRecord>>{
          '不存在': <EntryIndexRecord>[],
        },
      );
      container = buildUnlockedHomeContainer(repository);
    });

    tearDown(() {
      container.dispose();
    });

    test('空搜尋直接向 vault 取列表，不受全量索引快取影響', () async {
      final ProviderContainer staleCacheContainer = buildUnlockedHomeContainer(
        repository,
        overrides: [
          allEntryIndexRecordsProvider.overrideWith(
            (Ref ref) async => const <EntryIndexRecord>[],
          ),
        ],
      );
      addTearDown(staleCacheContainer.dispose);

      final List<EntryIndexRecord> entries = await staleCacheContainer.read(
        homeEntryIndexListProvider.future,
      );

      expect(entries, hasLength(1));
      expect(entries.first.id, 'jrn_RESTORED');
      expect(repository.listEntriesSearchQueries.last, isNull);
    });

    test('entryIndexRevision 更新後會重載全量索引', () async {
      await container.read(allEntryIndexRecordsProvider.future);
      repository.allEntries = <EntryIndexRecord>[
        buildEntryIndexRecord(id: 'jrn_AFTER_BUMP'),
      ];

      container.read(entryIndexRevisionProvider.notifier).bump();

      final List<EntryIndexRecord> entries = await container.read(
        allEntryIndexRecordsProvider.future,
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
        allEntries: <EntryIndexRecord>[
          buildEntryIndexRecord(id: 'jrn_HELD'),
        ],
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

    test('unlocking 期間保留可讀 session，避免首頁索引被清空', () async {
      final List<EntryIndexRecord> before = await container.read(
        homeEntryIndexListProvider.future,
      );
      expect(before, hasLength(1));

      sessionController.adopt(
        const AppSessionState(status: AppLockStatus.unlocking),
      );

      expect(
        container.read(indexQueryableVaultSessionProvider),
        isNotNull,
      );
      final List<EntryIndexRecord> duringUnlocking = await container.read(
        homeEntryIndexListProvider.future,
      );
      expect(duringUnlocking, hasLength(1));
    });
  });
}
