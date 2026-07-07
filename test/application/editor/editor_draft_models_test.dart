import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/application/editor/editor_draft_models.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

void main() {
  test('buildEditorDraftSnapshot 會正規化標籤與 markdown 內文', () {
    final EditorDraftSnapshot snapshot = buildEditorDraftSnapshot(
      titleRaw: '  標題  ',
      dateRaw: ' 2026-06-18 ',
      entryHour: 9,
      entryMinute: 30,
      tagsRaw: '工作, 工作, 生活',
      bodyRaw: '前言\n- [ ] 任務三',
      keptAttachmentIds: const <AssetId>['asset-1'],
      pendingAttachments: const <PendingAttachment>[],
    );

    expect(snapshot.title, '標題');
    expect(snapshot.dateValue, '2026-06-18');
    expect(snapshot.tags, <String>['工作', '生活']);
    expect(snapshot.markdownBody, '前言\n- [ ] 任務三\n');
  });

  test('標籤順序不同時會視為 dirty', () {
    final EditorDraftSnapshot saved = buildEditorDraftSnapshot(
      titleRaw: '標題',
      dateRaw: '2026-06-18',
      entryHour: 9,
      entryMinute: 30,
      tagsRaw: '工作, 生活',
      bodyRaw: '內文',
      keptAttachmentIds: const <AssetId>[],
      pendingAttachments: const <PendingAttachment>[],
    );
    final EditorDraftSnapshot current = buildEditorDraftSnapshot(
      titleRaw: '標題',
      dateRaw: '2026-06-18',
      entryHour: 9,
      entryMinute: 30,
      tagsRaw: '生活, 工作',
      bodyRaw: '內文',
      keptAttachmentIds: const <AssetId>[],
      pendingAttachments: const <PendingAttachment>[],
    );

    expect(editorDraftIsDirty(current: current, saved: saved), isTrue);
  });

  test('還原草稿後的 pending 附件指紋與目前草稿一致時不視為 dirty', () {
    final PendingAttachment restored = PendingAttachment(
      sourcePath: 'C:/drafts/pending/file',
      mimeType: 'image/jpeg',
      originalFilename: 'photo.jpg',
    );
    final EditorDraftSnapshot restoredBaseline = buildEditorDraftSnapshot(
      titleRaw: '草稿',
      dateRaw: '2026-06-18',
      entryHour: 8,
      entryMinute: 0,
      tagsRaw: '標籤',
      bodyRaw: '內文',
      keptAttachmentIds: const <AssetId>[],
      pendingAttachments: <PendingAttachment>[restored],
    );
    final EditorDraftSnapshot current = buildEditorDraftSnapshot(
      titleRaw: '草稿',
      dateRaw: '2026-06-18',
      entryHour: 8,
      entryMinute: 0,
      tagsRaw: '標籤',
      bodyRaw: '內文',
      keptAttachmentIds: const <AssetId>[],
      pendingAttachments: <PendingAttachment>[restored],
    );

    expect(
      editorDraftIsDirty(current: current, saved: restoredBaseline),
      isFalse,
    );
  });
}
