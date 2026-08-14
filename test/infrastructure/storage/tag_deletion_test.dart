import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/storage/tag_styles_store.dart';

import '../../helpers/vault/vault_test_harness.dart';

void main() {
  test('刪除標籤會同步從加密日記、索引與標籤目錄移除', () async {
    final VaultTestHarness harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final String entryId = await harness.saveSimpleEntry(
      setup,
      tags: const <String>['工作', '保留'],
    );
    await harness.repository.upsertTagCatalogItem('工作');
    await harness.repository.upsertTagCatalogItem('保留');

    final int updated = await harness.repository.removeTagFromAllEntries(
      setup.session,
      '工作',
    );

    expect(updated, 1);
    expect(
      (await harness.repository.loadEntry(setup.session, entryId))!.tags,
      <String>['保留'],
    );
    expect((await harness.repository.listEntries()).single.tags, <String>[
      '保留',
    ]);
    expect(
      (await harness.repository.listTagCatalog()).map(
        (TagCatalogItem item) => item.label,
      ),
      <String>['保留'],
    );
  });
}
