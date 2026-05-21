import '../../domain/diary/diary_entry.dart';
import '../../domain/shared/value_objects.dart';
import '../../infrastructure/storage/vault_repository.dart';

/// Editable field snapshot used for dirty detection and auto-save guards.
class EditorDraftSnapshot {
  const EditorDraftSnapshot({
    this.title,
    required this.dateValue,
    required this.entryHour,
    required this.entryMinute,
    required this.tags,
    this.mood,
    required this.markdownBody,
    required this.keptAttachmentIds,
    required this.pendingFingerprints,
  });

  final String? title;
  final String dateValue;
  final int entryHour;
  final int entryMinute;
  final List<String> tags;
  final String? mood;
  final String markdownBody;
  final List<AssetId> keptAttachmentIds;
  final List<String> pendingFingerprints;
}

List<String> parseEditorTagsCsv(String tagsRaw) {
  return tagsRaw
      .split(',')
      .map((String tag) => tag.trim())
      .where((String tag) => tag.isNotEmpty)
      .toList();
}

String pendingAttachmentFingerprint(PendingAttachment attachment) {
  return '${attachment.sourcePath}|${attachment.mimeType}|${attachment.originalFilename}';
}

EditorDraftSnapshot editorDraftSnapshotFromEntry(DiaryEntry entry) {
  return EditorDraftSnapshot(
    title: entry.normalizedTitle,
    dateValue: entry.date.value,
    entryHour: entry.createdAt.hour,
    entryMinute: entry.createdAt.minute,
    tags: List<String>.from(entry.tags),
    mood: () {
      final String? trimmed = entry.mood?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    }(),
    markdownBody: entry.markdownBody.trim(),
    keptAttachmentIds: List<AssetId>.from(entry.attachmentIds),
    pendingFingerprints: const <String>[],
  );
}

EditorDraftSnapshot buildEditorDraftSnapshot({
  required String titleRaw,
  required String dateRaw,
  required int entryHour,
  required int entryMinute,
  required String tagsRaw,
  required String moodRaw,
  required String bodyRaw,
  required List<AssetId> keptAttachmentIds,
  required List<PendingAttachment> pendingAttachments,
}) {
  final String trimmedTitle = titleRaw.trim();
  final String trimmedMood = moodRaw.trim();
  final List<String> pendingFingerprints = pendingAttachments
      .map(pendingAttachmentFingerprint)
      .toList()
    ..sort();
  return EditorDraftSnapshot(
    title: trimmedTitle.isEmpty ? null : trimmedTitle,
    dateValue: dateRaw.trim(),
    entryHour: entryHour,
    entryMinute: entryMinute,
    tags: parseEditorTagsCsv(tagsRaw),
    mood: trimmedMood.isEmpty ? null : trimmedMood,
    markdownBody: bodyRaw.trim(),
    keptAttachmentIds: List<AssetId>.from(keptAttachmentIds),
    pendingFingerprints: pendingFingerprints,
  );
}

bool editorDraftIsEmpty(EditorDraftSnapshot draft) {
  return draft.title == null &&
      draft.markdownBody.isEmpty &&
      draft.keptAttachmentIds.isEmpty &&
      draft.pendingFingerprints.isEmpty;
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
      current.mood != saved.mood ||
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
