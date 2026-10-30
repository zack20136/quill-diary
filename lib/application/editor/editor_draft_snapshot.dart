import 'package:quill_diary/application/editor/editor_body_blocks.dart';
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_draft.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

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
