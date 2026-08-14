import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/storage/tag_styles_store.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';

import '../../helpers/vault/vault_test_harness.dart';

const List<int> _defaultPresetIndexes = <int>[
  18,
  1,
  10,
  13,
  15,
  5,
  12,
  0,
  19,
  8,
  17,
  4,
  9,
  6,
];

void main() {
  test('繁中與英文預設標籤使用指定共用 preset 且不是自訂色', () {
    final List<int> expectedAccents = _defaultPresetIndexes
        .map((int index) => colorArgb32(kAccentColorPresets[index]))
        .toList(growable: false);

    for (final Locale locale in <Locale>[appZhLocale, appEnLocale]) {
      final List<TagCatalogItem> catalog = defaultTagCatalogForLocale(locale);

      expect(
        catalog.map((TagCatalogItem item) => item.label),
        localizedDefaultTagLabels(lookupAppLocalizations(locale)),
      );
      expect(
        catalog.map((TagCatalogItem item) => item.accentArgb),
        expectedAccents,
      );
      expect(
        catalog.map((TagCatalogItem item) => item.accentIsCustom),
        everyElement(isFalse),
      );
    }
  });

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
      locale: appZhLocale,
    );

    expect(seeded, isFalse);
    final TagCatalogItem existing = (await harness.repository.listTagCatalog())
        .single;
    expect(existing.label, '既有標籤');
    expect(existing.accentArgb, 0xFF123456);
    expect(existing.accentIsCustom, isTrue);
  });
}
