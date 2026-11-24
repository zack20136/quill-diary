import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/diary/diary_entry_providers.dart';
import 'package:quill_diary/application/editor/editor_attachment_items.dart';
import 'package:quill_diary/application/editor/editor_draft_providers.dart';
import 'package:quill_diary/application/editor/editor_gallery_export.dart';
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/diary/widgets/entry_cover_thumbnail.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';

class EditorPreviewGallery extends StatelessWidget {
  const EditorPreviewGallery({
    super.key,
    required this.images,
    required this.encryptedPathFuture,
    required this.onOpenGallery,
  });

  final List<EditorAttachmentItem> images;
  final Future<String> Function(AssetAttachment attachment) encryptedPathFuture;
  final ValueChanged<int> onOpenGallery;

  @override
  Widget build(BuildContext context) {
    final int total = images.length;
    if (total == 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360;
        final double thumbSide = (((maxWidth - 12) / 2) - 22).clamp(
          108.0,
          320.0,
        );

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
                final EditorAttachmentItem item = images[index];
                final Widget tile = switch (item) {
                  SavedEditorAttachmentItem(:final attachment) =>
                    _previewPhotoTileSaved(
                      attachment,
                      thumbSide,
                      leadingInset: first ? 0 : 6,
                      onTap: () => onOpenGallery(index),
                    ),
                  PendingEditorAttachmentItem(:final attachment) =>
                    _previewPhotoTilePending(
                      attachment,
                      thumbSide,
                      leadingInset: first ? 0 : 6,
                      onTap: () => onOpenGallery(index),
                    ),
                };
                return KeyedSubtree(
                  key: ValueKey<String>('editor-preview-image-${item.assetId}'),
                  child: tile,
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
          child: EditorDraftImage(
            source: attachment.encryptedDraftSource,
            size: edge,
          ),
        ),
      ),
    );
  }
}

class EditorGalleryImagePane extends ConsumerWidget {
  const EditorGalleryImagePane({super.key, required this.item});

  final GalleryImageItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftKey = item.draftKey;
    return draftKey == null
        ? _EncryptedGalleryImage(path: item.path)
        : EditorDraftImage(source: (draftKey: draftKey, path: item.path));
  }
}

class EditorDraftImage extends ConsumerWidget {
  const EditorDraftImage({
    super.key,
    required this.source,
    this.size,
    this.borderRadius,
  });

  final ({String draftKey, String path})? source;
  final double? size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = this.source;
    final bytes = source == null
        ? null
        : ref.watch(editorDraftAttachmentBytesProvider(source)).asData?.value;
    final size = this.size;
    final radius = borderRadius ?? BorderRadius.circular(PageStyle.radiusThumb);
    Widget fallback() => size == null
        ? Center(child: Text(context.l10n.editorPreviewUnavailable))
        : EntryCoverThumbnailPlaceholder(size: size, borderRadius: radius);
    if (bytes == null || bytes.isEmpty) return fallback();

    final image = Image.memory(
      bytes,
      width: size,
      height: size,
      fit: size == null ? BoxFit.contain : BoxFit.cover,
      cacheWidth: size == null
          ? null
          : (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(
              64,
              512,
            ),
      errorBuilder: (_, _, _) => fallback(),
    );
    return size == null ? image : ClipRRect(borderRadius: radius, child: image);
  }
}

class _EncryptedGalleryImage extends ConsumerWidget {
  const _EncryptedGalleryImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color foreground = context.appColors.galleryForeground;
    final AsyncValue<Uint8List?> async = ref.watch(
      entryCoverPreviewBytesProvider(path),
    );
    return async.when(
      skipLoadingOnReload: true,
      data: (Uint8List? bytes) {
        if (bytes == null || bytes.isEmpty) {
          return Center(
            child: Text(
              context.l10n.editorPreviewUnavailable,
              style: TextStyle(color: foreground.withValues(alpha: 0.85)),
            ),
          );
        }
        return Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true);
      },
      loading: () =>
          Center(child: CircularProgressIndicator(color: foreground)),
      error: (Object _, StackTrace _) =>
          Icon(Icons.broken_image_outlined, color: foreground, size: 56),
    );
  }
}
