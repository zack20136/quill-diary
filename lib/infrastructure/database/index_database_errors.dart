import 'package:sqlite3/sqlite3.dart' as sqlite;

/// SQLite/SQLCipher 回報索引檔無法以目前金鑰讀取（常見於損壞或金鑰不符）。
bool isUnreadableEncryptedIndexError(Object error) {
  if (error is sqlite.SqliteException) {
    return error.extendedResultCode == 26 || error.resultCode == 26;
  }
  final String text = error.toString();
  return text.contains('file is not a database') ||
      text.contains('SqliteException(26)');
}
