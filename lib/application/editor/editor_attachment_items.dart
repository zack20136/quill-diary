import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

sealed class EditorAttachmentItem {
  const EditorAttachmentItem();

  AssetId get assetId;
  String get mimeType;
}

class SavedEditorAttachmentItem extends EditorAttachmentItem {
  const SavedEditorAttachmentItem(this.attachment);

  final AssetAttachment attachment;

  @override
  AssetId get assetId => attachment.id;

  @override
  String get mimeType => attachment.mimeType;
}

class PendingEditorAttachmentItem extends EditorAttachmentItem {
  const PendingEditorAttachmentItem(this.attachment);

  final PendingAttachment attachment;

  @override
  AssetId get assetId => attachment.assetId;

  @override
  String get mimeType => attachment.mimeType;
}

List<EditorAttachmentItem> resolveEditorAttachmentItems({
  required List<AssetId> attachmentIds,
  required List<AssetAttachment> savedAttachments,
  required List<PendingAttachment> pendingAttachments,
}) {
  final Map<AssetId, EditorAttachmentItem> byId =
      <AssetId, EditorAttachmentItem>{
        for (final AssetAttachment attachment in savedAttachments)
          attachment.id: SavedEditorAttachmentItem(attachment),
        for (final PendingAttachment attachment in pendingAttachments)
          attachment.assetId: PendingEditorAttachmentItem(attachment),
      };
  return attachmentIds
      .map((AssetId id) => byId[id])
      .whereType<EditorAttachmentItem>()
      .toList();
}

List<AssetId> reorderEditorImageAttachmentIds({
  required List<AssetId> attachmentIds,
  required List<AssetId> imageIds,
  required int oldIndex,
  required int newIndex,
}) {
  if (oldIndex < 0 ||
      oldIndex >= imageIds.length ||
      newIndex < 0 ||
      newIndex >= imageIds.length ||
      oldIndex == newIndex) {
    return List<AssetId>.from(attachmentIds);
  }

  final List<AssetId> reorderedImageIds = List<AssetId>.from(imageIds);
  final AssetId moved = reorderedImageIds.removeAt(oldIndex);
  reorderedImageIds.insert(newIndex, moved);

  final Set<AssetId> imageIdSet = imageIds.toSet();
  var nextImageIndex = 0;
  return attachmentIds.map((AssetId id) {
    if (!imageIdSet.contains(id)) {
      return id;
    }
    return reorderedImageIds[nextImageIndex++];
  }).toList();
}
