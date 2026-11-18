import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/database/index_database_connection_io.dart';
import 'package:quill_diary/infrastructure/database/index_database_errors.dart';
import 'package:quill_diary/infrastructure/database/index_key_derivation.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';

class IndexDatabaseManager {
  IndexDatabaseManager(this._pathStrategy);

  final VaultPathStrategy _pathStrategy;

  IndexDatabase? _database;
  String? _openVaultId;
  List<int>? _openKey;
  Future<void> _operationTail = Future<void>.value();

  bool get isOpen => _database != null;

  IndexDatabase requireOpen() {
    final IndexDatabase? database = _database;
    if (database == null) {
      throw StateError('索引資料庫尚未開啟。');
    }
    return database;
  }

  Future<IndexDatabase> openForSession(
    UnlockedVaultSession session, {
    List<int>? interruptedRotationWrapKey,
  }) => _serialize(
    () => _openForSessionNow(
      session,
      interruptedRotationWrapKey: interruptedRotationWrapKey,
    ),
  );

  Future<IndexDatabase> _openForSessionNow(
    UnlockedVaultSession session, {
    List<int>? interruptedRotationWrapKey,
  }) async {
    final List<int> key = await _deriveKey(session);
    if (_database != null &&
        _openVaultId == session.vaultId &&
        listEquals(_openKey, key)) {
      return _database!;
    }

    await _closeNow();
    final String path = await _pathStrategy.indexDatabasePath();
    if (!File(path).existsSync()) await _deleteSidecars(path);
    try {
      return await _connectAndInitialize(session: session, keyBytes: key);
    } on Object catch (error) {
      if (!isUnreadableEncryptedIndexError(error)) {
        rethrow;
      }
      if (interruptedRotationWrapKey != null) {
        final IndexDatabase? recovered = await _recoverRotatedIndex(
          session,
          key,
          interruptedRotationWrapKey,
        );
        if (recovered != null) return recovered;
      }
      await _deleteDatabaseFilesNow();
      return await _connectAndInitialize(session: session, keyBytes: key);
    }
  }

  Future<IndexDatabase?> _recoverRotatedIndex(
    UnlockedVaultSession session,
    List<int> restoredIndexKey,
    List<int> interruptedRotationWrapKey,
  ) async {
    final List<int> rotatedIndexKey = await deriveIndexDatabaseKey(
      recoveryWrapKey: interruptedRotationWrapKey,
      vaultId: session.vaultId,
    );
    final IndexDatabase database;
    try {
      database = await _connectAndInitialize(
        session: session,
        keyBytes: rotatedIndexKey,
      );
    } on Object catch (error) {
      if (!isUnreadableEncryptedIndexError(error)) rethrow;
      return null;
    }
    await _rekeyOpenDatabase(database, restoredIndexKey);
    return database;
  }

  Future<IndexDatabase> _connectAndInitialize({
    required UnlockedVaultSession session,
    required List<int> keyBytes,
  }) async {
    final executor = await openIndexConnection(
      pathStrategy: _pathStrategy,
      encryptionKeyBytes: keyBytes,
    );
    final IndexDatabase database = IndexDatabase(executor);
    try {
      await database.initialize();
      _database = database;
      _openVaultId = session.vaultId;
      _openKey = keyBytes;
      return database;
    } on Object {
      await database.close();
      rethrow;
    }
  }

  Future<List<int>> _deriveKey(UnlockedVaultSession session) =>
      deriveIndexDatabaseKey(
        recoveryWrapKey: requireRecoveryWrapKey(session),
        vaultId: session.vaultId,
      );

  Future<void> rekeyForSession(UnlockedVaultSession session) =>
      _serialize(() async {
        final IndexDatabase database = requireOpen();
        if (_openVaultId != session.vaultId) {
          throw StateError('索引與日記庫身分不符。');
        }
        await _rekeyOpenDatabase(database, await _deriveKey(session));
      });

  Future<void> _rekeyOpenDatabase(IndexDatabase database, List<int> key) async {
    if (listEquals(_openKey, key)) return;
    try {
      await database.customStatement(
        "PRAGMA hexrekey = '${encodeIndexKey(key)}';",
      );
    } on Object {
      // SQL 錯誤可能含有金鑰參數，不能交給上層記錄。
      throw StateError('索引加密金鑰變更失敗。');
    }
    _openKey = key;
  }

  Future<void> close() => _serialize(_closeNow);

  Future<void> _closeNow() async {
    final IndexDatabase? database = _database;
    _database = null;
    _openVaultId = null;
    _openKey = null;
    if (database != null) {
      await database.close();
    }
  }

  Future<void> deleteDatabaseFiles() => _serialize(_deleteDatabaseFilesNow);

  Future<void> _deleteDatabaseFilesNow() async {
    await _closeNow();
    final String path = await _pathStrategy.indexDatabasePath();
    await _deleteIfExists(File(path));
    await _deleteSidecars(path);
  }

  Future<void> _deleteSidecars(String path) async {
    for (final suffix in ['-wal', '-shm', '-journal']) {
      await _deleteIfExists(File('$path$suffix'));
    }
  }

  Future<void> _deleteIfExists(File file) async {
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final Completer<T> completer = Completer<T>();
    final Future<void> previous = _operationTail;
    _operationTail = () async {
      try {
        await previous;
      } on Object {
        // 前一項操作的錯誤已交還原呼叫端，不阻斷後續佇列。
      }
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }();
    return completer.future;
  }
}
