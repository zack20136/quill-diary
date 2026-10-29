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
  late final LinkedHashMap<String, String> _chosenByNorm;
  late final TextEditingController _filterCtrl;
  late final ScrollController _tagPoolScrollController = ScrollController();

  String _norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

  void _addChosen(String raw) {
    final String display = _norm(raw);
    if (display.isEmpty) {
      return;
    }
    _chosenByNorm.putIfAbsent(normalizeText(display), () => display);
  }

  @override
  void initState() {
    super.initState();
    _chosenByNorm = LinkedHashMap<String, String>();
    _filterCtrl = TextEditingController();
    for (final String chunk in widget.initialCsv.split(',')) {
      _addChosen(chunk);
    }
    _filterCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    _tagPoolScrollController.dispose();
    super.dispose();
  }

  Future<void> _openTagAccentComposer() async {
    final String? createdTag = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: context.appColors.scrim,
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
                primaryButtonLabel: context.l10n.editorTagsStudioAddButton,
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || createdTag == null || createdTag.trim().isEmpty) {
      return;
    }
    setState(() {
      _addChosen(createdTag);
    });
  }

  Widget _chosenTagChip(
    String tag,
    ThemeData theme,
    Map<String, int> accents,
    AppColors colors,
  ) {
    final (Color bg, Color fg) = tagResolvedAccentPair(
      tag,
      theme.colorScheme,
      accents,
      colors,
    );
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 4),
      child: InputChip(
        label: Text(
          tag,
          style: TextStyle(color: fg, fontWeight: FontWeight.w700),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        onDeleted: () {
          _chosenByNorm.remove(normalizeText(tag));
          setState(() {});
        },
        deleteIconColor: fg.withValues(alpha: 0.82),
        backgroundColor: bg,
        side: tagBorderSide(colors, theme.colorScheme, bg, fg, width: 0.95),
      ),
    );
  }

  Widget _suggestionChip(
    String label,
    ThemeData theme,
    Map<String, int> accents,
    AppColors colors,
  ) {
    final (Color bg0, Color fg0) = tagResolvedAccentPair(
      label,
      theme.colorScheme,
      accents,
      colors,
    );
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
        setState(() {
          _addChosen(label);
        });
      },
      side: tagBorderSide(colors, theme.colorScheme, bg0, fg0, width: 0.95),
      elevation: 0,
      shadowColor: Colors.transparent,
      backgroundColor: bg0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = context.appColors;
    final Map<String, int> accentArgbByNorm = ref
        .watch(tagAccentArgbMapProvider)
        .maybeWhen(
          data: (Map<String, int> m) => m,
          orElse: () => const <String, int>{},
        );
    final String qlow = _filterCtrl.text.trim().toLowerCase();
    final Iterable<TagCatalogUsageItem> pool = widget.suggestions.where(
      (TagCatalogUsageItem item) =>
          !_chosenByNorm.containsKey(normalizeText(item.label)) &&
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
                colors.accentDialogGradientStart,
                colors.accentDialogGradientEnd,
              ],
            ),
            border: Border.all(color: colors.accentDialogBorder, width: 1.1),
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
                        context.l10n.editorTagsStudioTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.editorTagAddTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: _openTagAccentComposer,
                      icon: Icon(
                        Icons.add_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.commonCloseTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onDismiss,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Text(
                  context.l10n.editorTagsStudioGuide,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                if (_chosenByNorm.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      context.l10n.editorTagsStudioEmptyChosen,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.min(
                      MediaQuery.sizeOf(context).height * 0.18,
                      108,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final String t in _chosenByNorm.values)
                          _chosenTagChip(t, theme, accentArgbByNorm, colors),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _filterCtrl,
                  decoration: InputDecoration(
                    hintText: context.l10n.editorTagSearchHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 22),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerLow.withValues(
                      alpha: 0.75,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _filterCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: context.l10n.commonClearSearchTooltip,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _filterCtrl.clear(),
                            icon: const Icon(Icons.clear_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.l10n.editorTagLibraryHint,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.min(
                      MediaQuery.sizeOf(context).height * 0.34,
                      240,
                    ),
                  ),
                  child: NestedPanelScrollbar(
                    controller: _tagPoolScrollController,
                    contentPadding: const EdgeInsets.only(right: 8, bottom: 2),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.start,
                      children: <Widget>[
                        if (pool.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            child: Text(
                              qlow.isEmpty
                                  ? context.l10n.editorTagPoolEmpty
                                  : context.l10n.commonNoTagSearchResults,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        for (final TagCatalogUsageItem item in pool.take(60))
                          _suggestionChip(
                            item.label,
                            theme,
                            accentArgbByNorm,
                            colors,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: widget.onDismiss,
                      child: Text(context.l10n.commonActionCancel),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () =>
                          widget.onApply(_chosenByNorm.values.join(',')),
                      child: Text(context.l10n.commonActionApply),
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

class _GalleryImagePane extends ConsumerWidget {
  const _GalleryImagePane({required this.item});

  final GalleryImageItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color foreground = context.appColors.galleryForeground;
    return switch (item.source) {
      GalleryImageSource.encrypted => _EncryptedGalleryImage(path: item.path),
      GalleryImageSource.local => Image.file(
        File(item.path),
        fit: BoxFit.contain,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) => Icon(Icons.broken_image_outlined, color: foreground, size: 56),
      ),
    };
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
        : context.l10n.editorUntitledDraft;
    final String updatedAtText = DisplayFormat.formatDateTime(
      context.l10n,
      record.updatedAt,
    );
    return AppDialogShell(
      title: context.l10n.editorRestoreDraftTitle,
      content: Text(
        hasExistingEntry
            ? context.l10n.editorRestoreDraftOverwrite(titleText, updatedAtText)
            : context.l10n.editorRestoreDraftPrompt(titleText, updatedAtText),
        style: theme.textTheme.bodyMedium,
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.editorRestoreDraftDecline),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.editorRestoreDraftAccept),
        ),
      ],
    );
  }
}

class _DiscardDraftDialog extends StatelessWidget {
  const _DiscardDraftDialog();

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      title: context.l10n.editorDiscardDraftTitle,
      content: Text(context.l10n.editorDiscardDraftBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.commonActionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.editorDiscardDraftConfirm),
        ),
      ],
    );
  }
}
