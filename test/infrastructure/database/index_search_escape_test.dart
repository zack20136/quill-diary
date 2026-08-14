import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';

void main() {
  test('搜尋文字會跳脫 SQL LIKE 萬用字元與跳脫字元', () {
    expect(escapeSqlLikeSearchText(r'50%_done\path'), r'50\%\_done\\path');
  });
}
