import 'package:flutter/material.dart';

import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/application/editor/editor_attachment_items.dart';
import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/widgets/entry_cover_thumbnail.dart';
import 'package:quill_diary/shared/presentation/widgets/local_file_thumbnail.dart';

class EditorAttachmentStrip extends StatelessWidget {
  const EditorAttachmentStrip({
    super.key,
    required this.images,
    required this.nonImages,
    required this.editable,
    required this.draggingIndex,
    required this.encryptedPathFuture,
    required this.onRemove,
    required this.onReorder,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final List<EditorAttachmentItem> images;
  final List<EditorAttachmentItem> nonImages;
  final bool editable;
  final int? draggingIndex;
  final Future<String> Function(AssetAttachment attachment) encryptedPathFuture;
  final ValueChanged<EditorAttachmentItem> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<int> onDragStart;
  final ValueChanged<int> onDragEnd;

  static const double _thumbSize = 72;
  static const double _stripGap = 10;
  static const double _slotWidth = _thumbSize + _stripGap;

  @override
  Widget build(BuildContext context) {
    final bool hasNonImageAttachments = nonImages.isNotEmpty;
    if (images.isEmpty && !hasNonImageAttachments) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (images.isNotEmpty) _buildImageStrip(context),
        if (hasNonImageAttachments) ...<Widget>[
          if (images.isNotEmpty) const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              ...nonImages.map(
                (EditorAttachmentItem item) =>
                    _nonImageChip(item, editable: editable),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildImageStrip(BuildContext context) {
    final int itemCount = images.length;

    Widget buildThumbContent(int index) {
      final bool isDragPlaceholder = draggingIndex == index;
      final EditorAttachmentItem item = images[index];
      return switch (item) {
        SavedEditorAttachmentItem(:final attachment) =>
          _savedImageThumbnailTile(
            context,
            attachment,
            editable: editable,
            draggable: editable && itemCount > 1,
            isDragPlaceholder: isDragPlaceholder,
            onDelete: () => onRemove(item),
          ),
        PendingEditorAttachmentItem(:final attachment) =>
          _pendingImageThumbnailTile(
            context,
            attachment,
            editable: editable,
            draggable: editable && itemCount > 1,
            isDragPlaceholder: isDragPlaceholder,
            onDelete: () => onRemove(item),
          ),
      };
    }

    Widget buildStripItem(int index) {
      return _editorImageStripSlot(child: buildThumbContent(index));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: SizedBox(
            height: 76,
            child: editable && itemCount > 1
                ? ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    buildDefaultDragHandles: false,
                    clipBehavior: Clip.none,
                    proxyDecorator: _decorateEditorImageDragProxy,
                    onReorderStart: onDragStart,
                    onReorderEnd: onDragEnd,
                    onReorderItem: onReorder,
                    itemCount: itemCount,
                    itemBuilder: (BuildContext context, int index) {
                      final Key itemKey = ValueKey<String>(
                        'editor-image-${images[index].assetId}',
                      );
                      return KeyedSubtree(
                        key: itemKey,
                        child: _editorImageStripSlot(
                          child: ReorderableDelayedDragStartListener(
                            index: index,
                            child: buildThumbContent(index),
                          ),
                        ),
                      );
                    },
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List<Widget>.generate(
                        itemCount,
                        buildStripItem,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _editorImageStripSlot({required Widget child}) {
    return SizedBox(
      width: _slotWidth,
      height: _thumbSize,
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }

  Widget _decorateEditorImageDragProxy(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return Builder(
      builder: (BuildContext context) {
        final ColorScheme cs = Theme.of(context).colorScheme;
        return SizedBox(
          width: _thumbSize,
          height: _thumbSize,
          child: AnimatedBuilder(
            animation: animation,
            builder: (BuildContext context, Widget? animatedChild) {
              final double t = Curves.easeOutCubic.transform(animation.value);
              final double scale = Tween<double>(
                begin: 1,
                end: 1.08,
              ).transform(t);
              final double lift = Tween<double>(begin: 0, end: -4).transform(t);
              return Transform.translate(
                offset: Offset(0, lift),
                child: Transform.scale(
                  scale: scale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        PageStyle.radiusThumbSmall,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.28 * t),
                          blurRadius: 20 * t,
                          spreadRadius: 1 * t,
                          offset: Offset(0, 8 * t),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16 * t),
                          blurRadius: 12 * t,
                          offset: Offset(0, 4 * t),
                        ),
                      ],
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.52 * t),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        PageStyle.radiusThumbSmall,
                      ),
                      child: SizedBox(
                        width: _thumbSize,
                        height: _thumbSize,
                        child: animatedChild,
                      ),
                    ),
                  ),
                ),
              );
            },
            child: child,
          ),
        );
      },
    );
  }

  Widget _savedImageThumbnailTile(
    BuildContext context,
    AssetAttachment attachment, {
    required bool editable,
    required bool draggable,
    required bool isDragPlaceholder,
    required VoidCallback onDelete,
  }) {
    final ThemeData theme = Theme.of(context);
    if (isDragPlaceholder) {
      return _editorImageDragPlaceholder(theme);
    }

    Widget thumb(String path) {
      return SizedBox(
        width: _thumbSize,
        height: _thumbSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: <Widget>[
            EntryCoverThumbnail(
              encryptedFilePath: path.isEmpty ? null : path,
              size: 64,
              borderRadius: BorderRadius.circular(PageStyle.radiusThumbSmall),
            ),
            if (editable)
              _editorImageDeleteBadge(context, theme, onTap: onDelete),
            if (draggable) _dragIndicator(context, theme),
          ],
        ),
      );
    }

    return FutureBuilder<String>(
      future: encryptedPathFuture(attachment),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        return thumb(snapshot.data ?? '');
      },
    );
  }

  Widget _pendingImageThumbnailTile(
    BuildContext context,
    PendingAttachment attachment, {
    required bool editable,
    required bool draggable,
    required bool isDragPlaceholder,
    required VoidCallback onDelete,
  }) {
    final ThemeData theme = Theme.of(context);
    if (isDragPlaceholder) {
      return _editorImageDragPlaceholder(theme);
    }

    return SizedBox(
      width: _thumbSize,
      height: _thumbSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          localFileThumbnail(
            attachment.sourcePath,
            size: 64,
            borderRadius: BorderRadius.circular(PageStyle.radiusThumbSmall),
          ),
          if (editable)
            _editorImageDeleteBadge(context, theme, onTap: onDelete),
          if (draggable) _dragIndicator(context, theme),
        ],
      ),
    );
  }

  Widget _nonImageChip(EditorAttachmentItem item, {required bool editable}) {
    final String label = switch (item) {
      SavedEditorAttachmentItem(:final attachment) =>
        attachment.originalFilename ?? attachment.safeFilename,
      PendingEditorAttachmentItem(:final attachment) =>
        attachment.originalFilename,
    };
    return Chip(
      label: Text(label, overflow: TextOverflow.ellipsis),
      onDeleted: editable ? () => onRemove(item) : null,
    );
  }

  Widget _editorImageDragPlaceholder(ThemeData theme) {
    final ColorScheme cs = theme.colorScheme;
    return SizedBox(
      width: _thumbSize,
      height: _thumbSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PageStyle.radiusThumbSmall),
          color: cs.surfaceContainerHighest.withValues(alpha: 0.42),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.34),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.drag_indicator_rounded,
            size: 22,
            color: cs.primary.withValues(alpha: 0.42),
          ),
        ),
      ),
    );
  }

  Widget _editorImageDeleteBadge(
    BuildContext context,
    ThemeData theme, {
    required VoidCallback onTap,
  }) {
    return Positioned(
      right: 0,
      top: 0,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.cancel_rounded,
            size: 20,
            color: theme.colorScheme.error.withValues(alpha: 0.9),
            shadows: <Shadow>[
              Shadow(blurRadius: 4, color: context.appColors.shadow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dragIndicator(BuildContext context, ThemeData theme) {
    return Positioned(
      left: 4,
      bottom: 4,
      child: IgnorePointer(
        child: Icon(
          Icons.drag_indicator_rounded,
          size: 18,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
          shadows: <Shadow>[
            Shadow(blurRadius: 4, color: context.appColors.shadow),
          ],
        ),
      ),
    );
  }
}
