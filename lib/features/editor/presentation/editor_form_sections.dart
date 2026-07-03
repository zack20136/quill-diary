import 'package:flutter/material.dart';

import '../../../infrastructure/preferences/editor_typography_preferences.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/presentation/display_format.dart';
import '../../../app/app_colors.dart';
import '../../../shared/presentation/page_style.dart';
import '../../../shared/presentation/tag_visual.dart';
import '../../../shared/presentation/widgets/tag_chip.dart';
import '../application/editor_body_blocks.dart';
import 'editor_hybrid_body.dart';
import 'editor_keyboard_chrome.dart';
import 'editor_markdown_preview.dart';

class EditorTitleSection extends StatelessWidget {
  const EditorTitleSection({
    super.key,
    required this.previewMode,
    required this.titleController,
    required this.bodyController,
    required this.tagsController,
    required this.typography,
    required this.showEntryRequiredHint,
    required this.showUnsavedTag,
    required this.showMetadataTags,
    required this.tagAccentArgbMap,
  });

  final bool previewMode;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final TextEditingController tagsController;
  final EditorTypographyPreferences typography;
  final bool showEntryRequiredHint;
  final bool showUnsavedTag;
  final bool showMetadataTags;
  final Map<String, int> tagAccentArgbMap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle titleStyle = typography.titleTextStyle(theme.textTheme);
    final int bodyCharCount = bodyController.text.runes.length;
    final bool hasTagMetadata =
        _editableTagListPreview(tagsController.text).isNotEmpty ||
        bodyCharCount > 0 ||
        (previewMode && showUnsavedTag);
    final bool showTagsRow = showMetadataTags && hasTagMetadata;
    final Widget tagsWrap = ListenableBuilder(
      listenable: bodyController,
      builder: (BuildContext context, Widget? child) {
        final int liveBodyCharCount = bodyController.text.runes.length;
        return _TagsWrap(
          theme: theme,
          tagsCsv: tagsController.text,
          bodyCharCount: liveBodyCharCount,
          showCharCount: true,
          showUnsavedTag: previewMode ? showUnsavedTag : false,
          tagAccentArgbMap: tagAccentArgbMap,
        );
      },
    );

    if (previewMode) {
      final String titleText = titleController.text.trim();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            titleText.isEmpty ? context.l10n.editorUntitledDraft : titleText,
            style: titleStyle.copyWith(
              color: titleText.isEmpty
                  ? context.appColors.mutedForeground
                  : null,
            ),
          ),
          AnimatedSize(
            duration: kEditorChromeEnterDuration,
            reverseDuration: kEditorChromeExitDuration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            clipBehavior: Clip.hardEdge,
            child: showTagsRow
                ? Column(
                    key: const ValueKey<String>('editor-title-tags-visible'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const SizedBox(height: 10),
                      tagsWrap,
                    ],
                  )
                : const SizedBox(
                    key: ValueKey<String>('editor-title-tags-hidden'),
                    width: double.infinity,
                  ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: titleController,
          textInputAction: TextInputAction.next,
          style: titleStyle,
          decoration: InputDecoration(
            hintText: context.l10n.editorTitleHint,
            filled: false,
            fillColor: Colors.transparent,
            errorText: showEntryRequiredHint
                ? context.l10n.editorEntryRequiredError
                : null,
            hintStyle: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: context.appColors.mutedForeground,
            ),
            errorStyle: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
        ),
        AnimatedSize(
          duration: kEditorChromeEnterDuration,
          reverseDuration: kEditorChromeExitDuration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          clipBehavior: Clip.hardEdge,
          child: showTagsRow
              ? Column(
                  key: const ValueKey<String>('editor-edit-tags-visible'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(height: 10),
                    tagsWrap,
                  ],
                )
              : const SizedBox(
                  key: ValueKey<String>('editor-edit-tags-hidden'),
                  width: double.infinity,
                ),
        ),
      ],
    );
  }
}

class EditorBodySection extends StatefulWidget {
  const EditorBodySection({
    super.key,
    required this.previewMode,
    required this.bodyController,
    required this.typography,
    required this.onBodyChanged,
    this.onPreviewCheckboxChanged,
    this.hybridBodyKey,
  });

  final bool previewMode;
  final TextEditingController bodyController;
  final EditorTypographyPreferences typography;
  final VoidCallback onBodyChanged;
  final ValueChanged<String>? onPreviewCheckboxChanged;
  final GlobalKey<EditorHybridBodyState>? hybridBodyKey;

  @override
  State<EditorBodySection> createState() => _EditorBodySectionState();
}

class _EditorBodySectionState extends State<EditorBodySection> {
  String? _previewMarkdown;

  @override
  void initState() {
    super.initState();
    _previewMarkdown = widget.bodyController.text;
  }

  @override
  void didUpdateWidget(EditorBodySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.previewMode) {
      _previewMarkdown = null;
      return;
    }
    if (oldWidget.bodyController != widget.bodyController ||
        (oldWidget.previewMode != widget.previewMode &&
            widget.bodyController.text != _previewMarkdown)) {
      _previewMarkdown = widget.bodyController.text;
    }
  }

  void _handlePreviewCheckboxChanged(String markdown) {
    setState(() => _previewMarkdown = markdown);
    widget.bodyController.text = markdown;
    widget.onPreviewCheckboxChanged?.call(markdown);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData paneTheme = Theme.of(context);
    final TextStyle bodyStyle = widget.typography.bodyTextStyle(
      paneTheme.textTheme,
    );
    final String previewMarkdown =
        _previewMarkdown ?? widget.bodyController.text;
    final Widget body = widget.previewMode
        ? SelectionArea(
            child: SingleChildScrollView(
              child: previewMarkdown.isEmpty
                  ? Text(
                      context.l10n.editorBodyEmptyPreview,
                      style: bodyStyle.copyWith(
                        fontStyle: FontStyle.italic,
                        color: context.appColors.mutedForeground,
                      ),
                    )
                  : EditorMarkdownPreview(
                      markdown: previewMarkdown,
                      typography: widget.typography,
                      interactiveCheckboxes: editorBodyHasCheckboxBlocks(
                        previewMarkdown,
                      ),
                      onMarkdownChanged: _handlePreviewCheckboxChanged,
                    ),
            ),
          )
        : EditorHybridBody(
            key: widget.hybridBodyKey,
            bodyController: widget.bodyController,
            typography: widget.typography,
            onBodyChanged: widget.onBodyChanged,
          );

    final AppColors colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.previewPanel,
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
        border: Border.fromBorderSide(
          colors.outlineBorder(),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: Theme(
          data: paneTheme.copyWith(
            inputDecorationTheme: paneTheme.inputDecorationTheme.copyWith(
              filled: false,
              fillColor: Colors.transparent,
            ),
          ),
          child: body,
        ),
      ),
    );
  }
}

class _TagsWrap extends StatelessWidget {
  const _TagsWrap({
    required this.theme,
    required this.tagsCsv,
    required this.bodyCharCount,
    required this.showCharCount,
    required this.showUnsavedTag,
    required this.tagAccentArgbMap,
  });

  final ThemeData theme;
  final String tagsCsv;
  final int bodyCharCount;
  final bool showCharCount;
  final bool showUnsavedTag;
  final Map<String, int> tagAccentArgbMap;

  @override
  Widget build(BuildContext context) {
    final List<String> tags = _editableTagListPreview(tagsCsv);
    if (tags.isEmpty &&
        (!showCharCount || bodyCharCount <= 0) &&
        !showUnsavedTag) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: <Widget>[
          if (showUnsavedTag)
            TagChip.pair(
              label: context.l10n.editorUnsavedDraftLabel,
              pair: tagUnsavedPair(theme.colorScheme, context.appColors),
            ),
          if (showCharCount && bodyCharCount > 0)
            TagChip.pair(
              label: DisplayFormat.formatCharCount(
                context.l10n,
                bodyCharCount,
              ),
              pair: tagCharCountPair(theme.colorScheme),
            ),
          ...tags.map(
            (String tag) => TagChip.pair(
              label: tag,
              pair: tagResolvedAccentPair(
                tag,
                theme.colorScheme,
                tagAccentArgbMap,
                context.appColors,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<String> _editableTagListPreview(String tagsCsv) {
  return tagsCsv
      .split(',')
      .map((String tag) => tag.trim())
      .where((String tag) => tag.isNotEmpty)
      .toList();
}
