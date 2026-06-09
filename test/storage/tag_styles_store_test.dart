import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/tag_styles_store.dart';

import '../helpers/test_vault_path_strategy.dart';

void main() {
  late Directory tempDir;
  late TagStylesStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qld_tag_styles_test_');
    store = TagStylesStore(TestVaultPathStrategy(tempDir));
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('read 空檔案時回傳空目錄', () async {
    expect(await store.read(), isEmpty);
  });

  test('write 後可 round-trip 讀回 v1 標籤目錄', () async {
    await store.write(
      const <TagCatalogItem>[
        TagCatalogItem(label: '工作', accentArgb: 0xFF4C6EF5),
        TagCatalogItem(label: '日常', accentArgb: 0xFF51CF66),
      ],
    );

    final List<TagCatalogItem> loaded = await store.read();
    expect(loaded.map((TagCatalogItem item) => item.label), <String>['工作', '日常']);
    expect(TagStylesStore.toAccentMap(loaded), <String, int>{
      normalizeText('工作'): 0xFF4C6EF5,
      normalizeText('日常'): 0xFF51CF66,
    });

    final Directory vaultRoot = Directory('${tempDir.path}${Platform.pathSeparator}vault');
    final File file = File('${vaultRoot.path}${Platform.pathSeparator}tag_styles.json');
    final Object? decoded = jsonDecode(await file.readAsString());
    expect(decoded, isA<Map<String, Object?>>());
    expect((decoded as Map<String, Object?>)['version'], TagStylesStore.schemaVersion);
    expect(decoded['tags'], isA<List<Object?>>());
  });

  test('merge 以 normalized key 覆蓋並保留順序', () {
    final List<TagCatalogItem> merged = TagStylesStore.merge(
      const <TagCatalogItem>[
        TagCatalogItem(label: '工作', accentArgb: 1),
        TagCatalogItem(label: '生活', accentArgb: 2),
      ],
      const <TagCatalogItem>[
        TagCatalogItem(label: '工作 ', accentArgb: 9),
        TagCatalogItem(label: '旅遊', accentArgb: 3),
      ],
    );

    expect(
      merged
          .map((TagCatalogItem item) => <Object?>[item.label, item.accentArgb])
          .toList(),
      <List<Object?>>[
        <Object?>['工作', 9],
        <Object?>['生活', 2],
        <Object?>['旅遊', 3],
      ],
    );
  });
}
