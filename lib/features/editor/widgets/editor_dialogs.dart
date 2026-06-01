part of '../pages/editor_page.dart';

class _TagsStudioDialog extends ConsumerStatefulWidget {
  const _TagsStudioDialog({
    required this.initialCsv,
    required this.suggestions,
    required this.onApply,
    required this.onDismiss,
  });

  final String initialCsv;
  final List<MapEntry<String, int>> suggestions;
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
                primaryButtonLabel: '加入',
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
    final Iterable<MapEntry<String, int>> pool = widget.suggestions.where(
      (MapEntry<String, int> e) =>
          !_chosenNormSet.contains(normalizeText(e.key)) &&
          (qlow.isEmpty || e.key.toLowerCase().contains(qlow)),
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
                      '標籤',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '新增標籤',
                    visualDensity: VisualDensity.compact,
                    onPressed: _openTagAccentComposer,
                    icon: Icon(Icons.add_rounded, color: theme.colorScheme.primary),
                  ),
                  IconButton(
                    tooltip: '關閉',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onDismiss,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                '右上角可建立新標籤；下方為文庫標籤，輕觸加入。',
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
                    '尚未套用任何標籤',
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
                  hintText: '搜尋已用過的標籤…',
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
                          tooltip: '清除搜尋',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _filterCtrl.clear(),
                          icon: const Icon(Icons.clear_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '文庫裡的標籤 · 輕觸加入',
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
                              qlow.isEmpty ? '索引裡尚無可用標籤，或已全部加入目前清單' : '沒有符合的標籤',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        for (final String label
                            in pool.map((MapEntry<String, int> e) => e.key).take(60))
                          _suggestionChip(label, theme, accentArgbByNorm),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  TextButton(onPressed: widget.onDismiss, child: const Text('取消')),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => widget.onApply(_chosen.join(',')),
                    child: const Text('套用'),
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

class _EntryImageGalleryDialog extends StatefulWidget {
  const _EntryImageGalleryDialog({
    required this.items,
    required this.initialIndex,
  });

  final List<_PreviewGalleryImage> items;
  final int initialIndex;

  @override
  State<_EntryImageGalleryDialog> createState() => _EntryImageGalleryDialogState();
}

class _EntryImageGalleryDialogState extends State<_EntryImageGalleryDialog> {
  late final PageController _pageController = PageController(initialPage: widget.initialIndex);
  late int _currentIndex = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
              onPageChanged: (int index) => setState(() => _currentIndex = index),
              itemBuilder: (BuildContext context, int index) {
                return _GalleryImagePane(item: widget.items[index]);
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
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryImagePane extends ConsumerWidget {
  const _GalleryImagePane({required this.item});

  final _PreviewGalleryImage item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (item.sourceKind) {
      _PreviewGallerySourceKind.encrypted => _EncryptedGalleryImage(path: item.path),
      _PreviewGallerySourceKind.local => Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
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
        ),
    };
  }
}

class _EncryptedGalleryImage extends ConsumerWidget {
  const _EncryptedGalleryImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Uint8List?> async = ref.watch(entryCoverPreviewBytesProvider(path));
    return async.when(
      data: (Uint8List? bytes) {
        if (bytes == null || bytes.isEmpty) {
          return Center(
            child: Text(
              '無法預覽',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
            ),
          );
        }
        return Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
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
}) {
  final ColorScheme cs = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hintText,
    hintStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.28,
          letterSpacing: -0.35,
          fontStyle: FontStyle.italic,
          color: cs.onSurfaceVariant.withValues(alpha: 0.75),
        ),
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    contentPadding: EdgeInsets.zero,
    isDense: true,
  );
}

InputDecoration _bodyFieldDecoration(
  BuildContext context, {
  required String hintText,
}) {
  final ColorScheme cs = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hintText,
    hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
          height: 1.72,
          fontStyle: FontStyle.italic,
          color: cs.onSurfaceVariant.withValues(alpha: 0.85),
        ),
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    contentPadding: EdgeInsets.zero,
    isDense: true,
  );
}

