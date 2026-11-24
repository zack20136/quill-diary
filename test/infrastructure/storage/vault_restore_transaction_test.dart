import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/infrastructure/storage/portable/vault_restore_transaction.dart';

void main() {
  late Directory root;
  late VaultRestoreTransaction transaction;
  const directories = ['vault', 'index', 'drafts'];

  setUp(() async {
    root = await Directory.systemTemp.createTemp('restore_transaction_');
    transaction = VaultRestoreTransaction(root);
    await transaction.prepare();
    for (final name in directories) {
      final live = await Directory(p.join(root.path, name)).create();
      final next = await Directory(p.join(transaction.candidate.path, name))
          .create();
      await File(p.join(live.path, 'marker')).writeAsString('原始');
      await File(p.join(next.path, 'marker')).writeAsString('候選');
    }
  });

  tearDown(() => root.delete(recursive: true));

  Future<void> expectLive(String marker) async {
    for (final name in directories) {
      expect(
        await File(p.join(root.path, name, 'marker')).readAsString(),
        marker,
      );
    }
    expect(await Directory(p.join(root.path, '.restore')).exists(), isFalse);
  }

  test('新索引開啟失敗時回復原日記庫、索引與草稿', () async {
    await expectLater(
      transaction.commit(
        openRestoredVault: () async => throw StateError('新索引無法開啟'),
        closeRestoredVault: () async {},
      ),
      throwsStateError,
    );
    await expectLive('原始');
  });

  test('重啟可回復移到一半的日記庫與索引', () async {
    final work = transaction.candidate.parent;
    await File(p.join(work.path, 'transaction.json')).writeAsString(
      jsonEncode({'phase': 'SWITCHING', 'originals': directories}),
    );
    await Directory(p.join(root.path, 'vault'))
        .rename(p.join(work.path, 'old_vault'));
    await Directory(p.join(transaction.candidate.path, 'vault'))
        .rename(p.join(root.path, 'vault'));
    await Directory(p.join(root.path, 'index'))
        .rename(p.join(work.path, 'old_index'));

    await VaultRestoreTransaction(root).recover();

    await expectLive('原始');
  });

  test('重啟會清理已提交交易的舊庫副本', () async {
    final work = transaction.candidate.parent;
    await File(p.join(work.path, 'transaction.json')).writeAsString(
      jsonEncode({'phase': 'COMMITTED', 'originals': directories}),
    );
    for (final name in directories) {
      await Directory(p.join(root.path, name))
          .rename(p.join(work.path, 'old_$name'));
      await Directory(p.join(transaction.candidate.path, name))
          .rename(p.join(root.path, name));
    }

    await VaultRestoreTransaction(root).recover();

    await expectLive('候選');
  });
}
