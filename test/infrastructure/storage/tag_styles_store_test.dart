import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/tag/tag_defaults.dart';
import 'package:quill_diary/domain/tag/tag.dart';
import 'package:quill_diary/infrastructure/storage/tag_styles_store.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../helpers/vault/vault_test_harness.dart';

void main() {
  test('已有標籤時不建立預設目錄也不修改既有顏色', () async {
    final VaultTestHarness harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    await harness.repository.setupRecoveryKey();
    await harness.repository.upsertTagCatalogItem(
      '既有標籤',
      accentArgb: 0xFF123456,
      accentIsCustom: true,
    );

    final bool seeded = await harness.repository.seedDefaultTagCatalogIfEmpty(
      defaultTagCatalogForLocale(appZhLocale),
    );

    expect(seeded, isFalse);
    final TagCatalogItem existing =
        (await harness.repository.listTagCatalog()).single;
    expect(existing.label, '既有標籤');
    expect(existing.accentArgb, 0xFF123456);
    expect(existing.accentIsCustom, isTrue);
  });

  test('標籤目錄損壞時保留原檔並回傳空目錄', () async {
    final VaultTestHarness harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final File file = File(await harness.pathStrategy.tagStylesPath());
    await file.parent.create(recursive: true);
    await file.writeAsString('{');

    final List<TagCatalogItem> catalog = await TagStylesStore(
      harness.pathStrategy,
    ).read();

    expect(catalog, isEmpty);
    expect(file.existsSync(), isTrue);
    expect(await file.readAsString(), '{');
  });
}
