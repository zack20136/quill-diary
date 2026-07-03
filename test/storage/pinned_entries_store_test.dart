import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/storage/pinned_entries_store.dart';

import '../helpers/vault/test_vault_path_strategy.dart';

void main() {
  late Directory root;
  late TestVaultPathStrategy pathStrategy;
  late PinnedEntriesStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('qld_pin_store_');
    pathStrategy = TestVaultPathStrategy(root);
    store = PinnedEntriesStore(pathStrategy);
  });

  tearDown(() async {
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  });

  test('readIds 在檔案不存在時回傳空集合', () async {
    expect(await store.readIds(), isEmpty);
  });

  test('寫入、批次更新、prune 與清空後刪檔都正常', () async {
    expect(await store.readIds(), isEmpty);

    await store.setPinnedMany(<String>[
      'entry_a',
      'entry_b',
      'entry_missing',
    ], pinned: true);
    await store.setPinnedMany(<String>['entry_a'], pinned: false);
    await store.pruneTo(<String>['entry_b']);

    expect(await store.readIds(), equals(<String>{'entry_b'}));

    final String path = await pathStrategy.pinnedEntriesPath();
    expect(File(path).existsSync(), isTrue);

    await store.setPinned('entry_b', pinned: false);

    expect(await store.readIds(), isEmpty);
    expect(File(path).existsSync(), isFalse);
  });

  test('損毀或格式不符的檔案會保留並回傳空集合', () async {
    for (final String content in <String>['{not valid json', '["entry_a"]']) {
      final String path = await pathStrategy.pinnedEntriesPath();
      await File(path).parent.create(recursive: true);
      await File(path).writeAsString(content);

      expect(await store.readIds(), isEmpty);
      expect(File(path).existsSync(), isTrue);
    }
  });

  test('writeIds 會修剪重複空白並使用原子寫入', () async {
    final String path = await pathStrategy.pinnedEntriesPath();
    await store.writeIds(<String>{' entry_a ', 'entry_b'});

    expect(File(path).existsSync(), isTrue);
    expect(await store.readIds(), equals(<String>{'entry_a', 'entry_b'}));
    expect(File('$path.tmp').existsSync(), isFalse);
  });
}
