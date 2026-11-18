import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

Future<QueryExecutor> openIndexConnection({
  required VaultPathStrategy pathStrategy,
  required List<int> encryptionKeyBytes,
}) async {
  final String dbPath = await pathStrategy.indexDatabasePath();
  final File dbFile = File(dbPath);
  await dbFile.parent.create(recursive: true);
  final String hexKey = encodeIndexKey(encryptionKeyBytes);

  return NativeDatabase.createInBackground(
    dbFile,
    setup: (sqlite.Database rawDb) {
      if (!_hasCipher(rawDb)) throw const IndexCipherUnavailableException();
      rawDb.execute("PRAGMA hexkey = '$hexKey';");
      rawDb.select('SELECT count(*) FROM sqlite_master;');
      rawDb.execute('PRAGMA foreign_keys = ON;');
    },
  );
}

String encodeIndexKey(List<int> keyBytes) =>
    keyBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

bool _hasCipher(sqlite.Database database) {
  return database.select('PRAGMA cipher;').isNotEmpty;
}

class IndexCipherUnavailableException implements Exception {
  const IndexCipherUnavailableException();
}
