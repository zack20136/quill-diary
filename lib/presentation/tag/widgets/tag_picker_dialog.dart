import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/tag/tag_catalog_usage.dart';
import 'package:quill_diary/application/tag/tag_providers.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/tag/widgets/tag_accent_composer_dialog.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/tag_visual.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

class TagPickerDialog extends ConsumerStatefulWidget {
  const TagPickerDialog({
    super.key,
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
  ConsumerState<TagPickerDialog> createState() => _TagPickerDialogState();
}

class _TagPickerDialogState extends ConsumerState<TagPickerDialog> {
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
    final String? createdTag = await showTagAccentComposerDialog(
      context: context,
      primaryButtonLabel: context.l10n.editorTagsStudioAddButton,
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
        side: accentChipBorderSide(
          colors,
          theme.colorScheme,
          bg,
          fg,
          width: 0.95,
        ),
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
      avatar: Icon(Icons.add_rounded, size: 16, color: fg0),
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
      side: accentChipBorderSide(
        colors,
        theme.colorScheme,
        bg0,
        fg0,
        width: 0.95,
      ),
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

    return AppDialogShell(
      accent: true,
      icon: const Icon(Icons.label_rounded),
      title: context.l10n.editorTagsStudioTitle,
      titleTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: context.l10n.editorTagAddTooltip,
            visualDensity: VisualDensity.compact,
            onPressed: _openTagAccentComposer,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: context.l10n.commonCloseTooltip,
            visualDensity: VisualDensity.compact,
            onPressed: widget.onDismiss,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: widget.onDismiss,
          child: Text(context.l10n.commonActionCancel),
        ),
        FilledButton(
          onPressed: () => widget.onApply(_chosenByNorm.values.join(',')),
          child: Text(context.l10n.commonActionApply),
        ),
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
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
            child: AppScrollView(
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
            child: AppScrollbar(
              controller: _tagPoolScrollController,
              nested: true,
              reserveGutter: true,
              child: SingleChildScrollView(
                controller: _tagPoolScrollController,
                padding: const EdgeInsets.only(right: 8, bottom: 2),
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
          ),
        ],
      ),
    );
  }
}
