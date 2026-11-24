import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';

enum _Phase {
  prepared('PREPARED'),
  switching('SWITCHING'),
  committed('COMMITTED'),
  cleanupPending('CLEANUP_PENDING');

  const _Phase(this.label);
  final String label;
}

class VaultRestoreTransaction {
  VaultRestoreTransaction(this.root);

  static const _storage = MethodChannel('quill_diary/restore_storage');
  static const _directories = ['vault', 'index', 'drafts'];

  final Directory root;
  Directory get _work => Directory(p.join(root.path, '.restore'));
  Directory get candidate => Directory(p.join(_work.path, 'candidate'));
  File get _journal => File(p.join(_work.path, 'transaction.json'));
  Future<bool> hasPendingWork() => _work.exists();
  Directory _live(String name) => Directory(p.join(root.path, name));
  Directory _old(String name) => Directory(p.join(_work.path, 'old_$name'));
  Directory _new(String name) => Directory(p.join(candidate.path, name));

  static Future<VaultRestoreTransaction> forPaths(
    VaultPathStrategy paths,
  ) async => VaultRestoreTransaction(await paths.appRootDirectory());

  Future<void> prepare() async {
    await recover();
    if (await hasPendingWork()) {
      throw FileSystemException('前次還原的舊資料尚待清理。', _work.path);
    }
    await root.create(recursive: true);
    await _work.create();
    await _sync(root);
    await candidate.create();
    await _write(_Phase.prepared, {});
  }

  Future<void> checkSpace(int requiredBytes) async {
    if (!Platform.isAndroid) return;
    final bytes = await _storage.invokeMethod<int>('availableBytes', root.path);
    if (bytes == null || bytes < requiredBytes) {
      throw FileSystemException('日記庫還原的可用空間不足。', root.path);
    }
  }

  Future<void> commit({
    required Future<void> Function() openRestoredVault,
    required Future<void> Function() closeRestoredVault,
  }) async {
    final originals = {
      for (final name in _directories)
        if (await _live(name).exists()) name,
    };
    var writingCommit = false;
    var openingRestoredVault = false;
    try {
      await _sync(candidate, tree: true);
      await _write(_Phase.switching, originals);
      for (final name in _directories) {
        if (originals.contains(name)) {
          await _rename(_live(name), _old(name));
        }
        await _rename(_new(name), _live(name));
      }
      openingRestoredVault = true;
      await openRestoredVault();
      await _sync(_live('index'), tree: true);
      writingCommit = true;
      await _write(_Phase.committed, originals);
    } on Object {
      if (writingCommit) await _write(_Phase.switching, originals);
      if (openingRestoredVault) await closeRestoredVault();
      await _rollback(originals);
      rethrow;
    }
    await _cleanup(originals);
  }

  Future<void> recover() async {
    final kind = await FileSystemEntity.type(_work.path, followLinks: false);
    if (kind == FileSystemEntityType.notFound) return;
    if (kind != FileSystemEntityType.directory) {
      throw FileSystemException('還原交易目錄無效。', _work.path);
    }
    await recoverFileReplacement(_journal);
    if (!await _journal.exists()) {
      if (await _work
          .list(followLinks: false)
          .any((entity) => p.basename(entity.path).startsWith('old_'))) {
        throw FileSystemException('缺少還原交易紀錄。', _work.path);
      }
      await _discardWork();
      return;
    }
    final record = jsonDecode(await _journal.readAsString()) as Map;
    final phase = _Phase.values.firstWhere(
      (phase) => phase.label == record['phase'],
    );
    final originals = (record['originals'] as List).cast<String>().toSet();
    if (!originals.every(_directories.contains)) {
      throw const FormatException('還原交易紀錄無效。');
    }
    switch (phase) {
      case _Phase.prepared:
        await _discardWork();
      case _Phase.switching:
        await _rollback(originals);
      case _Phase.committed:
      case _Phase.cleanupPending:
        await _cleanup(originals);
    }
  }

  Future<void> _rollback(Set<String> originals) async {
    for (final name in _directories.reversed) {
      final live = _live(name);
      final old = _old(name);
      final next = _new(name);
      if (await old.exists()) {
        if (await live.exists()) {
          if (await next.exists()) {
            throw FileSystemException('日記庫替換狀態不一致。', live.path);
          }
          await _rename(live, next);
        }
        await _rename(old, live);
      } else if (originals.contains(name)) {
        if (!await live.exists() || !await next.exists()) {
          throw FileSystemException('找不到原始日記庫資料。', live.path);
        }
      } else if (!await next.exists() && await live.exists()) {
        await _rename(live, next);
      }
    }
    await _write(_Phase.prepared, {});
    await _discardWork();
  }

  Future<void> _cleanup(Set<String> originals) async {
    try {
      await _write(_Phase.cleanupPending, originals);
      for (final name in _directories) {
        final old = _old(name);
        if (await old.exists()) await old.delete(recursive: true);
      }
      await _discardWork();
    } on Exception catch (error) {
      if (error is! FileSystemException && error is! PlatformException) rethrow;
      // 已提交的還原可使用，舊資料留到下次啟動清理。
    }
  }

  Future<void> _discardWork() async {
    if (await candidate.exists()) await candidate.delete(recursive: true);
    if (await _journal.exists()) await _journal.delete();
    await _work.delete();
    await _sync(root);
  }

  Future<void> _write(_Phase phase, Set<String> originals) async {
    await atomicWriteString(
      _journal,
      jsonEncode({'phase': phase.label, 'originals': originals.toList()}),
    );
    await _sync(_work);
  }

  Future<void> _rename(Directory source, Directory destination) async {
    await source.rename(destination.path);
    await _sync(source.parent);
    if (!p.equals(source.parent.path, destination.parent.path)) {
      await _sync(destination.parent);
    }
  }

  Future<void> _sync(Directory directory, {bool tree = false}) async {
    if (!Platform.isAndroid) return;
    await _storage.invokeMethod<void>(
      tree ? 'syncTree' : 'syncDirectory',
      directory.path,
    );
  }
}
