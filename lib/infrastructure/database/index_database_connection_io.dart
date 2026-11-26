import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:quill_diary/infrastructure/database/index_database_errors.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

const int _minimumSqlitePageSize = 512;

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
      try {
        rawDb.execute("PRAGMA hexkey = '$hexKey';");
      } on sqlite.SqliteException catch (error, stackTrace) {
        if (error.extendedResultCode ==
            sqlite.SqlExtendedError.SQLITE_IOERR_SHORT_READ) {
          final size = dbFile.statSync().size;
          if (size > 0 && size < _minimumSqlitePageSize) {
            throw const TruncatedEncryptedIndexException();
          }
        }
        // PRAGMA 的錯誤含有金鑰，保留錯誤碼但移除 SQL。
        Error.throwWithStackTrace(
          sqlite.SqliteException(
            extendedResultCode: error.extendedResultCode,
            message: '無法設定索引加密金鑰。',
            explanation: error.explanation,
          ),
          stackTrace,
        );
      }
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
