import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/session/session_messages.dart';
import 'package:quill_diary/infrastructure/database/index_database_errors.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('isUnreadableEncryptedIndexError 辨識 SqliteException(26)', () {
    expect(
      isUnreadableEncryptedIndexError(
        sqlite.SqliteException(
          extendedResultCode: 26,
          message: 'file is not a database',
        ),
      ),
      isTrue,
    );
    expect(
      isUnreadableEncryptedIndexError(
        StateError('SqliteException(26): file is not a database'),
      ),
      isTrue,
    );
    expect(
      isUnreadableEncryptedIndexError(StateError('other')),
      isFalse,
    );
  });

  test('friendlySessionErrorMessage 將索引讀取失敗轉成可讀訊息', () {
    expect(
      friendlySessionErrorMessage(
        sqlite.SqliteException(
          extendedResultCode: 26,
          message: 'file is not a database',
        ),
      ),
      kIndexDatabaseUnreadableMessage,
    );
  });
}
