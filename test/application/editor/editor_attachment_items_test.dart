import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/editor/editor_attachment_items.dart';
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

void main() {
  test('附件解析會依統一 ID 順序交錯既有與暫存附件', () {
    final AssetAttachment saved = AssetAttachment(
      id: 'saved-image',
      entryId: 'entry-1',
      mimeType: 'image/jpeg',
      safeFilename: 'saved.jpg',
      byteSize: 1,
      createdAt: DateTime(2026, 8, 18),
      sha256: 'sha',
    );
    final PendingAttachment pending = PendingAttachment(
      assetId: 'pending-image',
      bytes: Uint8List.fromList(<int>[1]),
      mimeType: 'image/jpeg',
      originalFilename: 'pending.jpg',
    );

    final List<EditorAttachmentItem> items = resolveEditorAttachmentItems(
      attachmentIds: const <AssetId>['pending-image', 'saved-image'],
      savedAttachments: <AssetAttachment>[saved],
      pendingAttachments: <PendingAttachment>[pending],
    );

    expect(items.first, isA<PendingEditorAttachmentItem>());
    expect(items.last, isA<SavedEditorAttachmentItem>());
  });

  group('reorderEditorImageAttachmentIds', () {
    test('新圖片可以移到舊圖片前方且一般附件留在原槽位', () {
      final List<AssetId> reordered = reorderEditorImageAttachmentIds(
        attachmentIds: const <AssetId>['saved-image', 'file', 'pending-image'],
        imageIds: const <AssetId>['saved-image', 'pending-image'],
        oldIndex: 1,
        newIndex: 0,
      );

      expect(reordered, <AssetId>['pending-image', 'file', 'saved-image']);
    });

    test('圖片可以連續雙向重排', () {
      final List<AssetId> movedForward = reorderEditorImageAttachmentIds(
        attachmentIds: const <AssetId>['a', 'b', 'c'],
        imageIds: const <AssetId>['a', 'b', 'c'],
        oldIndex: 2,
        newIndex: 0,
      );
      final List<AssetId> movedBack = reorderEditorImageAttachmentIds(
        attachmentIds: movedForward,
        imageIds: movedForward,
        oldIndex: 0,
        newIndex: 2,
      );

      expect(movedForward, <AssetId>['c', 'a', 'b']);
      expect(movedBack, <AssetId>['a', 'b', 'c']);
    });

    test('無效索引、相同索引與單張圖片不改變順序', () {
      const List<AssetId> original = <AssetId>['image', 'file'];

      expect(
        reorderEditorImageAttachmentIds(
          attachmentIds: original,
          imageIds: const <AssetId>['image'],
          oldIndex: 0,
          newIndex: 0,
        ),
        original,
      );
      expect(
        reorderEditorImageAttachmentIds(
          attachmentIds: original,
          imageIds: const <AssetId>['image'],
          oldIndex: 1,
          newIndex: 0,
        ),
        original,
      );
    });
  });
}
