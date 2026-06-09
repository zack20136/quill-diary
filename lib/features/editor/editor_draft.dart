import '../../domain/diary/diary_entry.dart';
import '../../domain/shared/value_objects.dart';
import '../../infrastructure/storage/vault_repository.dart';

/// 編輯器欄位快照，用於比對是否有未儲存變更。
class EditorDraftSnapshot {
  const EditorDraftSnapshot({
    this.title,
    required this.dateValue,
    required this.entryHour,
    required this.entryMinute,
    required this.tags,
    required this.markdownBody,
    required this.keptAttachmentIds,
    required this.pendingFingerprints,
  });

  final String? title;
  final String dateValue;
  final int entryHour;
  final int entryMinute;
  final List<String> tags;
  final String markdownBody;
  final List<AssetId> keptAttachmentIds;
  final List<String> pendingFingerprints;
}

/// 草稿內待上傳附件的相對路徑描述。
class EditorDraftPendingAttachment {
  const EditorDraftPendingAttachment({
    required this.relativePath,
    required this.mimeType,
    required this.originalFilename,
  });

  final String relativePath;
  final String mimeType;
  final String originalFilename;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'relative_path': relativePath,
      'mime_type': mimeType,
      'original_filename': originalFilename,
    };
  }

  factory EditorDraftPendingAttachment.fromJson(Map<String, Object?> json) {
    return EditorDraftPendingAttachment(
      relativePath: (json['relative_path'] ?? '').toString(),
      mimeType: (json['mime_type'] ?? '').toString(),
      originalFilename: (json['original_filename'] ?? '').toString(),
    );
  }
}

/// 本地加密草稿的完整內容。
class EditorDraftRecord {
  const EditorDraftRecord({
    this.title,
    required this.dateValue,
    required this.entryHour,
    required this.entryMinute,
    required this.tags,
    required this.markdownBody,
    required this.keptAttachmentIds,
    required this.pendingAttachments,
    required this.provisionalEntryId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String? title;
  final String dateValue;
  final int entryHour;
  final int entryMinute;
  final List<String> tags;
  final String markdownBody;
  final List<AssetId> keptAttachmentIds;
  final List<EditorDraftPendingAttachment> pendingAttachments;
  final EntryId provisionalEntryId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'title': title,
      'date_value': dateValue,
      'entry_hour': entryHour,
      'entry_minute': entryMinute,
      'tags': tags,
      'markdown_body': markdownBody,
      'kept_attachment_ids': keptAttachmentIds,
      'pending_attachments': pendingAttachments
          .map((EditorDraftPendingAttachment attachment) => attachment.toJson())
          .toList(),
      'provisional_entry_id': provisionalEntryId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory EditorDraftRecord.fromJson(Map<String, Object?> json) {
    final List<Object?> rawPending = json['pending_attachments'] is List<Object?>
        ? json['pending_attachments'] as List<Object?>
        : const <Object?>[];
    return EditorDraftRecord(
      title: (json['title'] ?? '').toString().trim().isEmpty
          ? null
          : (json['title'] ?? '').toString().trim(),
      dateValue: (json['date_value'] ?? '').toString(),
      entryHour: int.tryParse('${json['entry_hour'] ?? 0}') ?? 0,
      entryMinute: int.tryParse('${json['entry_minute'] ?? 0}') ?? 0,
      tags: (json['tags'] is List<Object?> ? json['tags'] as List<Object?> : const <Object?>[])
          .map((Object? tag) => '$tag'.trim())
          .where((String tag) => tag.isNotEmpty)
          .toList(),
      markdownBody: (json['markdown_body'] ?? '').toString(),
      keptAttachmentIds: (json['kept_attachment_ids'] is List<Object?>
              ? json['kept_attachment_ids'] as List<Object?>
              : const <Object?>[])
          .map((Object? id) => '$id')
          .where((String id) => id.trim().isNotEmpty)
          .toList(),
      pendingAttachments: rawPending
          .whereType<Map<Object?, Object?>>()
          .map(
            (Map<Object?, Object?> raw) => EditorDraftPendingAttachment.fromJson(
              raw.map(
                (Object? key, Object? value) => MapEntry('$key', value),
              ),
            ),
          )
          .where(
            (EditorDraftPendingAttachment attachment) => attachment.relativePath.trim().isNotEmpty,
          )
          .toList(),
      provisionalEntryId: (json['provisional_entry_id'] ?? '').toString().trim().isEmpty
          ? generateEntryId()
          : (json['provisional_entry_id'] ?? '').toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}') ?? DateTime.now(),
    );
  }
}

List<String> parseEditorTagsCsv(String tagsRaw) {
  return tagsRaw
      .split(',')
      .map((String tag) => tag.trim())
      .where((String tag) => tag.isNotEmpty)
      .toList();
}

String pendingAttachmentFingerprint(PendingAttachment attachment) {
  final String sourceKey = attachment.bytes != null
      ? 'bytes:${attachment.bytes!.length}'
      : attachment.sourcePath ?? '';
  return '$sourceKey|${attachment.mimeType}|${attachment.originalFilename}';
}

EditorDraftSnapshot editorDraftSnapshotFromEntry(DiaryEntry entry) {
  return EditorDraftSnapshot(
    title: entry.normalizedTitle,
    dateValue: entry.date.value,
    entryHour: entry.createdAt.hour,
    entryMinute: entry.createdAt.minute,
    tags: List<String>.from(entry.tags),
    markdownBody: entry.markdownBody.trim(),
    keptAttachmentIds: List<AssetId>.from(entry.attachmentIds),
    pendingFingerprints: const <String>[],
  );
}

EditorDraftSnapshot editorDraftSnapshotFromRecord(EditorDraftRecord record) {
  return EditorDraftSnapshot(
    title: record.title,
    dateValue: record.dateValue,
    entryHour: record.entryHour,
    entryMinute: record.entryMinute,
    tags: List<String>.from(record.tags),
    markdownBody: record.markdownBody.trim(),
    keptAttachmentIds: List<AssetId>.from(record.keptAttachmentIds),
    pendingFingerprints: record.pendingAttachments
        .map(
          (EditorDraftPendingAttachment attachment) =>
              '${attachment.relativePath}|${attachment.mimeType}|${attachment.originalFilename}',
        )
        .toList(),
  );
}

EditorDraftSnapshot buildEditorDraftSnapshot({
  required String titleRaw,
  required String dateRaw,
  required int entryHour,
  required int entryMinute,
  required String tagsRaw,
  required String bodyRaw,
  required List<AssetId> keptAttachmentIds,
  required List<PendingAttachment> pendingAttachments,
}) {
  final String trimmedTitle = titleRaw.trim();
  final List<String> pendingFingerprints = pendingAttachments
      .map(pendingAttachmentFingerprint)
      .toList();
  return EditorDraftSnapshot(
    title: trimmedTitle.isEmpty ? null : trimmedTitle,
    dateValue: dateRaw.trim(),
    entryHour: entryHour,
    entryMinute: entryMinute,
    tags: parseEditorTagsCsv(tagsRaw),
    markdownBody: bodyRaw.trim(),
    keptAttachmentIds: List<AssetId>.from(keptAttachmentIds),
    pendingFingerprints: pendingFingerprints,
  );
}

List<PendingAttachment> pendingAttachmentsFromDraftRecord(
  EditorDraftRecord record, {
  required String Function(String relativePath) absolutePathBuilder,
}) {
  return record.pendingAttachments.map((EditorDraftPendingAttachment attachment) {
    return PendingAttachment(
      sourcePath: absolutePathBuilder(attachment.relativePath),
      mimeType: attachment.mimeType,
      originalFilename: attachment.originalFilename,
    );
  }).toList();
}

/// 新建草稿且無任何實質內容時視為空白。
bool editorDraftIsEmpty(EditorDraftSnapshot draft) {
  return draft.title == null &&
      draft.markdownBody.isEmpty &&
      draft.keptAttachmentIds.isEmpty &&
      draft.pendingFingerprints.isEmpty;
}

/// 比對目前編輯內容與基準快照（vault 已儲存或上次落盤草稿）。
bool editorDraftIsDirty({
  required EditorDraftSnapshot current,
  required EditorDraftSnapshot? saved,
}) {
  if (saved == null) {
    return !editorDraftIsEmpty(current);
  }
  return current.title != saved.title ||
      current.dateValue != saved.dateValue ||
      current.entryHour != saved.entryHour ||
      current.entryMinute != saved.entryMinute ||
      !_listEquals(current.tags, saved.tags) ||
      current.markdownBody != saved.markdownBody ||
      !_listEquals(current.keptAttachmentIds, saved.keptAttachmentIds) ||
      !_listEquals(current.pendingFingerprints, saved.pendingFingerprints);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
