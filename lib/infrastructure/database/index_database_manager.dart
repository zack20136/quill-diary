import 'dart:io';

import '../../domain/security/unlocked_vault_session.dart';
import '../storage/vault_path_strategy.dart';
import 'index_database.dart';
import 'index_database_connection_io.dart';
import 'index_database_errors.dart';
import 'index_key_derivation.dart';

class IndexDatabaseManager {
  IndexDatabaseManager(this._pathStrategy);

  final VaultPathStrategy _pathStrategy;

  IndexDatabase? _database;
  String? _openVaultId;

  bool get isOpen => _database != null;

  IndexDatabase requireOpen() {
    final IndexDatabase? database = _database;
    if (database == null) {
      throw StateError('索引資料庫尚未開啟。');
    }
    return database;
  }

  Future<IndexDatabase> openForSession(UnlockedVaultSession session) async {
    if (_database != null && _openVaultId == session.vaultId) {
      return _database!;
    }

    await close();

    final List<int> keyBytes = await deriveIndexDatabaseKey(
      recoveryWrapKey:
          session.recoveryWrapKey ??
          (throw StateError('目前 session 沒有可用的 Recovery wrapping key。')),
      vaultId: session.vaultId,
    );
    try {
      return await _connectAndInitialize(session: session, keyBytes: keyBytes);
    } on Object catch (error) {
      if (!isUnreadableEncryptedIndexError(error)) {
        rethrow;
      }
      await deleteDatabaseFiles();
      return await _connectAndInitialize(session: session, keyBytes: keyBytes);
    }
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
      return database;
    } on Object {
      await database.close();
      rethrow;
    }
  }

  Future<void> close() async {
    final IndexDatabase? database = _database;
    _database = null;
    _openVaultId = null;
    if (database != null) {
      await database.close();
    }
  }

  Future<void> deleteDatabaseFiles() async {
    await close();
    final String path = await _pathStrategy.indexDatabasePath();
    await _deleteIfExists(File(path));
    await _deleteIfExists(File('$path-wal'));
    await _deleteIfExists(File('$path-shm'));
    await _deleteIfExists(File('$path-journal'));
  }

  Future<void> _deleteIfExists(File file) async {
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
