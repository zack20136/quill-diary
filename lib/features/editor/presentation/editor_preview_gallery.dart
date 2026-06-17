import 'package:flutter/material.dart';

import '../../../domain/attachment/asset_attachment.dart';
import '../../../infrastructure/storage/vault_repository.dart';
import '../../../shared/presentation/page_style.dart';
import '../../../shared/presentation/widgets/entry_cover_thumbnail.dart';
import '../../../shared/presentation/widgets/local_file_thumbnail.dart';

class EditorPreviewGallery extends StatelessWidget {
  const EditorPreviewGallery({
    super.key,
    required this.savedImages,
    required this.pendingImages,
    required this.encryptedPathFuture,
    required this.onOpenGallery,
  });

  final List<AssetAttachment> savedImages;
  final List<PendingAttachment> pendingImages;
  final Future<String> Function(AssetAttachment attachment) encryptedPathFuture;
  final ValueChanged<int> onOpenGallery;

  @override
  Widget build(BuildContext context) {
    final int total = savedImages.length + pendingImages.length;
    if (total == 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360;
        final double thumbSide = (((maxWidth - 12) / 2) - 22).clamp(108.0, 320.0);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            height: thumbSide,
            child: ListView.separated(
              key: const Key('editor-preview-gallery'),
              padding: EdgeInsets.zero,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: total,
              separatorBuilder: (BuildContext _, int _) =>
                  const SizedBox(width: 10),
              itemBuilder: (BuildContext context, int index) {
                final bool first = index == 0;
                if (index < savedImages.length) {
                  return _previewPhotoTileSaved(
                    savedImages[index],
                    thumbSide,
                    leadingInset: first ? 0 : 6,
                    onTap: () => onOpenGallery(index),
                  );
                }
                return _previewPhotoTilePending(
                  pendingImages[index - savedImages.length],
                  thumbSide,
                  leadingInset: first ? 0 : 6,
                  onTap: () => onOpenGallery(index),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _previewPhotoTileSaved(
    AssetAttachment attachment,
    double thumbSide, {
    required double leadingInset,
    required VoidCallback onTap,
  }) {
    final double edge = thumbSide.clamp(40.0, 400.0);
    return Padding(
      padding: EdgeInsets.only(left: leadingInset, right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PageStyle.radiusThumb),
          child: FutureBuilder<String>(
            future: encryptedPathFuture(attachment),
            builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
              return EntryCoverThumbnail(
                encryptedFilePath: snapshot.data ?? '',
                size: edge,
                borderRadius: BorderRadius.circular(PageStyle.radiusThumb),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _previewPhotoTilePending(
    PendingAttachment attachment,
    double thumbSide, {
    required double leadingInset,
    required VoidCallback onTap,
  }) {
    final double edge = thumbSide.clamp(40.0, 400.0);
    return Padding(
      padding: EdgeInsets.only(left: leadingInset, right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PageStyle.radiusThumb),
          child: localFileThumbnail(
            attachment.sourcePath,
            size: edge,
            borderRadius: BorderRadius.circular(PageStyle.radiusThumb),
          ),
        ),
      ),
    );
  }
}
