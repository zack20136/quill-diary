import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/database/index_database_connection_io.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/database/index_key_derivation.dart';
import '../helpers/test_vault_path_strategy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('openIndexConnection 使用正確 key 可成功查詢', () async {
    final Directory dir = Directory.systemTemp.createTempSync('qld_idx_good_key');
    try {
      final String dbPath = p.join(dir.path, 'journal_index.sqlite');
      final TmpIndexPathStrategy strategy = TmpIndexPathStrategy(dbPath);
      final List<int> goodKey = List<int>.generate(32, (int i) => i);

      final IndexDatabase opened = IndexDatabase(
        await openIndexConnection(pathStrategy: strategy, encryptionKeyBytes: goodKey),
      );
      await opened.customStatement('SELECT 1');
      await opened.close();
    } finally {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    }
  });

  test('openIndexConnection 使用錯誤 hex key 時無法讀 sqlite3mc 索引檔', () async {
    final Directory dir = Directory.systemTemp.createTempSync('qld_idx_wrong_key');
    try {
      final String dbPath = p.join(dir.path, 'journal_index.sqlite');
      final TmpIndexPathStrategy strategy = TmpIndexPathStrategy(dbPath);

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

  test('IndexDatabaseManager.openForSession 可初始化加密索引', () async {
    final Directory dir = await Directory.systemTemp.createTemp('qld_idx_manager');
    try {
      final TestVaultPathStrategy pathStrategy = TestVaultPathStrategy(dir);
      final IndexDatabaseManager manager = IndexDatabaseManager(pathStrategy);
      const String vaultId = 'vlt_index_mgr';
      final List<int> recoveryWrapKey = List<int>.generate(32, (int i) => i + 10);
      final List<int> indexKey = await deriveIndexDatabaseKey(
        recoveryWrapKey: recoveryWrapKey,
        vaultId: vaultId,
      );
      expect(indexKey, hasLength(32));

      final UnlockedVaultSession session = UnlockedVaultSession(
        vaultId: vaultId,
        trustedDevice: true,
        recoveryWrapKey: recoveryWrapKey,
        deviceSlotId: 'dev_test',
      );

      final IndexDatabase database = await manager.openForSession(session);
      await database.initialize();
      await database.customStatement('SELECT 1');
      expect(manager.isOpen, isTrue);

      await manager.close();
      expect(manager.isOpen, isFalse);
    } finally {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }
  });

  test('IndexDatabaseManager.openForSession 遇到損壞索引檔時自動重建', () async {
    final Directory dir = await Directory.systemTemp.createTemp('qld_idx_corrupt');
    try {
      final TestVaultPathStrategy pathStrategy = TestVaultPathStrategy(dir);
      final String dbPath = await pathStrategy.indexDatabasePath();
      await File(dbPath).parent.create(recursive: true);
      await File(dbPath).writeAsBytes(<int>[0, 1, 2, 3, 4, 5]);

      final IndexDatabaseManager manager = IndexDatabaseManager(pathStrategy);
      const String vaultId = 'vlt_index_corrupt';
      final List<int> recoveryWrapKey = List<int>.generate(32, (int i) => i + 3);
      final UnlockedVaultSession session = UnlockedVaultSession(
        vaultId: vaultId,
        trustedDevice: true,
        recoveryWrapKey: recoveryWrapKey,
        deviceSlotId: 'dev_test',
      );

      final IndexDatabase database = await manager.openForSession(session);
      await database.customStatement('SELECT 1');
      expect(manager.isOpen, isTrue);

      await manager.close();
    } finally {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }
  });
}
