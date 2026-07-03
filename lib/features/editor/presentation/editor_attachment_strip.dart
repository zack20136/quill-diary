import 'package:flutter/material.dart';

import '../../../domain/attachment/asset_attachment.dart';
import '../../../infrastructure/storage/vault_repository.dart';
import '../../../app/app_colors.dart';
import '../../../shared/presentation/page_style.dart';
import '../../../shared/presentation/widgets/entry_cover_thumbnail.dart';
import '../../../shared/presentation/widgets/local_file_thumbnail.dart';
import '../application/editor_draft_models.dart';

class EditorAttachmentStrip extends StatelessWidget {
  const EditorAttachmentStrip({
    super.key,
    required this.savedImages,
    required this.pendingImages,
    required this.savedNonImages,
    required this.pendingNonImages,
    required this.editable,
    required this.draggingIndex,
    required this.encryptedPathFuture,
    required this.onRemoveSaved,
    required this.onRemovePending,
    required this.onReorder,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final List<AssetAttachment> savedImages;
  final List<PendingAttachment> pendingImages;
  final List<AssetAttachment> savedNonImages;
  final List<PendingAttachment> pendingNonImages;
  final bool editable;
  final int? draggingIndex;
  final Future<String> Function(AssetAttachment attachment) encryptedPathFuture;
  final ValueChanged<AssetAttachment> onRemoveSaved;
  final ValueChanged<PendingAttachment> onRemovePending;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<int> onDragStart;
  final ValueChanged<int> onDragEnd;

  static const double _thumbSize = 72;
  static const double _stripGap = 10;
  static const double _slotWidth = _thumbSize + _stripGap;

  @override
  Widget build(BuildContext context) {
    final bool hasNonImageAttachments =
        savedNonImages.isNotEmpty || pendingNonImages.isNotEmpty;
    if (savedImages.isEmpty &&
        pendingImages.isEmpty &&
        !hasNonImageAttachments) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (savedImages.isNotEmpty || pendingImages.isNotEmpty)
          _buildImageStrip(context),
        if (hasNonImageAttachments) ...<Widget>[
          if (savedImages.isNotEmpty || pendingImages.isNotEmpty)
            const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              ...savedNonImages.map(
                (AssetAttachment attachment) =>
                    _savedNonImageChip(attachment, editable: editable),
              ),
              ...pendingNonImages.map(
                (PendingAttachment attachment) =>
                    _pendingNonImageChip(attachment, editable: editable),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildImageStrip(BuildContext context) {
    final int itemCount = savedImages.length + pendingImages.length;

    Widget buildThumbContent(int index) {
      final bool isDragPlaceholder = draggingIndex == index;
      if (index < savedImages.length) {
        return _savedImageThumbnailTile(
          context,
          savedImages[index],
          editable: editable,
          draggable: editable && itemCount > 1,
          isDragPlaceholder: isDragPlaceholder,
        );
      }
      final PendingAttachment attachment =
          pendingImages[index - savedImages.length];
      return _pendingImageThumbnailTile(
        context,
        attachment,
        editable: editable,
        draggable: editable && itemCount > 1,
        isDragPlaceholder: isDragPlaceholder,
      );
    }

    Widget buildStripItem(int index) {
      return _editorImageStripSlot(child: buildThumbContent(index));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 4),
        SizedBox(
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
                    final Key itemKey;
                    if (index < savedImages.length) {
                      itemKey = ValueKey<String>(
                        'saved-image-${savedImages[index].id}',
                      );
                    } else {
                      final PendingAttachment attachment =
                          pendingImages[index - savedImages.length];
                      itemKey = ValueKey<String>(
                        'pending-image-${pendingAttachmentFingerprint(attachment)}',
                      );
                    }
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
                    children: List<Widget>.generate(itemCount, buildStripItem),
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
      child: Center(child: child),
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
              _editorImageDeleteBadge(
                context,
                theme,
                onTap: () => onRemoveSaved(attachment),
              ),
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
            _editorImageDeleteBadge(
              context,
              theme,
              onTap: () => onRemovePending(attachment),
            ),
          if (draggable) _dragIndicator(context, theme),
        ],
      ),
    );
  }

  Widget _savedNonImageChip(
    AssetAttachment attachment, {
    required bool editable,
  }) {
    return Chip(
      label: Text(
        attachment.originalFilename ?? attachment.safeFilename,
        overflow: TextOverflow.ellipsis,
      ),
      onDeleted: editable ? () => onRemoveSaved(attachment) : null,
    );
  }

  Widget _pendingNonImageChip(
    PendingAttachment attachment, {
    required bool editable,
  }) {
    return Chip(
      label: Text(attachment.originalFilename, overflow: TextOverflow.ellipsis),
      onDeleted: editable ? () => onRemovePending(attachment) : null,
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
