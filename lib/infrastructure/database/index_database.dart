import 'dart:async';

import 'package:drift/drift.dart';

import '../../domain/attachment/asset_attachment.dart';
import '../../domain/diary/diary_entry.dart';
import '../../domain/shared/value_objects.dart';

/// 日記列表預覽用的圖片附件路徑（GROUP_CONCAT 串接）。
const String _kPreviewImagePathsSelect = '''
  (
    SELECT GROUP_CONCAT(sfp.path, '<|>')
    FROM (
      SELECT a.file_path AS path
      FROM entry_attachments a
      WHERE a.entry_id = e.id
        AND a.mime_type LIKE 'image/%'
      ORDER BY a.created_at ASC
    ) AS sfp
  ) AS preview_image_paths_joined''';

const String _kImageAttachmentCountSelect = '''
  (
    SELECT COUNT(*)
    FROM entry_attachments a
    WHERE a.entry_id = e.id
      AND a.mime_type LIKE 'image/%'
  ) AS image_attachment_count''';

const String _kFileAttachmentCountSelect = '''
  (
    SELECT COUNT(*)
    FROM entry_attachments a
    WHERE a.entry_id = e.id
      AND a.mime_type NOT LIKE 'image/%'
  ) AS file_attachment_count''';

class EntryIndexRecord {
  const EntryIndexRecord({
    required this.id,
    required this.vaultId,
    required this.filePath,
    required this.title,
    required this.previewText,
    this.previewMarkdown = '',
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    required this.wordCount,
    required this.charCount,
    required this.attachmentCount,
    this.imageAttachmentCount = 0,
    this.fileAttachmentCount = 0,
    this.previewImagePaths = const <String>[],
  });

  final EntryId id;
  final VaultId vaultId;
  final String filePath;
  final String? title;
  final String previewText;
  final String previewMarkdown;
  final DateOnly date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final int wordCount;
  final int charCount;
  final int attachmentCount;
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
      previewMarkdown: row.readNullable<String>('preview_markdown') ?? '',
      date: DateOnly.parse(row.read<String>('date')),
      createdAt: DateTime.parse(row.read<String>('created_at')),
      updatedAt: DateTime.parse(row.read<String>('updated_at')),
      tags: _parseTags(row.readNullable<String>('tags_joined')),
      wordCount: row.read<int>('word_count'),
      charCount: row.read<int>('char_count'),
      attachmentCount: row.read<int>('attachment_count'),
      imageAttachmentCount:
          row.readNullable<int>('image_attachment_count') ?? 0,
      fileAttachmentCount: row.readNullable<int>('file_attachment_count') ?? 0,
      previewImagePaths: _parsePreviewPaths(
        row.readNullable<String>('preview_image_paths_joined'),
      ),
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

/// 人物提及篇數統計（近 30 天窗口以呼叫時的 [now] 計算）。
class PersonMentionStats {
  const PersonMentionStats({
    required this.personId,
    required this.mentionCount,
    required this.recentMentionCount,
    this.lastMentionDate,
  });

  final PersonId personId;
  final int mentionCount;
  final int recentMentionCount;
  final DateOnly? lastMentionDate;
}

/// 範圍內提及排序列（總覽 Top N）。
class PersonScopedMentionRank {
  const PersonScopedMentionRank({
    required this.personId,
    required this.mentionCount,
    required this.lastMentionDate,
  });

  final PersonId personId;
  final int mentionCount;
  final DateOnly lastMentionDate;
}

/// 人物姓名分析所需的輕量索引列，不含人物關聯。
class PeopleAnalysisSourceDocument {
  const PeopleAnalysisSourceDocument({
    required this.entryId,
    required this.entryDate,
    required this.contentHash,
    required this.titleText,
    required this.bodyVisibleText,
  });

  final EntryId entryId;
  final DateOnly entryDate;
  final String contentHash;
  final String titleText;
  final String bodyVisibleText;
}

class PeopleVisibleTextSourceDocument {
  const PeopleVisibleTextSourceDocument({
    required this.entryId,
    required this.filePath,
    required this.contentHash,
  });

  final EntryId entryId;
  final String filePath;
  final String contentHash;
}

class PeopleAnalysisDocumentResult {
  const PeopleAnalysisDocumentResult({
    required this.document,
    required this.personIds,
  });

  final PeopleAnalysisSourceDocument document;
  final Set<PersonId> personIds;
}

class IndexDatabase extends GeneratedDatabase {
  IndexDatabase(super.executor);

  static const int indexGeneration = 1;

  /// 人物分析衍生索引的語意版本（與 schema generation 分開）。
  /// 變更匹配規則時請遞增，讓既有 vault 自動重建統計。
  static const int peopleAnalyticsGeneration = 1;

  static const String kPeopleAnalyticsGenerationKey =
      'people_analytics_generation';
  static const String kPeopleAnalyticsStaleKey = 'people_analytics_stale';
  static const String kPeopleAnalyticsCatalogFingerprintKey =
      'people_analytics_catalog_fingerprint';

  @override
  int get schemaVersion => 1;

  @override
  List<TableInfo<Table, Object?>> get allTables =>
      const <TableInfo<Table, Object?>>[];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      const <DatabaseSchemaEntity>[];

  Future<void> initialize() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS entries_index (
        id TEXT PRIMARY KEY,
        vault_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        title TEXT,
        title_search_text TEXT,
        preview_text TEXT,
        body_search_text TEXT,
        body_visible_text TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        word_count INTEGER NOT NULL DEFAULT 0,
        char_count INTEGER NOT NULL DEFAULT 0,
        attachment_count INTEGER NOT NULL DEFAULT 0,
        has_attachments INTEGER NOT NULL DEFAULT 0,
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
        created_at TEXT NOT NULL
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
      CREATE INDEX IF NOT EXISTS idx_entries_index_date_updated
      ON entries_index (date, updated_at);
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_entry_tags_entry_id
      ON entry_tags (entry_id);
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_entry_attachments_entry_created
      ON entry_attachments (entry_id, created_at);
    ''');
    await _ensurePreviewMarkdownColumn();
    await _ensureBodyVisibleTextColumn();
    // 解鎖熱路徑只確保表存在；不重建人物統計。
    await ensurePeopleAnalyticsTable();
  }

  Future<void> ensurePeopleAnalyticsTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS entry_people_analytics (
        entry_id TEXT NOT NULL,
        person_id TEXT NOT NULL,
        entry_date TEXT NOT NULL,
        PRIMARY KEY (entry_id, person_id)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS people_analysis_documents (
        entry_id TEXT PRIMARY KEY,
        content_hash TEXT NOT NULL,
        entry_date TEXT NOT NULL
      );
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_entry_people_analytics_person_date
      ON entry_people_analytics (person_id, entry_date);
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_entry_people_analytics_entry
      ON entry_people_analytics (entry_id);
    ''');
  }

  Future<void> _ensurePreviewMarkdownColumn() async {
    final List<QueryRow> rows = await customSelect(
      'PRAGMA table_info(entries_index);',
    ).get();
    final bool hasColumn = rows.any(
      (QueryRow row) => row.read<String>('name') == 'preview_markdown',
    );
    if (!hasColumn) {
      await customStatement(
        'ALTER TABLE entries_index ADD COLUMN preview_markdown TEXT;',
      );
    }
  }

  Future<void> _ensureBodyVisibleTextColumn() async {
    final List<QueryRow> rows = await customSelect(
      'PRAGMA table_info(entries_index);',
    ).get();
    final bool hasColumn = rows.any(
      (QueryRow row) => row.read<String>('name') == 'body_visible_text',
    );
    if (!hasColumn) {
      await customStatement(
        'ALTER TABLE entries_index ADD COLUMN body_visible_text TEXT;',
      );
    }
  }

  Future<void> upsertEntry({
    required DiaryEntry entry,
    required String filePath,
    required String previewText,
    required String previewMarkdown,
    required String titleSearchText,
    required String bodySearchText,
    required String bodyVisibleText,
    required String contentHash,
    required int encryptedFileSize,
    required DateTime encryptedModifiedAt,
  }) async {
    await customStatement(
      '''
        INSERT INTO entries_index (
          id, vault_id, file_path, title, title_search_text, preview_text,
          preview_markdown, body_search_text, body_visible_text, date,
          created_at, updated_at, word_count, char_count, attachment_count,
          has_attachments, encrypted_file_size,
          encrypted_file_mtime, content_hash
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          vault_id = excluded.vault_id,
          file_path = excluded.file_path,
          title = excluded.title,
          title_search_text = excluded.title_search_text,
          preview_text = excluded.preview_text,
          preview_markdown = excluded.preview_markdown,
          body_search_text = excluded.body_search_text,
          body_visible_text = excluded.body_visible_text,
          date = excluded.date,
          created_at = excluded.created_at,
          updated_at = excluded.updated_at,
          word_count = excluded.word_count,
          char_count = excluded.char_count,
          attachment_count = excluded.attachment_count,
          has_attachments = excluded.has_attachments,
          encrypted_file_size = excluded.encrypted_file_size,
          encrypted_file_mtime = excluded.encrypted_file_mtime,
          content_hash = excluded.content_hash;
      ''',
      <Object?>[
        entry.id,
        entry.vaultId,
        filePath,
        entry.normalizedTitle,
        titleSearchText,
        previewText,
        previewMarkdown,
        bodySearchText,
        bodyVisibleText,
        entry.date.value,
        entry.createdAt.toIso8601String(),
        entry.updatedAt.toIso8601String(),
        _wordCount(entry.markdownBody),
        entry.markdownBody.runes.length,
        entry.attachmentIds.length,
        entry.attachmentIds.isEmpty ? 0 : 1,
        encryptedFileSize,
        encryptedModifiedAt.toIso8601String(),
        contentHash,
      ],
    );
    await replaceTags(entry.id, entry.tags);
  }

  /// `normalizeText(tag)` → 儲存的 ARGB（與 Flutter `Color` 對應）。
  Future<Map<String, int>> fetchTagAccentArgbMap() async {
    final List<QueryRow> rows = await customSelect(
      'SELECT tag_normalized, accent_argb FROM tag_styles;',
    ).get();
    return <String, int>{
      for (final QueryRow row in rows)
        row.read<String>('tag_normalized'): row.read<int>('accent_argb'),
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
    await customStatement(
      'DELETE FROM entry_tags WHERE entry_id = ?;',
      <Object?>[entryId],
    );
    for (final String tag in tags) {
      await customStatement(
        'INSERT INTO entry_tags (entry_id, tag, tag_normalized) VALUES (?, ?, ?);',
        <Object?>[entryId, tag, normalizeSearchText(tag)],
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
            byte_size, sha256, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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

  Future<List<EntryIndexRecord>> listEntries({
    String? searchQuery,
    DateOnly? date,
  }) async {
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      return searchEntries(searchQuery);
    }

    final List<Object?> variables = <Object?>[];
    final List<String> where = <String>[if (date != null) 'e.date = ?'];
    if (date != null) {
      variables.add(date.value);
    }

    final String sql =
        '''
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
      ORDER BY e.date DESC, e.created_at DESC, e.updated_at DESC;
    ''';
    final List<QueryRow> rows = await customSelect(
      sql,
      variables: <Variable<Object>>[
        for (final Object? value in variables)
          Variable.withString(value as String),
      ],
    ).get();
    return rows.map(EntryIndexRecord.fromRow).toList();
  }

  Future<List<EntryIndexRecord>> searchEntries(String query) async {
    final String normalizedQuery = normalizeSearchText(query);
    if (normalizedQuery.isEmpty) {
      return listEntries();
    }
    return _searchEntriesByLike(normalizedQuery);
  }

  Future<List<EntryIndexRecord>> _searchEntriesByLike(
    String normalizedQuery,
  ) async {
    final String likeQuery = '%$normalizedQuery%';
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
          COALESCE(e.title_search_text, '') LIKE ? OR
          COALESCE(e.body_search_text, '') LIKE ? OR
          EXISTS (
            SELECT 1
            FROM entry_tags et
            WHERE et.entry_id = e.id AND et.tag_normalized LIKE ?
          )
        )
        GROUP BY e.id
        ORDER BY e.date DESC, e.created_at DESC, e.updated_at DESC;
      ''',
      variables: <Variable<Object>>[
        Variable.withString(likeQuery),
        Variable.withString(likeQuery),
        Variable.withString(likeQuery),
      ],
    ).get();
    return rows.map(EntryIndexRecord.fromRow).toList();
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
        WHERE e.date LIKE ?
        GROUP BY e.id
        ORDER BY e.date ASC, e.created_at DESC, e.updated_at DESC;
      ''',
      variables: <Variable<Object>>[Variable.withString('$prefix%')],
    ).get();
    return rows.map(EntryIndexRecord.fromRow).toList();
  }

  Future<List<DateOnly>> monthEntryDates(DateTime month) async {
    final String prefix =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    final List<QueryRow> rows = await customSelect(
      '''
        SELECT DISTINCT date
        FROM entries_index
        WHERE date LIKE ?
        ORDER BY date ASC;
      ''',
      variables: <Variable<Object>>[Variable.withString('$prefix%')],
    ).get();
    return rows
        .map((QueryRow row) => DateOnly.parse(row.read<String>('date')))
        .toList();
  }

  Future<List<AssetAttachment>> attachmentsForEntry(EntryId entryId) async {
    final List<QueryRow> rows = await customSelect(
      '''
        SELECT *
        FROM entry_attachments
        WHERE entry_id = ?
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

  /// 硬刪除：移除索引中的日記、標籤與附件紀錄。
  Future<void> removeEntry(EntryId entryId) async {
    await customStatement(
      'DELETE FROM entry_tags WHERE entry_id = ?;',
      <Object?>[entryId],
    );
    await customStatement(
      'DELETE FROM entry_attachments WHERE entry_id = ?;',
      <Object?>[entryId],
    );
    await customStatement(
      'DELETE FROM entry_people_analytics WHERE entry_id = ?;',
      <Object?>[entryId],
    );
    await customStatement(
      'DELETE FROM people_analysis_documents WHERE entry_id = ?;',
      <Object?>[entryId],
    );
    await customStatement('DELETE FROM entries_index WHERE id = ?;', <Object?>[
      entryId,
    ]);
  }

  Future<int> replacePeopleAnalyticsForDocuments(
    List<PeopleAnalysisDocumentResult> results,
  ) async {
    if (results.isEmpty) {
      return 0;
    }
    return transaction(() async {
      var applied = 0;
      for (final PeopleAnalysisDocumentResult result in results) {
        final PeopleAnalysisSourceDocument document = result.document;
        await customStatement(
          'DELETE FROM entry_people_analytics WHERE entry_id = ?;',
          <Object?>[document.entryId],
        );
        await customStatement(
          'DELETE FROM people_analysis_documents WHERE entry_id = ?;',
          <Object?>[document.entryId],
        );
        final QueryRow? current = await customSelect(
          '''
            SELECT 1 AS present
            FROM entries_index
            WHERE id = ?
              AND date = ?
              AND COALESCE(content_hash, '') = ?
              AND body_visible_text IS NOT NULL
            LIMIT 1;
          ''',
          variables: <Variable<Object>>[
            Variable.withString(document.entryId),
            Variable.withString(document.entryDate.value),
            Variable.withString(document.contentHash),
          ],
        ).getSingleOrNull();
        if (current == null) {
          continue;
        }
        for (final PersonId personId in result.personIds) {
          if (personId.isEmpty) {
            continue;
          }
          await customStatement(
            '''
              INSERT INTO entry_people_analytics
                (entry_id, person_id, entry_date)
              VALUES (?, ?, ?);
            ''',
            <Object?>[document.entryId, personId, document.entryDate.value],
          );
        }
        await customStatement(
          '''
            INSERT INTO people_analysis_documents
              (entry_id, content_hash, entry_date)
            VALUES (?, ?, ?)
            ON CONFLICT(entry_id) DO UPDATE SET
              content_hash = excluded.content_hash,
              entry_date = excluded.entry_date;
          ''',
          <Object?>[
            document.entryId,
            document.contentHash,
            document.entryDate.value,
          ],
        );
        applied += 1;
      }
      return applied;
    });
  }

  Future<int> countMissingPeopleVisibleTextDocuments() async {
    final QueryRow row = await customSelect('''
      SELECT COUNT(*) AS missing_count
      FROM entries_index
      WHERE body_visible_text IS NULL;
    ''').getSingle();
    return row.read<int>('missing_count');
  }

  Future<List<PeopleVisibleTextSourceDocument>>
  missingPeopleVisibleTextDocuments({
    int limit = 256,
    EntryId? afterEntryId,
  }) async {
    final String keysetClause = afterEntryId == null ? '' : 'AND id > ?';
    final List<Variable<Object>> variables = <Variable<Object>>[
      if (afterEntryId != null) Variable.withString(afterEntryId),
      Variable.withInt(limit),
    ];
    final List<QueryRow> rows = await customSelect('''
      SELECT id, file_path, COALESCE(content_hash, '') AS content_hash
      FROM entries_index
      WHERE body_visible_text IS NULL
      $keysetClause
      ORDER BY id
      LIMIT ?;
    ''', variables: variables).get();
    return <PeopleVisibleTextSourceDocument>[
      for (final QueryRow row in rows)
        PeopleVisibleTextSourceDocument(
          entryId: row.read<String>('id'),
          filePath: row.read<String>('file_path'),
          contentHash: row.read<String>('content_hash'),
        ),
    ];
  }

  Future<int> updatePeopleVisibleTextDocuments(
    Map<PeopleVisibleTextSourceDocument, String> visibleTextByDocument,
  ) async {
    if (visibleTextByDocument.isEmpty) {
      return 0;
    }
    return transaction(() async {
      var updated = 0;
      for (final MapEntry<PeopleVisibleTextSourceDocument, String> item
          in visibleTextByDocument.entries) {
        final PeopleVisibleTextSourceDocument document = item.key;
        await customStatement(
          '''
            UPDATE entries_index
            SET body_visible_text = ?
            WHERE id = ?
              AND file_path = ?
              AND COALESCE(content_hash, '') = ?
              AND body_visible_text IS NULL;
          ''',
          <Object?>[
            item.value,
            document.entryId,
            document.filePath,
            document.contentHash,
          ],
        );
        final QueryRow changed = await customSelect(
          'SELECT changes() AS changed;',
        ).getSingle();
        updated += changed.read<int>('changed');
      }
      return updated;
    });
  }

  Future<List<PeopleAnalysisSourceDocument>> changedPeopleAnalysisDocuments({
    int limit = 256,
    EntryId? afterEntryId,
  }) async {
    final String keysetClause = afterEntryId == null ? '' : 'AND e.id > ?';
    final List<Variable<Object>> variables = <Variable<Object>>[
      if (afterEntryId != null) Variable.withString(afterEntryId),
      Variable.withInt(limit),
    ];
    final List<QueryRow> rows = await customSelect('''
      SELECT
        e.id,
        e.date,
        COALESCE(e.content_hash, '') AS content_hash,
        COALESCE(e.title_search_text, '') AS title_text,
        e.body_visible_text AS body_text
      FROM entries_index e
      LEFT JOIN people_analysis_documents d ON d.entry_id = e.id
      WHERE (
        d.entry_id IS NULL
        OR d.content_hash <> COALESCE(e.content_hash, '')
        OR d.entry_date <> e.date
      )
      AND e.body_visible_text IS NOT NULL
      $keysetClause
      ORDER BY e.id
      LIMIT ?;
    ''', variables: variables).get();
    return <PeopleAnalysisSourceDocument>[
      for (final QueryRow row in rows)
        PeopleAnalysisSourceDocument(
          entryId: row.read<String>('id'),
          entryDate: DateOnly.parse(row.read<String>('date')),
          contentHash: row.read<String>('content_hash'),
          titleText: row.read<String>('title_text'),
          bodyVisibleText: row.read<String>('body_text'),
        ),
    ];
  }

  Future<int> countChangedPeopleAnalysisDocuments() async {
    final QueryRow row = await customSelect('''
      SELECT COUNT(*) AS pending_count
      FROM entries_index e
      LEFT JOIN people_analysis_documents d ON d.entry_id = e.id
      WHERE (
        d.entry_id IS NULL
        OR d.content_hash <> COALESCE(e.content_hash, '')
        OR d.entry_date <> e.date
      )
      AND e.body_visible_text IS NOT NULL;
    ''').getSingle();
    return row.read<int>('pending_count');
  }

  Future<void> resetPeopleAnalytics() async {
    await transaction(() async {
      await customStatement('DELETE FROM entry_people_analytics;');
      await customStatement('DELETE FROM people_analysis_documents;');
    });
  }

  Future<void> setPeopleAnalyticsStale(bool stale) async {
    await setAppValue(kPeopleAnalyticsStaleKey, stale ? '1' : '0');
  }

  Future<bool> isPeopleAnalyticsStale() async {
    final String? value = await getAppValue(kPeopleAnalyticsStaleKey);
    return value == '1';
  }

  Future<void> markPeopleAnalyticsReady(String catalogFingerprint) async {
    await setAppValue(
      kPeopleAnalyticsGenerationKey,
      peopleAnalyticsGeneration.toString(),
    );
    await setAppValue(
      kPeopleAnalyticsCatalogFingerprintKey,
      catalogFingerprint,
    );
    await setPeopleAnalyticsStale(false);
  }

  Future<void> beginPeopleAnalyticsRebuild(String catalogFingerprint) async {
    await setAppValue(
      kPeopleAnalyticsGenerationKey,
      peopleAnalyticsGeneration.toString(),
    );
    await setAppValue(
      kPeopleAnalyticsCatalogFingerprintKey,
      catalogFingerprint,
    );
    await setPeopleAnalyticsStale(true);
  }

  Future<bool> needsPeopleAnalyticsReset(String catalogFingerprint) async {
    final String? generation = await getAppValue(kPeopleAnalyticsGenerationKey);
    if (generation != peopleAnalyticsGeneration.toString()) {
      return true;
    }
    return await getAppValue(kPeopleAnalyticsCatalogFingerprintKey) !=
        catalogFingerprint;
  }

  Future<Map<PersonId, PersonMentionStats>> allPersonMentionStats({
    DateTime? now,
  }) async {
    final DateTime today = now ?? DateTime.now();
    final DateOnly todayDate = DateOnly.fromDateTime(today);
    final DateOnly windowStart = DateOnly.fromDateTime(
      today.subtract(const Duration(days: 29)),
    );

    final List<QueryRow> rows = await customSelect(
      '''
        SELECT
          person_id,
          COUNT(*) AS mention_count,
          MAX(entry_date) AS last_mention_date,
          SUM(
            CASE
              WHEN entry_date >= ? AND entry_date <= ? THEN 1
              ELSE 0
            END
          ) AS recent_mention_count
        FROM entry_people_analytics
        GROUP BY person_id;
      ''',
      variables: <Variable<Object>>[
        Variable.withString(windowStart.value),
        Variable.withString(todayDate.value),
      ],
    ).get();

    return <PersonId, PersonMentionStats>{
      for (final QueryRow row in rows)
        row.read<String>('person_id'): PersonMentionStats(
          personId: row.read<String>('person_id'),
          mentionCount: row.read<int>('mention_count'),
          recentMentionCount:
              row.readNullable<int>('recent_mention_count') ?? 0,
          lastMentionDate: DateOnly.tryParse(
            row.readNullable<String>('last_mention_date') ?? '',
          ),
        ),
    };
  }

  Future<List<EntryIndexRecord>> relatedEntriesForPerson(
    PersonId personId,
  ) async {
    final List<QueryRow> rows = await customSelect(
      '''
        SELECT
          e.*,
          GROUP_CONCAT(t.tag, CHAR(10)) AS tags_joined,
          $_kImageAttachmentCountSelect,
          $_kFileAttachmentCountSelect,
          $_kPreviewImagePathsSelect
        FROM entry_people_analytics epa
        INNER JOIN entries_index e ON e.id = epa.entry_id
        LEFT JOIN entry_tags t ON t.entry_id = e.id
        WHERE epa.person_id = ?
        GROUP BY e.id
        ORDER BY e.date DESC, e.created_at DESC, e.updated_at DESC;
      ''',
      variables: <Variable<Object>>[Variable.withString(personId)],
    ).get();
    return rows.map(EntryIndexRecord.fromRow).toList();
  }

  Future<List<PersonScopedMentionRank>> topMentionedPeople({
    required int limit,
    String? yearPrefix,
    String? monthPrefix,
  }) async {
    final StringBuffer where = StringBuffer();
    final List<Variable<Object>> variables = <Variable<Object>>[];
    if (monthPrefix != null && monthPrefix.isNotEmpty) {
      where.write('WHERE entry_date LIKE ?');
      variables.add(Variable.withString('$monthPrefix%'));
    } else if (yearPrefix != null && yearPrefix.isNotEmpty) {
      where.write('WHERE entry_date LIKE ?');
      variables.add(Variable.withString('$yearPrefix%'));
    }
    variables.add(Variable.withInt(limit));

    final List<QueryRow> rows = await customSelect('''
        SELECT
          person_id,
          COUNT(*) AS mention_count,
          MAX(entry_date) AS last_mention_date
        FROM entry_people_analytics
        $where
        GROUP BY person_id
        ORDER BY mention_count DESC, last_mention_date DESC, person_id ASC
        LIMIT ?;
      ''', variables: variables).get();

    final List<PersonScopedMentionRank> ranks = <PersonScopedMentionRank>[];
    for (final QueryRow row in rows) {
      final DateOnly? last = DateOnly.tryParse(
        row.readNullable<String>('last_mention_date') ?? '',
      );
      if (last == null) {
        continue;
      }
      ranks.add(
        PersonScopedMentionRank(
          personId: row.read<String>('person_id'),
          mentionCount: row.read<int>('mention_count'),
          lastMentionDate: last,
        ),
      );
    }
    return ranks;
  }

  static const Set<String> _removedIndexColumns = <String>{
    'mood',
    'schema_version',
  };

  static const Set<String> _requiredIndexColumns = <String>{
    'id',
    'vault_id',
    'file_path',
    'title_search_text',
    'body_search_text',
    'body_visible_text',
    'date',
    'created_at',
    'updated_at',
    'word_count',
    'char_count',
    'attachment_count',
    'has_attachments',
    'content_hash',
  };

  Future<bool> hasExpectedIndexSchema() async {
    final List<QueryRow> rows = await customSelect(
      'PRAGMA table_info(entries_index);',
    ).get();
    if (rows.isEmpty) {
      return false;
    }

    final Set<String> columns = rows
        .map((QueryRow row) => row.read<String>('name'))
        .toSet();
    if (_removedIndexColumns.any(columns.contains)) {
      return false;
    }
    if (!_requiredIndexColumns.every(columns.contains)) {
      return false;
    }
    return true;
  }

  Future<void> rebuild() async {
    await customStatement('DELETE FROM entries_index;');
    await customStatement('DELETE FROM entry_tags;');
    await customStatement('DELETE FROM entry_attachments;');
    await customStatement('DELETE FROM entry_people_analytics;');
    await customStatement('DELETE FROM people_analysis_documents;');
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
    await customStatement('DELETE FROM app_kv WHERE key = ?;', <Object?>[key]);
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
