import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../app/app_colors.dart';
import '../../../l10n/l10n.dart';

class AppImageGalleryDialog extends StatefulWidget {
  const AppImageGalleryDialog({
    super.key,
    required this.itemCount,
    required this.initialIndex,
    required this.imageBuilder,
    this.onDownload,
  }) : assert(itemCount > 0),
       assert(initialIndex >= 0 && initialIndex < itemCount);

  final int itemCount;
  final int initialIndex;
  final IndexedWidgetBuilder imageBuilder;
  final Future<void> Function(BuildContext context, int index)? onDownload;

  @override
  State<AppImageGalleryDialog> createState() => _AppImageGalleryDialogState();
}

class _AppImageGalleryDialogState extends State<AppImageGalleryDialog> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late int _currentIndex = widget.initialIndex;
  bool _pageScrollEnabled = true;
  bool _downloading = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onGalleryZoomChanged(bool zoomed) {
    if (_pageScrollEnabled == !zoomed) return;
    setState(() => _pageScrollEnabled = !zoomed);
  }

  Future<void> _downloadCurrentImage() async {
    final download = widget.onDownload;
    if (_downloading || download == null) return;
    setState(() => _downloading = true);
    try {
      await download(context, _currentIndex);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final colors = context.appColors;
    final foreground = colors.galleryForeground;
    return Dialog(
      backgroundColor: colors.galleryBackground,
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
        width: size.width - 24,
        height: size.height * 0.88,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
              child: Row(
                children: [
                  Text(
                    '${_currentIndex + 1} / ${widget.itemCount}',
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (widget.onDownload != null)
                    IconButton(
                      tooltip: context.l10n.editorGalleryDownloadTooltip,
                      onPressed: _downloading ? null : _downloadCurrentImage,
                      icon: _downloading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: foreground,
                              ),
                            )
                          : Icon(Icons.download_outlined, color: foreground),
                    ),
                  IconButton(
                    tooltip: context.l10n.commonCloseTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: foreground),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.itemCount,
                physics: _pageScrollEnabled && widget.itemCount > 1
                    ? const PageScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() {
                  _currentIndex = index;
                  _pageScrollEnabled = true;
                }),
                itemBuilder: (context, index) => _ZoomableGalleryImage(
                  isActive: index == _currentIndex,
                  onZoomChanged: _onGalleryZoomChanged,
                  child: widget.imageBuilder(context, index),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomableGalleryImage extends StatefulWidget {
  const _ZoomableGalleryImage({
    required this.child,
    required this.isActive,
    this.onZoomChanged,
  });

  final Widget child;
  final bool isActive;
  final ValueChanged<bool>? onZoomChanged;

  @override
  State<_ZoomableGalleryImage> createState() => _ZoomableGalleryImageState();
}

class _ZoomableGalleryImageState extends State<_ZoomableGalleryImage>
    with SingleTickerProviderStateMixin {
  static const double _minScale = 1;
  static const double _maxScale = 4;
  static const double _doubleTapScale = 2.5;
  static const double _zoomedScaleThreshold = 1.01;
  static const Duration _zoomAnimationDuration = Duration(milliseconds: 220);

  final TransformationController _transformController =
      TransformationController();
  late final AnimationController _zoomAnimationController = AnimationController(
    vsync: this,
    duration: _zoomAnimationDuration,
  );

  Animation<Matrix4>? _zoomAnimation;
  bool _isZoomed = false;
  bool _panEnabled = false;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onTransformChanged);
    _zoomAnimationController.addListener(_onZoomAnimationTick);
  }

  @override
  void didUpdateWidget(covariant _ZoomableGalleryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive && _isZoomed) {
      _resetTransform(animated: false);
    }
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _zoomAnimationController.removeListener(_onZoomAnimationTick);
    _zoomAnimationController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _onZoomAnimationTick() {
    final Animation<Matrix4>? animation = _zoomAnimation;
    if (animation == null) {
      return;
    }
    _transformController.value = animation.value;
  }

  void _onTransformChanged() {
    if (_zoomAnimationController.isAnimating) {
      return;
    }
    _syncZoomState(notifyParent: true);
  }

  void _syncZoomState({required bool notifyParent}) {
    final double scale = _transformController.value.getMaxScaleOnAxis();
    final bool zoomed = scale > _zoomedScaleThreshold;
    final bool panEnabled = zoomed;

    if (notifyParent && zoomed != _isZoomed) {
      widget.onZoomChanged?.call(zoomed);
    }

    if (zoomed != _isZoomed || panEnabled != _panEnabled) {
      setState(() {
        _isZoomed = zoomed;
        _panEnabled = panEnabled;
      });
    }
  }

  void _resetTransform({required bool animated}) {
    _zoomAnimationController.stop();
    _zoomAnimation = null;
    if (animated) {
      _animateToMatrix(Matrix4.identity());
      return;
    }
    _transformController.value = Matrix4.identity();
    _syncZoomState(notifyParent: true);
  }

  void _animateToMatrix(Matrix4 target) {
    _zoomAnimationController.stop();
    final bool targetZoomed =
        target.getMaxScaleOnAxis() > _zoomedScaleThreshold;
    if (targetZoomed != _isZoomed) {
      setState(() {
        _isZoomed = targetZoomed;
        _panEnabled = targetZoomed;
      });
      widget.onZoomChanged?.call(targetZoomed);
    }
    _zoomAnimation =
        Matrix4Tween(
          begin: _transformController.value.clone(),
          end: target,
        ).animate(
          CurvedAnimation(
            parent: _zoomAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
    unawaited(
      _zoomAnimationController.forward(from: 0).whenComplete(() {
        if (!mounted) {
          return;
        }
        _syncZoomState(notifyParent: true);
      }),
    );
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _zoomAnimationController.stop();
    _zoomAnimation = null;

    if (_isZoomed) {
      _resetTransform(animated: true);
      return;
    }

    final Offset focalPoint = details.localPosition;
    final Matrix4 target = Matrix4.identity()
      ..translateByDouble(focalPoint.dx, focalPoint.dy, 0, 1)
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1)
      ..translateByDouble(-focalPoint.dx, -focalPoint.dy, 0, 1);
    _animateToMatrix(target);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return GestureDetector(
          onDoubleTapDown: _handleDoubleTapDown,
          behavior: HitTestBehavior.opaque,
          child: InteractiveViewer(
            transformationController: _transformController,
            clipBehavior: Clip.none,
            boundaryMargin: const EdgeInsets.all(80),
            minScale: _minScale,
            maxScale: _maxScale,
            panEnabled: _panEnabled,
            scaleEnabled: true,
            trackpadScrollCausesScale: true,
            onInteractionStart: (_) {
              if (_zoomAnimationController.isAnimating) {
                _zoomAnimationController.stop();
                _zoomAnimation = null;
              }
            },
            onInteractionEnd: (_) {
              if (_zoomAnimationController.isAnimating) {
                return;
              }
              final double scale = _transformController.value
                  .getMaxScaleOnAxis();
              if (scale < _zoomedScaleThreshold) {
                _resetTransform(animated: true);
              }
            },
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Center(child: widget.child),
            ),
          ),
        );
      },
    );
  }
}
