import 'package:drift/isolate.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class TruncatedEncryptedIndexException implements Exception {
  const TruncatedEncryptedIndexException();
}

/// SQLite3 Multiple Ciphers 無法讀取截斷、損壞或金鑰不符的索引檔。
bool isUnreadableEncryptedIndexError(Object error) {
  final cause = error is DriftRemoteException ? error.remoteCause : error;
  return cause is TruncatedEncryptedIndexException ||
      (cause is sqlite.SqliteException &&
          cause.resultCode == sqlite.SqlError.SQLITE_NOTADB);
}
