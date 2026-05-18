import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_lock_diary/infrastructure/database/index_database.dart';
import 'package:quill_lock_diary/infrastructure/database/index_database_connection_io.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

class _TmpIndexPathStrategy extends VaultPathStrategy {
  _TmpIndexPathStrategy(this.absolutePath);

  final String absolutePath;

  @override
  Future<String> indexDatabasePath() async => absolutePath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  });

  test('openIndexConnection 使用錯誤 hex key 時無法讀 sqlite3mc 索引檔', () async {
    final Directory dir = Directory.systemTemp.createTempSync('qld_idx_wrong_key');
    try {
      final String dbPath = p.join(dir.path, 'journal_index.sqlite');
      final _TmpIndexPathStrategy strategy = _TmpIndexPathStrategy(dbPath);

      final List<int> goodKey = List<int>.generate(32, (int i) => i);
      final List<int> badKey = List<int>.generate(32, (int i) => 255 - i);

      final IndexDatabase opened = IndexDatabase(
        await openIndexConnection(pathStrategy: strategy, encryptionKeyBytes: goodKey),
      );
      await opened.customStatement('SELECT 1');
      await opened.close();

      final IndexDatabase replay = IndexDatabase(
        await openIndexConnection(pathStrategy: strategy, encryptionKeyBytes: badKey),
      );

      Object? captured;
      try {
        await replay.customStatement('SELECT 1');
      } on Object catch (error) {
        captured = error;
      }

      try {
        await replay.close();
      } on Object catch (_) {
        // 若開啟失敗，close 仍可能拋錯；不影響錯金鑰應查詢失敗的斷言。
      }

      expect(
        captured,
        isNotNull,
        reason: '錯誤金鑰不應能成功查詢已加密的索引檔',
      );
    } finally {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    }
  });
}
