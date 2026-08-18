import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/editor/editor_draft_models.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

void main() {
  test('buildEditorDraftSnapshot 會整理標題、標籤與內文', () {
    final EditorDraftSnapshot snapshot = buildEditorDraftSnapshot(
      titleRaw: '  標題  ',
      dateRaw: ' 2026-06-18 ',
      entryHour: 9,
      entryMinute: 30,
      tagsRaw: '旅行, 旅行, 夏天',
      bodyRaw: '內容\n- [ ] 待辦',
      attachmentIds: const <AssetId>['asset-1'],
    );

    expect(snapshot.title, '標題');
    expect(snapshot.dateValue, '2026-06-18');
    expect(snapshot.tags, <String>['旅行', '夏天']);
    expect(snapshot.markdownBody, '內容\n- [ ] 待辦\n');
  });

  test('附件順序不同會視為草稿已修改', () {
    final EditorDraftSnapshot saved = buildEditorDraftSnapshot(
      titleRaw: '標題',
      dateRaw: '2026-06-18',
      entryHour: 9,
      entryMinute: 30,
      tagsRaw: '',
      bodyRaw: '內容',
      attachmentIds: const <AssetId>['saved-1', 'pending-1'],
    );
    final EditorDraftSnapshot current = buildEditorDraftSnapshot(
      titleRaw: '標題',
      dateRaw: '2026-06-18',
      entryHour: 9,
      entryMinute: 30,
      tagsRaw: '',
      bodyRaw: '內容',
      attachmentIds: const <AssetId>['pending-1', 'saved-1'],
    );

    expect(editorDraftIsDirty(current: current, saved: saved), isTrue);
  });

  test('標籤順序不同會視為草稿已修改', () {
    final EditorDraftSnapshot saved = buildEditorDraftSnapshot(
      titleRaw: '標題',
      dateRaw: '2026-06-18',
      entryHour: 9,
      entryMinute: 30,
      tagsRaw: '旅行, 生活',
      bodyRaw: '內容',
      attachmentIds: const <AssetId>[],
    );
    final EditorDraftSnapshot current = buildEditorDraftSnapshot(
      titleRaw: '標題',
      dateRaw: '2026-06-18',
      entryHour: 9,
      entryMinute: 30,
      tagsRaw: '生活, 旅行',
      bodyRaw: '內容',
      attachmentIds: const <AssetId>[],
    );

    expect(editorDraftIsDirty(current: current, saved: saved), isTrue);
  });

  test('草稿 JSON 會保留混合附件順序與暫存附件 ID', () {
    final EditorDraftRecord record = EditorDraftRecord(
      title: '標題',
      dateValue: '2026-06-18',
      entryHour: 8,
      entryMinute: 0,
      tags: const <String>[],
      markdownBody: '內容\n',
      attachmentIds: const <AssetId>['pending-1', 'saved-1'],
      pendingAttachments: const <EditorDraftPendingAttachment>[
        EditorDraftPendingAttachment(
          assetId: 'pending-1',
          relativePath: 'pending/photo.jpg.enc',
          mimeType: 'image/jpeg',
          originalFilename: 'photo.jpg',
        ),
      ],
      provisionalEntryId: 'entry-1',
      createdAt: DateTime(2026, 6, 18, 8),
      updatedAt: DateTime(2026, 6, 18, 9),
    );

    final EditorDraftRecord restored = EditorDraftRecord.fromJson(
      record.toJson(),
    );

    expect(restored.attachmentIds, <AssetId>['pending-1', 'saved-1']);
    expect(restored.pendingAttachments.single.assetId, 'pending-1');
  });

  test('舊版草稿會將既有附件後接暫存附件', () {
    final EditorDraftRecord restored = EditorDraftRecord.fromJson(
      <String, Object?>{
        'date_value': '2026-06-18',
        'entry_hour': 8,
        'entry_minute': 0,
        'tags': <String>[],
        'markdown_body': '',
        'kept_attachment_ids': <String>['saved-1'],
        'pending_attachments': <Map<String, Object?>>[
          <String, Object?>{
            'relative_path': 'pending/photo.jpg.enc',
            'mime_type': 'image/jpeg',
            'original_filename': 'photo.jpg',
          },
        ],
        'provisional_entry_id': 'entry-1',
        'created_at': '2026-06-18T08:00:00.000',
        'updated_at': '2026-06-18T09:00:00.000',
      },
    );

    final AssetId pendingId = restored.pendingAttachments.single.assetId;
    expect(restored.attachmentIds, <AssetId>['saved-1', pendingId]);
    expect(pendingId, isNotEmpty);
  });

  test('還原草稿時會沿用暫存附件 ID', () {
    final EditorDraftRecord record = EditorDraftRecord(
      title: null,
      dateValue: '2026-06-18',
      entryHour: 8,
      entryMinute: 0,
      tags: const <String>[],
      markdownBody: '',
      attachmentIds: const <AssetId>['pending-1'],
      pendingAttachments: const <EditorDraftPendingAttachment>[
        EditorDraftPendingAttachment(
          assetId: 'pending-1',
          relativePath: 'pending/photo.jpg.enc',
          mimeType: 'image/jpeg',
          originalFilename: 'photo.jpg',
        ),
      ],
      provisionalEntryId: 'entry-1',
      createdAt: DateTime(2026, 6, 18, 8),
      updatedAt: DateTime(2026, 6, 18, 9),
    );

    final pending = pendingAttachmentsFromDraftRecord(
      record,
      absolutePathBuilder: (String relativePath) => 'C:/drafts/$relativePath',
    );

    expect(pending.single.assetId, 'pending-1');
  });
}
