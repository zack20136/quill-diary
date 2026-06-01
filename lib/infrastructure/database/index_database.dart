import 'dart:async';

import 'package:drift/drift.dart';

import '../../domain/attachment/asset_attachment.dart';
import '../../domain/diary/diary_entry.dart';
import '../../domain/shared/value_objects.dart';
/// Up to 5 image attachment paths for list preview strip (GROUP_CONCAT in SELECT).
const String _kPreviewImagePathsSelect = '''
  (
    SELECT GROUP_CONCAT(sfp.path, '<|>')
    FROM (
      SELECT a.file_path AS path
      FROM entry_attachments a
      WHERE a.entry_id = e.id AND a.is_deleted = 0
        AND a.mime_type LIKE 'image/%'
      ORDER BY a.created_at ASC
      LIMIT 5
    ) AS sfp
  ) AS preview_image_paths_joined''';

const String _kImageAttachmentCountSelect = '''
  (
    SELECT COUNT(*)
    FROM entry_attachments a
    WHERE a.entry_id = e.id AND a.is_deleted = 0
      AND a.mime_type LIKE 'image/%'
  ) AS image_attachment_count''';

const String _kFileAttachmentCountSelect = '''
  (
    SELECT COUNT(*)
    FROM entry_attachments a
    WHERE a.entry_id = e.id AND a.is_deleted = 0
      AND a.mime_type NOT LIKE 'image/%'
  ) AS file_attachment_count''';

class EntryIndexRecord {
  const EntryIndexRecord({
    required this.id,
    required this.vaultId,
    required this.filePath,
    required this.title,
    required this.previewText,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    required this.mood,
    required this.wordCount,
    required this.charCount,
    required this.attachmentCount,
    required this.isDeleted,
    this.imageAttachmentCount = 0,
    this.fileAttachmentCount = 0,
    this.previewImagePaths = const <String>[],
  });

  final EntryId id;
  final VaultId vaultId;
  final String filePath;
  final String? title;
  final String previewText;
  final DateOnly date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final String? mood;
  final int wordCount;
  final int charCount;
  final int attachmentCount;
  final bool isDeleted;
  final int imageAttachmentCount;
  final int fileAttachmentCount;
  final List<String> previewImagePaths;

  factory EntryIndexRecord.fromRow(QueryRow row) {
    return EntryIndexRecord(
      id: row.read<String>('id'),
      vaultId: row.read<String>('vault_id'),
      filePath: row.read<String>('file_path'),
      title: row.readNullable<String>('title'),
      previewText: row.readNullable<String>('preview_text') ?? '',
      date: DateOnly.parse(row.read<String>('date')),
      createdAt: DateTime.parse(row.read<String>('created_at')),
      updatedAt: DateTime.parse(row.read<String>('updated_at')),
      tags: _parseTags(row.readNullable<String>('tags_joined')),
      mood: row.readNullable<String>('mood'),
      wordCount: row.read<int>('word_count'),
      charCount: row.read<int>('char_count'),
      attachmentCount: row.read<int>('attachment_count'),
      isDeleted: row.read<int>('is_deleted') == 1,
      imageAttachmentCount: row.readNullable<int>('image_attachment_count') ?? 0,
      fileAttachmentCount: row.readNullable<int>('file_attachment_count') ?? 0,
      previewImagePaths: _parsePreviewPaths(row.readNullable<String>('preview_image_paths_joined')),
    );
  }

  static List<String> _parsePreviewPaths(String? joined) {
    if (joined == null || joined.isEmpty) {
      return const <String>[];
    }
    return joined.split('<|>').where((String s) => s.isNotEmpty).toList();
  }

  static List<String> _parseTags(String? joined) {
    if (joined == null || joined.isEmpty) {
      return const <String>[];
    }
    return joined.split('\n').where((String tag) => tag.isNotEmpty).toList();
  }
}

class IndexDatabase extends GeneratedDatabase {
  IndexDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  List<TableInfo<Table, Object?>> get allTables => const <TableInfo<Table, Object?>>[];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const <DatabaseSchemaEntity>[];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async => initialize(),
        onUpgrade: (Migrator m, int from, int to) async => initialize(),
        beforeOpen: (OpeningDetails details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );

  Future<void> initialize() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS entries_index (
        id TEXT PRIMARY KEY,
        vault_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        title TEXT,
        title_normalized TEXT,
        preview_text TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        mood TEXT,
        word_count INTEGER NOT NULL DEFAULT 0,
        char_count INTEGER NOT NULL DEFAULT 0,
        attachment_count INTEGER NOT NULL DEFAULT 0,
        has_attachments INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        schema_version INTEGER NOT NULL DEFAULT 1,
        encrypted_file_size INTEGER,
        encrypted_file_mtime TEXT,
        content_hash TEXT
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS entry_tags (
        entry_id TEXT NOT NULL,
        tag TEXT NOT NULL,
        tag_normalized TEXT NOT NULL,
        PRIMARY KEY (entry_id, tag_normalized)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS entry_attachments (
        id TEXT PRIMARY KEY,
        entry_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        safe_filename TEXT NOT NULL,
        width INTEGER,
        height INTEGER,
        byte_size INTEGER NOT NULL,
        sha256 TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      );
    ''');
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5(
        entry_id,
        title,
        tags,
        preview_text
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS app_kv (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS tag_styles (
        tag_normalized TEXT PRIMARY KEY,
        accent_argb INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_entries_index_active_date_updated
      ON entries_index (is_deleted, date, updated_at);
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_entry_tags_entry_id
      ON entry_tags (entry_id);
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_entry_attachments_entry_active_created
      ON entry_attachments (entry_id, is_deleted, created_at);
    ''');
  }

  Future<void> upsertEntry({
    required DiaryEntry entry,
    required String filePath,
    required String previewText,
    required String contentHash,
    required int encryptedFileSize,
    required DateTime encryptedModifiedAt,
  }) async {
    await customStatement(
      '''
        INSERT INTO entries_index (
          id, vault_id, file_path, title, title_normalized, preview_text, date,
          created_at, updated_at, mood, word_count, char_count, attachment_count,
          has_attachments, is_deleted, schema_version, encrypted_file_size,
          encrypted_file_mtime, content_hash
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          vault_id = excluded.vault_id,
          file_path = excluded.file_path,
          title = excluded.title,
          title_normalized = excluded.title_normalized,
          preview_text = excluded.preview_text,
          date = excluded.date,
          created_at = excluded.created_at,
          updated_at = excluded.updated_at,
          mood = excluded.mood,
          word_count = excluded.word_count,
          char_count = excluded.char_count,
          attachment_count = excluded.attachment_count,
          has_attachments = excluded.has_attachments,
          is_deleted = excluded.is_deleted,
          schema_version = excluded.schema_version,
          encrypted_file_size = excluded.encrypted_file_size,
          encrypted_file_mtime = excluded.encrypted_file_mtime,
          content_hash = excluded.content_hash;
      ''',
      <Object?>[
        entry.id,
        entry.vaultId,
        filePath,
        entry.normalizedTitle,
        entry.normalizedTitle == null ? null : normalizeText(entry.normalizedTitle!),
        previewText,
        entry.date.value,
        entry.createdAt.toIso8601String(),
        entry.updatedAt.toIso8601String(),
        entry.mood,
        _wordCount(entry.markdownBody),
        entry.markdownBody.runes.length,
        entry.attachmentIds.length,
        entry.attachmentIds.isEmpty ? 0 : 1,
        entry.isDeleted ? 1 : 0,
        1,
        encryptedFileSize,
        encryptedModifiedAt.toIso8601String(),
        contentHash,
      ],
    );
    await replaceTags(entry.id, entry.tags);
  }

  /// `normalizeText(tag)` → 儲存的 ARGB（與 Flutter `Color` 對應）。
  Future<Map<String, int>> fetchTagAccentArgbMap() async {
    final List<QueryRow> rows = await customSelect('SELECT tag_normalized, accent_argb FROM tag_styles;').get();
    return <String, int>{
      for (final QueryRow row in rows) row.read<String>('tag_normalized'): row.read<int>('accent_argb'),
    };
  }

  Future<void> upsertTagAccentArgb(String tag, int accentArgb) async {
    final String nk = normalizeText(tag);
    if (nk.isEmpty) {
      throw ArgumentError.value(tag, 'tag', '標籤名稱不可為空白');
    }
    await customStatement(
      '''
        INSERT INTO tag_styles (tag_normalized, accent_argb, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(tag_normalized) DO UPDATE SET
          accent_argb = excluded.accent_argb,
          updated_at = excluded.updated_at;
      ''',
      <Object?>[nk, accentArgb, DateTime.now().toIso8601String()],
    );
  }

  Future<void> deleteTagAccentArgb(String tag) async {
    final String nk = normalizeText(tag);
    if (nk.isEmpty) {
      return;
    }
    await customStatement(
      'DELETE FROM tag_styles WHERE tag_normalized = ?;',
      <Object?>[nk],
    );
  }

  Future<void> replaceTags(EntryId entryId, List<String> tags) async {
    await customStatement('DELETE FROM entry_tags WHERE entry_id = ?;', <Object?>[entryId]);
    for (final String tag in tags) {
      await customStatement(
        'INSERT INTO entry_tags (entry_id, tag, tag_normalized) VALUES (?, ?, ?);',
        <Object?>[entryId, tag, normalizeText(tag)],
      );
    }
  }

  Future<void> replaceAttachments(
    EntryId entryId,
    List<AssetAttachment> attachments,
    Map<AssetId, String> filePaths,
  ) async {
    await customStatement(
      'DELETE FROM entry_attachments WHERE entry_id = ?;',
      <Object?>[entryId],
    );
    for (final AssetAttachment attachment in attachments) {
      await customStatement(
        '''
          INSERT OR REPLACE INTO entry_attachments (
            id, entry_id, file_path, mime_type, safe_filename, width, height,
            byte_size, sha256, created_at, is_deleted
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);
        ''',
        <Object?>[
          attachment.id,
          entryId,
          filePaths[attachment.id] ?? '',
          attachment.mimeType,
          attachment.safeFilename,
          attachment.width,
          attachment.height,
          attachment.byteSize,
          attachment.sha256,
          attachment.createdAt.toIso8601String(),
        ],
      );
    }
  }

  Future<void> upsertSearchDocument({
    required DiaryEntry entry,
    required String previewText,
  }) async {
    await customStatement(
      'DELETE FROM entries_fts WHERE entry_id = ?;',
      <Object?>[entry.id],
    );
    await customStatement(
      '''
        INSERT INTO entries_fts (entry_id, title, tags, preview_text)
        VALUES (?, ?, ?, ?);
      ''',
      <Object?>[
        entry.id,
        entry.normalizedTitle ?? '',
        entry.tags.join(' '),
        previewText,
      ],
    );
  }

  Future<List<EntryIndexRecord>> listEntries({
    String? searchQuery,
    DateOnly? date,
    bool includeDeleted = false,
  }) async {
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      return searchEntries(searchQuery, includeDeleted: includeDeleted);
    }

    final List<Object?> variables = <Object?>[];
    final List<String> where = <String>[
      if (!includeDeleted) 'e.is_deleted = 0',
      if (date != null) 'e.date = ?',
    ];
    if (date != null) {
      variables.add(date.value);
    }

    final String sql = '''
        SELECT
          e.*,
          GROUP_CONCAT(t.tag, CHAR(10)) AS tags_joined,
          $_kImageAttachmentCountSelect,
          $_kFileAttachmentCountSelect,
          $_kPreviewImagePathsSelect
      FROM entries_index e
      LEFT JOIN entry_tags t ON t.entry_id = e.id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      GROUP BY e.id
      ORDER BY e.date DESC, e.updated_at DESC;
    ''';
    final List<QueryRow> rows = await customSelect(
      sql,
      variables: <Variable<Object>>[
        for (final Object? value in variables) Variable.withString(value as String),
      ],
    ).get();
    return rows.map(EntryIndexRecord.fromRow).toList();
  }

  Future<List<EntryIndexRecord>> searchEntries(
    String query, {
    bool includeDeleted = false,
  }) async {
    final String sanitized = query
        .trim()
        .replaceAll(RegExp(r'[^\w\u4e00-\u9fff\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (sanitized.isEmpty) {
      return listEntries(includeDeleted: includeDeleted);
    }

    try {
      final List<QueryRow> rows = await customSelect(
        '''
          SELECT
            e.*,
            GROUP_CONCAT(t.tag, CHAR(10)) AS tags_joined,
            $_kImageAttachmentCountSelect,
            $_kFileAttachmentCountSelect,
            $_kPreviewImagePathsSelect
          FROM entries_fts f
          JOIN entries_index e ON e.id = f.entry_id
          LEFT JOIN entry_tags t ON t.entry_id = e.id
          WHERE f.entries_fts MATCH ? ${includeDeleted ? '' : 'AND e.is_deleted = 0'}
          GROUP BY e.id
          ORDER BY e.date DESC, e.updated_at DESC;
        ''',
        variables: <Variable<Object>>[Variable.withString('$sanitized*')],
      ).get();
      return rows.map(EntryIndexRecord.fromRow).toList();
    } catch (_) {
      final String likeQuery = '%${normalizeText(query)}%';
      final List<QueryRow> rows = await customSelect(
        '''
          SELECT
            e.*,
            GROUP_CONCAT(t.tag, CHAR(10)) AS tags_joined,
            $_kImageAttachmentCountSelect,
            $_kFileAttachmentCountSelect,
            $_kPreviewImagePathsSelect
          FROM entries_index e
          LEFT JOIN entry_tags t ON t.entry_id = e.id
          WHERE (
            COALESCE(e.title_normalized, '') LIKE ? OR
            COALESCE(e.preview_text, '') LIKE ?
          ) ${includeDeleted ? '' : 'AND e.is_deleted = 0'}
          GROUP BY e.id
          ORDER BY e.date DESC, e.updated_at DESC;
        ''',
        variables: <Variable<Object>>[
          Variable.withString(likeQuery),
          Variable.withString(likeQuery),
        ],
      ).get();
      return rows.map(EntryIndexRecord.fromRow).toList();
    }
  }

  Future<EntryIndexRecord?> getEntryById(EntryId entryId) async {
    final List<QueryRow> rows = await customSelect(
      '''
        SELECT
          e.*,
          GROUP_CONCAT(t.tag, CHAR(10)) AS tags_joined,
          $_kImageAttachmentCountSelect,
          $_kFileAttachmentCountSelect,
          $_kPreviewImagePathsSelect
        FROM entries_index e
        LEFT JOIN entry_tags t ON t.entry_id = e.id
        WHERE e.id = ?
        GROUP BY e.id
        LIMIT 1;
      ''',
      variables: <Variable<Object>>[Variable.withString(entryId)],
    ).get();
    if (rows.isEmpty) {
      return null;
    }
    return EntryIndexRecord.fromRow(rows.first);
  }

  Future<List<EntryIndexRecord>> listEntriesForMonth(DateTime month) async {
    final String prefix =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    final List<QueryRow> rows = await customSelect(
      '''
        SELECT
          e.*,
          GROUP_CONCAT(t.tag, CHAR(10)) AS tags_joined,
          $_kImageAttachmentCountSelect,
          $_kFileAttachmentCountSelect,
          $_kPreviewImagePathsSelect
        FROM entries_index e
        LEFT JOIN entry_tags t ON t.entry_id = e.id
        WHERE e.date LIKE ? AND e.is_deleted = 0
        GROUP BY e.id
        ORDER BY e.date ASC, e.updated_at DESC;
      ''',
      variables: <Variable<Object>>[Variable.withString('$prefix%')],
    ).get();
    return rows.map(EntryIndexRecord.fromRow).toList();
  }

  Future<List<DateOnly>> monthEntryDates(DateTime month) async {
    final String prefix = '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    final List<QueryRow> rows = await customSelect(
      '''
        SELECT DISTINCT date
        FROM entries_index
        WHERE date LIKE ? AND is_deleted = 0
        ORDER BY date ASC;
      ''',
      variables: <Variable<Object>>[Variable.withString('$prefix%')],
    ).get();
    return rows.map((QueryRow row) => DateOnly.parse(row.read<String>('date'))).toList();
  }

  Future<List<AssetAttachment>> attachmentsForEntry(EntryId entryId) async {
    final List<QueryRow> rows = await customSelect(
      '''
        SELECT *
        FROM entry_attachments
        WHERE entry_id = ? AND is_deleted = 0
        ORDER BY created_at ASC;
      ''',
      variables: <Variable<Object>>[Variable.withString(entryId)],
    ).get();
    return rows
        .map(
          (QueryRow row) => AssetAttachment(
            id: row.read<String>('id'),
            entryId: row.read<String>('entry_id'),
            mimeType: row.read<String>('mime_type'),
            safeFilename: row.read<String>('safe_filename'),
            byteSize: row.read<int>('byte_size'),
            createdAt: DateTime.parse(row.read<String>('created_at')),
            sha256: row.read<String>('sha256'),
            width: row.readNullable<int>('width'),
            height: row.readNullable<int>('height'),
          ),
        )
        .toList();
  }

  Future<void> markEntryDeleted(EntryId entryId) async {
    await customStatement(
      'UPDATE entries_index SET is_deleted = 1 WHERE id = ?;',
      <Object?>[entryId],
    );
  }

  Future<void> clearForRebuild() async {
    await customStatement('DELETE FROM entries_index;');
    await customStatement('DELETE FROM entry_tags;');
    await customStatement('DELETE FROM entry_attachments;');
    await customStatement('DELETE FROM entries_fts;');
  }

  Future<void> rebuild() async {
    await clearForRebuild();
  }

  Future<void> setAppValue(String key, String value) async {
    await customStatement(
      '''
        INSERT INTO app_kv (key, value, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(key) DO UPDATE SET
          value = excluded.value,
          updated_at = excluded.updated_at;
      ''',
      <Object?>[key, value, DateTime.now().toIso8601String()],
    );
  }

  Future<String?> getAppValue(String key) async {
    final List<QueryRow> rows = await customSelect(
      'SELECT value FROM app_kv WHERE key = ? LIMIT 1;',
      variables: <Variable<Object>>[Variable.withString(key)],
    ).get();
    if (rows.isEmpty) {
      return null;
    }
    return rows.first.read<String>('value');
  }

  Future<void> deleteAppValue(String key) async {
    await customStatement(
      'DELETE FROM app_kv WHERE key = ?;',
      <Object?>[key],
    );
  }

  int _wordCount(String markdown) {
    final List<String> words = markdown
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .split(' ')
        .where((String token) => token.isNotEmpty)
        .toList();
    return words.isEmpty ? 0 : words.length;
  }
}
