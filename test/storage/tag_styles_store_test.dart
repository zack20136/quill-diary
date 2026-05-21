import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/infrastructure/storage/tag_styles_store.dart';

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

  test('read 空檔案回傳空 map', () async {
    expect(await store.read(), isEmpty);
  });

  test('write 與 read 往返', () async {
    await store.write(<String, int>{
      'work': 0xFF4C6EF5,
      'life': 0xFF51CF66,
    });
    final Map<String, int> loaded = await store.read();
    expect(loaded['work'], 0xFF4C6EF5);
    expect(loaded['life'], 0xFF51CF66);
  });

  test('merge 後者覆寫前者', () {
    final Map<String, int> merged = TagStylesStore.merge(
      <String, int>{'a': 1, 'b': 2},
      <String, int>{'b': 9, 'c': 3},
    );
    expect(merged, <String, int>{'a': 1, 'b': 9, 'c': 3});
  });
}
