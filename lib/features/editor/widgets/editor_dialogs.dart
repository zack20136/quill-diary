part of '../pages/editor_page.dart';

class _TagsStudioDialog extends ConsumerStatefulWidget {
  const _TagsStudioDialog({
    required this.initialCsv,
    required this.suggestions,
    required this.onApply,
    required this.onDismiss,
  });

  final String initialCsv;
  final List<TagCatalogUsageItem> suggestions;
  final ValueChanged<String> onApply;
  final VoidCallback onDismiss;

  @override
  ConsumerState<_TagsStudioDialog> createState() => _TagsStudioDialogState();
}

class _TagsStudioDialogState extends ConsumerState<_TagsStudioDialog> {
  late final LinkedHashSet<String> _chosen;
  late final TextEditingController _filterCtrl;

  String _norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

  Set<String> get _chosenNormSet => _chosen.map((String s) => normalizeText(s)).toSet();

  @override
  void initState() {
    super.initState();
    _chosen = LinkedHashSet<String>();
    _filterCtrl = TextEditingController();
    for (final String chunk in widget.initialCsv.split(',')) {
      final String t = _norm(chunk);
      if (t.isNotEmpty) {
        _chosen.add(t);
      }
    }
    _filterCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  Future<void> _openTagAccentComposer() async {
    final String? createdTag = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black45,
      builder: (BuildContext dialogContext) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 26,
            bottom: 26 + MediaQuery.viewInsetsOf(dialogContext).bottom,
          ),
          child: Align(
            alignment: Alignment.center,
            child: Material(
              color: Colors.transparent,
              child: TagAccentComposerDialog(
                primaryButtonLabel: EditorCopy.tagsStudioAddButton,
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || createdTag == null || createdTag.trim().isEmpty) {
      return;
    }
    final String t = _norm(createdTag);
    if (t.isNotEmpty) {
      _chosen.add(t);
      setState(() {});
    }
  }

  Widget _chosenTagChip(String tag, ThemeData theme, Map<String, int> accents) {
    final (Color bg, Color fg) =
        tagResolvedAccentPair(tag, theme.colorScheme, accents);
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 4),
      child: InputChip(
        label: Text(tag, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        onDeleted: () {
          _chosen.remove(tag);
          setState(() {});
        },
        deleteIconColor: fg.withValues(alpha: 0.82),
        backgroundColor: bg.withValues(alpha: 0.92),
        side: BorderSide(color: fg.withValues(alpha: 0.38), width: 0.95),
      ),
    );
  }

  Widget _suggestionChip(String label, ThemeData theme, Map<String, int> accents) {
    final (Color bg0, Color fg0) =
        tagResolvedAccentPair(label, theme.colorScheme, accents);
    return ActionChip(
      avatar: Icon(
        Icons.add_rounded,
        size: 16,
        color: fg0.withValues(alpha: 0.95),
      ),
      label: Text(label),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.22,
        color: fg0,
      ),
      onPressed: () {
        _chosen.add(label);
        setState(() {});
      },
      side: BorderSide(
        color: fg0.withValues(alpha: 0.28),
        width: 0.95,
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
      backgroundColor: Color.alphaBlend(
        fg0.withValues(alpha: 0.08),
        bg0,
      ).withValues(alpha: 0.96),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, int> accentArgbByNorm = ref.watch(tagAccentArgbMapProvider).maybeWhen(
          data: (Map<String, int> m) => m,
          orElse: () => const <String, int>{},
        );
    final String qlow = _filterCtrl.text.trim().toLowerCase();
    final Iterable<TagCatalogUsageItem> pool = widget.suggestions.where(
      (TagCatalogUsageItem item) =>
          !_chosenNormSet.contains(normalizeText(item.label)) &&
          (qlow.isEmpty || item.label.toLowerCase().contains(qlow)),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: const Alignment(0.15, 0.45),
              colors: <Color>[
                Color.lerp(theme.colorScheme.primary, theme.colorScheme.surface, 0.86)!,
                theme.colorScheme.surface,
              ],
            ),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.18),
              width: 1.1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.17),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 12, 16),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.label_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      EditorCopy.tagsStudioTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: EditorCopy.tagAddTooltip,
                    visualDensity: VisualDensity.compact,
                    onPressed: _openTagAccentComposer,
                    icon: Icon(Icons.add_rounded, color: theme.colorScheme.primary),
                  ),
                  IconButton(
                    tooltip: CommonCopy.closeTooltip,
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onDismiss,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                EditorCopy.tagsStudioGuide,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.4,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (_chosen.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    EditorCopy.tagsStudioEmptyChosen,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: math.min(MediaQuery.sizeOf(context).height * 0.18, 108)),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final String t in _chosen)
                        _chosenTagChip(t, theme, accentArgbByNorm),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _filterCtrl,
                decoration: InputDecoration(
                  hintText: EditorCopy.tagSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded, size: 22),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.75),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _filterCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: CommonCopy.clearSearchTooltip,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _filterCtrl.clear(),
                          icon: const Icon(Icons.clear_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                EditorCopy.tagLibraryHint,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: math.min(MediaQuery.sizeOf(context).height * 0.34, 240)),
                child: Scrollbar(
                  thumbVisibility: true,
                  thickness: 4,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.start,
                      children: <Widget>[
                        if (pool.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            child: Text(
                              qlow.isEmpty ? EditorCopy.tagPoolEmpty : CommonCopy.noTagSearchResults,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        for (final TagCatalogUsageItem item in pool.take(60))
                          _suggestionChip(item.label, theme, accentArgbByNorm),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  TextButton(onPressed: widget.onDismiss, child: const Text(CommonCopy.actionCancel)),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => widget.onApply(_chosen.join(',')),
                    child: const Text(CommonCopy.actionApply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _EntryImageGalleryDialog extends ConsumerStatefulWidget {
  const _EntryImageGalleryDialog({
    required this.items,
    required this.initialIndex,
    required this.scaffoldMessengerContext,
  });

  final List<GalleryImageItem> items;
  final int initialIndex;
  final BuildContext scaffoldMessengerContext;

  @override
  ConsumerState<_EntryImageGalleryDialog> createState() => _EntryImageGalleryDialogState();
}

class _EntryImageGalleryDialogState extends ConsumerState<_EntryImageGalleryDialog> {
  late final PageController _pageController = PageController(initialPage: widget.initialIndex);
  late int _currentIndex = widget.initialIndex;
  bool _pageScrollEnabled = true;
  bool _downloading = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onGalleryZoomChanged(bool zoomed) {
    final bool pageScrollEnabled = !zoomed;
    if (_pageScrollEnabled == pageScrollEnabled) {
      return;
    }
    setState(() => _pageScrollEnabled = pageScrollEnabled);
  }

  Future<void> _downloadCurrentImage() async {
    if (_downloading) {
      return;
    }
    setState(() => _downloading = true);
    try {
      await downloadGalleryImage(
        ref: ref,
        scaffoldMessengerContext: widget.scaffoldMessengerContext,
        item: widget.items[_currentIndex],
      );
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size mq = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
        width: mq.width - 24,
        height: mq.height * 0.88,
        child: Stack(
          children: <Widget>[
            PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              physics: _pageScrollEnabled && widget.items.length > 1
                  ? const PageScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              onPageChanged: (int index) => setState(() {
                _currentIndex = index;
                _pageScrollEnabled = true;
              }),
              itemBuilder: (BuildContext context, int index) {
                return _GalleryImagePane(
                  item: widget.items[index],
                  isActive: index == _currentIndex,
                  onZoomChanged: _onGalleryZoomChanged,
                );
              },
            ),
            PositionedDirectional(
              top: 12,
              start: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.items.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 4,
              end: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: EditorCopy.galleryDownloadTooltip,
                    onPressed: _downloading ? null : () => unawaited(_downloadCurrentImage()),
                    icon: _downloading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_outlined, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: CommonCopy.closeTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryImagePane extends ConsumerWidget {
  const _GalleryImagePane({
    required this.item,
    required this.isActive,
    this.onZoomChanged,
  });

  final GalleryImageItem item;
  final bool isActive;
  final ValueChanged<bool>? onZoomChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (item.source) {
      GalleryImageSource.encrypted => _EncryptedGalleryImage(
          path: item.path,
          isActive: isActive,
          onZoomChanged: onZoomChanged,
        ),
      GalleryImageSource.local => _ZoomableGalleryImage(
          isActive: isActive,
          onZoomChanged: onZoomChanged,
          child: Image.file(
            File(item.path),
            fit: BoxFit.contain,
            errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
                const Icon(
              Icons.broken_image_outlined,
              color: Colors.white,
              size: 56,
            ),
          ),
        ),
    };
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

  final TransformationController _transformController = TransformationController();
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
    final bool targetZoomed = target.getMaxScaleOnAxis() > _zoomedScaleThreshold;
    if (targetZoomed != _isZoomed) {
      setState(() {
        _isZoomed = targetZoomed;
        _panEnabled = targetZoomed;
      });
      widget.onZoomChanged?.call(targetZoomed);
    }
    _zoomAnimation = Matrix4Tween(
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
              final double scale = _transformController.value.getMaxScaleOnAxis();
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

class _EncryptedGalleryImage extends ConsumerWidget {
  const _EncryptedGalleryImage({
    required this.path,
    required this.isActive,
    this.onZoomChanged,
  });

  final String path;
  final bool isActive;
  final ValueChanged<bool>? onZoomChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Uint8List?> async = ref.watch(entryCoverPreviewBytesProvider(path));
    return async.when(
      data: (Uint8List? bytes) {
        if (bytes == null || bytes.isEmpty) {
          return Center(
            child: Text(
              EditorCopy.previewUnavailable,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
            ),
          );
        }
        return _ZoomableGalleryImage(
          isActive: isActive,
          onZoomChanged: onZoomChanged,
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      error: (Object _, StackTrace _) => const Icon(
        Icons.broken_image_outlined,
        color: Colors.white,
        size: 56,
      ),
    );
  }
}

InputDecoration _titleFieldDecoration(
  BuildContext context, {
  required String hintText,
  String? errorText,
}) {
  final ColorScheme cs = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hintText,
    errorText: errorText,
    hintStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          color: AppTypography.muted(cs),
        ),
    errorStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.error,
          fontWeight: FontWeight.w600,
        ),
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    contentPadding: EdgeInsets.zero,
    isDense: true,
  );
}

InputDecoration _bodyFieldDecoration(
  BuildContext context, {
  required String hintText,
}) {
  return InputDecoration(
    hintText: hintText,
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    contentPadding: EdgeInsets.zero,
    isDense: true,
  );
}

class _RestoreDraftDialog extends StatelessWidget {
  const _RestoreDraftDialog({
    required this.record,
    required this.hasExistingEntry,
  });

  final EditorDraftRecord record;
  final bool hasExistingEntry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String titleText = record.title?.trim().isNotEmpty == true
        ? record.title!.trim()
        : EditorCopy.untitledDraft;
    final String updatedAtText = DisplayFormat.formatDateTimeZh(record.updatedAt);
    return AlertDialog(
      title: const Text(EditorCopy.restoreDraftTitle),
      content: Text(
        hasExistingEntry
            ? EditorCopy.restoreDraftOverwrite(titleText, updatedAtText)
            : EditorCopy.restoreDraftPrompt(titleText, updatedAtText),
        style: theme.textTheme.bodyMedium,
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(EditorCopy.restoreDraftDecline),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(EditorCopy.restoreDraftAccept),
        ),
      ],
    );
  }
}

class _DiscardDraftDialog extends StatelessWidget {
  const _DiscardDraftDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(EditorCopy.discardDraftTitle),
      content: const Text(EditorCopy.discardDraftBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(CommonCopy.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(EditorCopy.discardDraftConfirm),
        ),
      ],
    );
  }
}

