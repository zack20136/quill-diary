import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'editor_body_blocks.dart';

class EditorDraftSnapshot {
  const EditorDraftSnapshot({
    this.title,
    required this.dateValue,
    required this.entryHour,
    required this.entryMinute,
    required this.tags,
    required this.markdownBody,
    required this.attachmentIds,
  });

  final String? title;
  final String dateValue;
  final int entryHour;
  final int entryMinute;
  final List<String> tags;
  final String markdownBody;
  final List<AssetId> attachmentIds;
}

class EditorDraftPendingAttachment {
  const EditorDraftPendingAttachment({
    required this.assetId,
    required this.relativePath,
    required this.mimeType,
    required this.originalFilename,
  });

  final AssetId assetId;
  final String relativePath;
  final String mimeType;
  final String originalFilename;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'asset_id': assetId,
      'relative_path': relativePath,
      'mime_type': mimeType,
      'original_filename': originalFilename,
    };
  }

  factory EditorDraftPendingAttachment.fromJson(Map<String, Object?> json) {
    return EditorDraftPendingAttachment(
      assetId: (json['asset_id'] ?? '').toString().trim().isEmpty
          ? generateAssetId()
          : (json['asset_id'] ?? '').toString(),
      relativePath: (json['relative_path'] ?? '').toString(),
      mimeType: (json['mime_type'] ?? '').toString(),
      originalFilename: (json['original_filename'] ?? '').toString(),
    );
  }
}

class EditorDraftRecord {
  const EditorDraftRecord({
    this.title,
    required this.dateValue,
    required this.entryHour,
    required this.entryMinute,
    required this.tags,
    required this.markdownBody,
    required this.attachmentIds,
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
  final List<AssetId> attachmentIds;
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
      'attachment_ids': attachmentIds,
      'pending_attachments': pendingAttachments
          .map((EditorDraftPendingAttachment attachment) => attachment.toJson())
          .toList(),
      'provisional_entry_id': provisionalEntryId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory EditorDraftRecord.fromJson(Map<String, Object?> json) {
    final List<Object?> rawPending =
        json['pending_attachments'] is List<Object?>
        ? json['pending_attachments'] as List<Object?>
        : const <Object?>[];
    final List<EditorDraftPendingAttachment> pendingAttachments = rawPending
        .whereType<Map<Object?, Object?>>()
        .map(
          (Map<Object?, Object?> raw) => EditorDraftPendingAttachment.fromJson(
            raw.map((Object? key, Object? value) => MapEntry('$key', value)),
          ),
        )
        .where(
          (EditorDraftPendingAttachment attachment) =>
              attachment.relativePath.trim().isNotEmpty,
        )
        .toList();
    final bool hasAttachmentOrder = json['attachment_ids'] is List<Object?>;
    final List<AssetId> attachmentIds =
        (hasAttachmentOrder
                ? json['attachment_ids'] as List<Object?>
                : json['kept_attachment_ids'] is List<Object?>
                ? json['kept_attachment_ids'] as List<Object?>
                : const <Object?>[])
            .map((Object? id) => '$id'.trim())
            .where((String id) => id.isNotEmpty)
            .toList();
    if (!hasAttachmentOrder) {
      attachmentIds.addAll(
        pendingAttachments.map(
          (EditorDraftPendingAttachment attachment) => attachment.assetId,
        ),
      );
    }
    return EditorDraftRecord(
      title: (json['title'] ?? '').toString().trim().isEmpty
          ? null
          : (json['title'] ?? '').toString().trim(),
      dateValue: (json['date_value'] ?? '').toString(),
      entryHour: int.tryParse('${json['entry_hour'] ?? 0}') ?? 0,
      entryMinute: int.tryParse('${json['entry_minute'] ?? 0}') ?? 0,
      tags:
          (json['tags'] is List<Object?>
                  ? json['tags'] as List<Object?>
                  : const <Object?>[])
              .map((Object? tag) => '$tag'.trim())
              .where((String tag) => tag.isNotEmpty)
              .toList(),
      markdownBody: (json['markdown_body'] ?? '').toString(),
      attachmentIds: attachmentIds,
      pendingAttachments: pendingAttachments,
      provisionalEntryId:
          (json['provisional_entry_id'] ?? '').toString().trim().isEmpty
          ? generateEntryId()
          : (json['provisional_entry_id'] ?? '').toString(),
      createdAt:
          DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse('${json['updated_at'] ?? ''}') ?? DateTime.now(),
    );
  }
}

List<String> parseEditorTagsCsv(String tagsRaw) {
  final List<String> out = <String>[];
  final Set<String> seen = <String>{};
  for (final String chunk in tagsRaw.split(',')) {
    final String display = chunk.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (display.isEmpty) {
      continue;
    }
    final String norm = normalizeText(display);
    if (seen.add(norm)) {
      out.add(display);
    }
  }
  return out;
}

EditorDraftSnapshot editorDraftSnapshotFromEntry(DiaryEntry entry) {
  return EditorDraftSnapshot(
    title: entry.normalizedTitle,
    dateValue: entry.date.value,
    entryHour: entry.createdAt.hour,
    entryMinute: entry.createdAt.minute,
    tags: List<String>.from(entry.tags),
    markdownBody: normalizeEditorBodyMarkdownForSave(entry.markdownBody),
    attachmentIds: List<AssetId>.from(entry.attachmentIds),
  );
}

EditorDraftSnapshot editorDraftSnapshotFromRecord(EditorDraftRecord record) {
  return EditorDraftSnapshot(
    title: record.title,
    dateValue: record.dateValue,
    entryHour: record.entryHour,
    entryMinute: record.entryMinute,
    tags: List<String>.from(record.tags),
    markdownBody: normalizeEditorBodyMarkdownForSave(record.markdownBody),
    attachmentIds: List<AssetId>.from(record.attachmentIds),
  );
}

EditorDraftSnapshot buildEditorDraftSnapshot({
  required String titleRaw,
  required String dateRaw,
  required int entryHour,
  required int entryMinute,
  required String tagsRaw,
  required String bodyRaw,
  required List<AssetId> attachmentIds,
}) {
  final String trimmedTitle = titleRaw.trim();
  return EditorDraftSnapshot(
    title: trimmedTitle.isEmpty ? null : trimmedTitle,
    dateValue: dateRaw.trim(),
    entryHour: entryHour,
    entryMinute: entryMinute,
    tags: parseEditorTagsCsv(tagsRaw),
    markdownBody: normalizeEditorBodyMarkdownForSave(bodyRaw),
    attachmentIds: List<AssetId>.from(attachmentIds),
  );
}

List<PendingAttachment> pendingAttachmentsFromDraftRecord(
  EditorDraftRecord record, {
  required String Function(String relativePath) absolutePathBuilder,
}) {
  return record.pendingAttachments.map((
    EditorDraftPendingAttachment attachment,
  ) {
    return PendingAttachment(
      assetId: attachment.assetId,
      sourcePath: absolutePathBuilder(attachment.relativePath),
      pendingRelativePath: attachment.relativePath,
      mimeType: attachment.mimeType,
      originalFilename: attachment.originalFilename,
    );
  }).toList();
}

bool editorDraftIsEmpty(EditorDraftSnapshot draft) {
  return draft.title == null &&
      draft.markdownBody.isEmpty &&
      draft.attachmentIds.isEmpty;
}

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
      !_listEquals(current.attachmentIds, saved.attachmentIds);
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
