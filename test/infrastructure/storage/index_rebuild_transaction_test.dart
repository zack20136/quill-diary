import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';

import '../../helpers/vault/vault_test_harness.dart';

void main() {
  test('索引重建 transaction 失敗時會保留原索引', () async {
    final VaultTestHarness harness = await VaultTestHarness.create();
    final IndexDatabaseManager manager = IndexDatabaseManager(
      harness.pathStrategy,
    );
    try {
      final setup = await harness.repository.setupRecoveryKey();
      await harness.saveSimpleEntry(setup, id: 'entry-before-rollback');
      await harness.repository.closeUnlockedResources();
      final IndexDatabase database = await manager.openForSession(
        setup.session,
      );

      await expectLater(
        database.transaction(() async {
          await database.rebuild();
          throw StateError('injected index rebuild failure');
        }),
        throwsStateError,
      );

      expect((await database.listEntries()).map((entry) => entry.id), <String>[
        'entry-before-rollback',
      ]);
    } finally {
      await manager.close();
      await harness.dispose();
    }
  });
}
