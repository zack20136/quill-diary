import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../storage/vault_path_strategy.dart';

Future<QueryExecutor> openIndexConnection({
  required VaultPathStrategy pathStrategy,
  required List<int> encryptionKeyBytes,
}) async {
  final String dbPath = await pathStrategy.indexDatabasePath();
  final File dbFile = File(dbPath);
  await dbFile.parent.create(recursive: true);
  final String hexKey = encryptionKeyBytes
      .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();

  return NativeDatabase.createInBackground(
    dbFile,
    setup: (sqlite.Database rawDb) {
      assert(_debugCheckHasCipher(rawDb));
      rawDb.execute("PRAGMA hexkey = '$hexKey';");
      rawDb.select('SELECT count(*) FROM sqlite_master;');
      rawDb.execute('PRAGMA foreign_keys = ON;');
    },
  );
}

bool _debugCheckHasCipher(sqlite.Database database) {
  return database.select('PRAGMA cipher;').isNotEmpty;
}
