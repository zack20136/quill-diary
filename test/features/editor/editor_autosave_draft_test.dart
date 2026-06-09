import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/features/editor/editor_draft.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

void main() {
  group('editorDraftIsEmpty', () {
    test('空白 draft 視為 empty', () {
      const EditorDraftSnapshot draft = EditorDraftSnapshot(
        title: null,
        dateValue: '2026-05-17',
        entryHour: 10,
        entryMinute: 28,
        tags: <String>[],
        markdownBody: '',
        keptAttachmentIds: <AssetId>[],
        pendingFingerprints: <String>[],
      );

      expect(editorDraftIsEmpty(draft), isTrue);
    });

    test('有標題則不是 empty', () {
      const EditorDraftSnapshot draft = EditorDraftSnapshot(
        title: 'hello',
        dateValue: '2026-05-17',
        entryHour: 10,
        entryMinute: 28,
        tags: <String>[],
        markdownBody: '',
        keptAttachmentIds: <AssetId>[],
        pendingFingerprints: <String>[],
      );

      expect(editorDraftIsEmpty(draft), isFalse);
    });
  });

  group('editorDraftIsDirty', () {
    final EditorDraftSnapshot saved = EditorDraftSnapshot(
      title: 'title',
      dateValue: '2026-05-17',
      entryHour: 10,
      entryMinute: 28,
      tags: <String>['tag'],
      markdownBody: 'body',
      keptAttachmentIds: <AssetId>['asset-1'],
      pendingFingerprints: <String>[],
    );

    test('saved 為 null 且 empty 時不 dirty', () {
      const EditorDraftSnapshot current = EditorDraftSnapshot(
        title: null,
        dateValue: '2026-05-17',
        entryHour: 10,
        entryMinute: 28,
        tags: <String>[],
        markdownBody: '',
        keptAttachmentIds: <AssetId>[],
        pendingFingerprints: <String>[],
      );

      expect(
        editorDraftIsDirty(current: current, saved: null),
        isFalse,
      );
    });

    test('文字變更標記 dirty', () {
      final EditorDraftSnapshot current = saved.copyWithBody('changed');

      expect(
        editorDraftIsDirty(current: current, saved: saved),
        isTrue,
      );
    });

    test('附件 id 變更標記 dirty', () {
      final EditorDraftSnapshot current = saved.copyWithAttachments(
        keptAttachmentIds: <AssetId>['asset-2'],
      );

      expect(
        editorDraftIsDirty(current: current, saved: saved),
        isTrue,
      );
    });

    test('pending 附件指紋變更標記 dirty', () {
      final EditorDraftSnapshot current = saved.copyWithPending(
        pendingFingerprints: <String>['/tmp/a.jpg|image/jpeg|a.jpg'],
      );

      expect(
        editorDraftIsDirty(current: current, saved: saved),
        isTrue,
      );
    });
  });

  group('buildEditorDraftSnapshot', () {
    test('trim 標題與內文並解析標籤', () {
      final EditorDraftSnapshot draft = buildEditorDraftSnapshot(
        titleRaw: '  hello  ',
        dateRaw: '2026-05-17',
        entryHour: 9,
        entryMinute: 5,
        tagsRaw: 'a, b ,c',
        bodyRaw: '  body  ',
        keptAttachmentIds: <AssetId>['asset-1'],
        pendingAttachments: <PendingAttachment>[
          PendingAttachment(
            sourcePath: '/tmp/x.png',
            mimeType: 'image/png',
            originalFilename: 'x.png',
          ),
        ],
      );

      expect(draft.title, 'hello');
      expect(draft.markdownBody, 'body');
      expect(draft.tags, <String>['a', 'b', 'c']);
      expect(draft.pendingFingerprints, <String>['/tmp/x.png|image/png|x.png']);
    });
  });

  group('editorDraftSnapshotFromEntry', () {
    test('從 DiaryEntry 建立 snapshot', () {
      final DiaryEntry entry = DiaryEntry(
        id: 'entry-1',
        vaultId: 'vault-1',
        title: 'title',
        date: DateOnly.parse('2026-05-17'),
        createdAt: DateTime(2026, 5, 17, 10, 28),
        updatedAt: DateTime(2026, 5, 17, 10, 28),
        tags: <String>['tag'],
        markdownBody: 'body',
        attachmentIds: <AssetId>['asset-1'],
      );

      final EditorDraftSnapshot snapshot = editorDraftSnapshotFromEntry(entry);

      expect(snapshot.title, 'title');
      expect(snapshot.entryHour, 10);
      expect(snapshot.entryMinute, 28);
      expect(snapshot.keptAttachmentIds, <AssetId>['asset-1']);
      expect(snapshot.pendingFingerprints, isEmpty);
    });
  });
}

extension _EditorDraftSnapshotTestHelpers on EditorDraftSnapshot {
  EditorDraftSnapshot copyWithBody(String body) {
    return EditorDraftSnapshot(
      title: title,
      dateValue: dateValue,
      entryHour: entryHour,
      entryMinute: entryMinute,
      tags: tags,
      markdownBody: body,
      keptAttachmentIds: keptAttachmentIds,
      pendingFingerprints: pendingFingerprints,
    );
  }

  EditorDraftSnapshot copyWithAttachments({
    required List<AssetId> keptAttachmentIds,
  }) {
    return EditorDraftSnapshot(
      title: title,
      dateValue: dateValue,
      entryHour: entryHour,
      entryMinute: entryMinute,
      tags: tags,
      markdownBody: markdownBody,
      keptAttachmentIds: keptAttachmentIds,
      pendingFingerprints: pendingFingerprints,
    );
  }

  EditorDraftSnapshot copyWithPending({
    required List<String> pendingFingerprints,
  }) {
    return EditorDraftSnapshot(
      title: title,
      dateValue: dateValue,
      entryHour: entryHour,
      entryMinute: entryMinute,
      tags: tags,
      markdownBody: markdownBody,
      keptAttachmentIds: keptAttachmentIds,
      pendingFingerprints: pendingFingerprints,
    );
  }
}
