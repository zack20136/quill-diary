import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/database/index_database_connection_io.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/database/index_key_derivation.dart';
import '../../helpers/vault/test_vault_path_strategy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('openIndexConnection 使用正確 key 可成功查詢', () async {
    final Directory dir = Directory.systemTemp.createTempSync(
      'qld_idx_good_key',
    );
    try {
      final String dbPath = p.join(dir.path, 'journal_index.sqlite');
      final TmpIndexPathStrategy strategy = TmpIndexPathStrategy(dbPath);
      final List<int> goodKey = List<int>.generate(32, (int i) => i);

      final IndexDatabase opened = IndexDatabase(
        await openIndexConnection(
          pathStrategy: strategy,
          encryptionKeyBytes: goodKey,
        ),
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
    final Directory dir = Directory.systemTemp.createTempSync(
      'qld_idx_wrong_key',
    );
    try {
      final String dbPath = p.join(dir.path, 'journal_index.sqlite');
      final TmpIndexPathStrategy strategy = TmpIndexPathStrategy(dbPath);

      final List<int> goodKey = List<int>.generate(32, (int i) => i);
      final List<int> badKey = List<int>.generate(32, (int i) => 255 - i);

      final IndexDatabase opened = IndexDatabase(
        await openIndexConnection(
          pathStrategy: strategy,
          encryptionKeyBytes: goodKey,
        ),
      );
      await opened.customStatement('SELECT 1');
      await opened.close();

      final IndexDatabase replay = IndexDatabase(
        await openIndexConnection(
          pathStrategy: strategy,
          encryptionKeyBytes: badKey,
        ),
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

      expect(captured, isNotNull, reason: '錯誤金鑰不應能成功查詢已加密的索引檔');
    } finally {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    }
  });

  test('IndexDatabaseManager.openForSession 可初始化加密索引', () async {
    final Directory dir = await Directory.systemTemp.createTemp(
      'qld_idx_manager',
    );
    try {
      final TestVaultPathStrategy pathStrategy = TestVaultPathStrategy(dir);
      final IndexDatabaseManager manager = IndexDatabaseManager(pathStrategy);
      const String vaultId = 'vlt_index_mgr';
      final List<int> recoveryWrapKey = List<int>.generate(
        32,
        (int i) => i + 10,
      );
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

  test('IndexDatabaseManager 會升級 1.0.0+14 索引且保留既有資料', () async {
    final Directory dir = await Directory.systemTemp.createTemp(
      'qld_idx_legacy_upgrade',
    );
    try {
      final TestVaultPathStrategy pathStrategy = TestVaultPathStrategy(dir);
      const String vaultId = 'vlt_legacy_upgrade';
      final List<int> recoveryWrapKey = List<int>.generate(
        32,
        (int index) => index + 20,
      );
      final List<int> indexKey = await deriveIndexDatabaseKey(
        recoveryWrapKey: recoveryWrapKey,
        vaultId: vaultId,
      );
      final IndexDatabase legacyDatabase = IndexDatabase(
        await openIndexConnection(
          pathStrategy: pathStrategy,
          encryptionKeyBytes: indexKey,
        ),
      );
      await legacyDatabase.customStatement('''
        CREATE TABLE entries_index (
          id TEXT PRIMARY KEY,
          vault_id TEXT NOT NULL,
          file_path TEXT NOT NULL,
          title TEXT,
          title_search_text TEXT,
          preview_text TEXT,
          body_search_text TEXT,
          date TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          word_count INTEGER NOT NULL DEFAULT 0,
          char_count INTEGER NOT NULL DEFAULT 0,
          attachment_count INTEGER NOT NULL DEFAULT 0,
          has_attachments INTEGER NOT NULL DEFAULT 0,
          encrypted_file_size INTEGER,
          encrypted_file_mtime TEXT,
          content_hash TEXT,
          preview_markdown TEXT
        );
      ''');
      await legacyDatabase.customStatement(
        '''
          INSERT INTO entries_index (
            id, vault_id, file_path, title, title_search_text, preview_text,
            body_search_text, preview_markdown, date, created_at, updated_at,
            word_count, char_count, attachment_count, has_attachments,
            content_hash
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        <Object?>[
          'ent_legacy',
          vaultId,
          'entries/2026/06/ent_legacy.md.enc',
          '舊版日記',
          '舊版日記',
          '既有預覽',
          '既有正文',
          '既有 **Markdown**',
          '2026-06-01',
          '2026-06-01T08:00:00.000Z',
          '2026-06-01T08:00:00.000Z',
          4,
          12,
          0,
          0,
          'legacy-content-hash',
        ],
      );
      await legacyDatabase.close();

      final IndexDatabaseManager manager = IndexDatabaseManager(pathStrategy);
      final IndexDatabase upgraded = await manager.openForSession(
        UnlockedVaultSession(
          vaultId: vaultId,
          trustedDevice: true,
          recoveryWrapKey: recoveryWrapKey,
          deviceSlotId: 'dev_legacy_upgrade',
        ),
      );

      final Set<String> columns =
          (await upgraded
                  .customSelect('PRAGMA table_info(entries_index);')
                  .get())
              .map((row) => row.read<String>('name'))
              .toSet();
      final Set<String> tables =
          (await upgraded
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type = 'table';",
                  )
                  .get())
              .map((row) => row.read<String>('name'))
              .toSet();
      final row = await upgraded
          .customSelect('SELECT title, content_hash FROM entries_index;')
          .getSingleOrNull();

      expect(columns, contains('body_visible_text'));
      expect(tables, contains('entry_people_analytics'));
      expect(tables, contains('people_analysis_documents'));
      expect(row?.read<String>('title'), '舊版日記');
      expect(row?.read<String>('content_hash'), 'legacy-content-hash');

      await manager.close();
    } finally {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }
  });

  test('IndexDatabaseManager 會序列化同一 vault 的並行開啟', () async {
    final Directory dir = await Directory.systemTemp.createTemp(
      'qld_idx_parallel',
    );
    try {
      final IndexDatabaseManager manager = IndexDatabaseManager(
        TestVaultPathStrategy(dir),
      );
      final UnlockedVaultSession session = UnlockedVaultSession(
        vaultId: 'vlt_parallel',
        trustedDevice: true,
        recoveryWrapKey: List<int>.generate(32, (int index) => index + 1),
        deviceSlotId: 'dev_test',
      );

      final List<IndexDatabase> databases =
          await Future.wait(<Future<IndexDatabase>>[
            manager.openForSession(session),
            manager.openForSession(session),
            manager.openForSession(session),
          ]);

      expect(identical(databases[0], databases[1]), isTrue);
      expect(identical(databases[1], databases[2]), isTrue);
      await manager.close();
    } finally {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }
  });

  test('IndexDatabaseManager.openForSession 遇到損壞索引檔時自動重建', () async {
    final Directory dir = await Directory.systemTemp.createTemp(
      'qld_idx_corrupt',
    );
    try {
      final TestVaultPathStrategy pathStrategy = TestVaultPathStrategy(dir);
      final String dbPath = await pathStrategy.indexDatabasePath();
      await File(dbPath).parent.create(recursive: true);
      await File(dbPath).writeAsBytes(<int>[0, 1, 2, 3, 4, 5]);

      final IndexDatabaseManager manager = IndexDatabaseManager(pathStrategy);
      const String vaultId = 'vlt_index_corrupt';
      final List<int> recoveryWrapKey = List<int>.generate(
        32,
        (int i) => i + 3,
      );
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
