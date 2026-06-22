import 'package:flutter/material.dart';

import '../../../infrastructure/preferences/editor_typography_preferences.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/presentation/app_typography.dart';
import '../../../shared/presentation/display_format.dart';
import '../../../shared/presentation/page_style.dart';
import '../../../shared/presentation/tag_visual.dart';
import 'editor_markdown_preview.dart';

class EditorTitleSection extends StatelessWidget {
  const EditorTitleSection({
    super.key,
    required this.previewMode,
    required this.titleController,
    required this.bodyController,
    required this.tagsController,
    required this.typography,
    required this.formattedDisplayDate,
    required this.formattedEntryTime,
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
  final String formattedDisplayDate;
  final String formattedEntryTime;
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
                  ? AppTypography.muted(theme.colorScheme)
                  : null,
            ),
          ),
          if (showTagsRow) ...<Widget>[
            const SizedBox(height: 10),
            _TagsWrap(
              theme: theme,
              tagsCsv: tagsController.text,
              bodyCharCount: bodyCharCount,
              showCharCount: true,
              showUnsavedTag: showUnsavedTag,
              tagAccentArgbMap: tagAccentArgbMap,
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              '$formattedDisplayDate · $formattedEntryTime',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
              maxLines: 1,
            ),
          ],
        ),
        const SizedBox(height: 8),
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
              color: AppTypography.muted(theme.colorScheme),
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
        if (showTagsRow) ...<Widget>[
          const SizedBox(height: 10),
          _TagsWrap(
            theme: theme,
            tagsCsv: tagsController.text,
            bodyCharCount: bodyCharCount,
            showCharCount: true,
            showUnsavedTag: false,
            tagAccentArgbMap: tagAccentArgbMap,
          ),
        ],
      ],
    );
  }
}

class EditorBodySection extends StatelessWidget {
  const EditorBodySection({
    super.key,
    required this.previewMode,
    required this.bodyController,
    required this.typography,
  });

  final bool previewMode;
  final TextEditingController bodyController;
  final EditorTypographyPreferences typography;

  @override
  Widget build(BuildContext context) {
    final ThemeData paneTheme = Theme.of(context);
    final TextStyle bodyStyle = typography.bodyTextStyle(paneTheme.textTheme);
    final Widget body = previewMode
        ? SingleChildScrollView(
            child: bodyController.text.isEmpty
                ? SelectableText(
                    context.l10n.editorBodyEmptyPreview,
                    style: bodyStyle.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppTypography.muted(paneTheme.colorScheme),
                    ),
                  )
                : EditorMarkdownPreview(
                    markdown: bodyController.text,
                    typography: typography,
                  ),
          )
        : TextField(
            controller: bodyController,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            style: bodyStyle,
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ).copyWith(hintText: context.l10n.editorBodyHint),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: PageStyle.previewPanelFill(paneTheme.colorScheme),
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
        border: Border.fromBorderSide(
          PageStyle.outlineSide(paneTheme.colorScheme),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: body,
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
          if (showUnsavedTag) _buildUnsavedTagPill(context, theme),
          if (showCharCount && bodyCharCount > 0)
            _buildCharCountTagPill(context, theme, bodyCharCount),
          ...tags.map(
            (String tag) => _buildTagPill(tag, theme, tagAccentArgbMap),
          ),
        ],
      ),
    );
  }

  Widget _buildCharCountTagPill(
    BuildContext context,
    ThemeData theme,
    int charCount,
  ) {
    final ColorScheme cs = theme.colorScheme;
    final Color bg = Color.alphaBlend(
      cs.onSurfaceVariant.withValues(alpha: 0.12),
      cs.surface,
    );
    final Color fg = cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg.withValues(alpha: 0.92),
        border: Border.all(color: fg.withValues(alpha: 0.32), width: 0.9),
      ),
      child: Text(
        DisplayFormat.formatCharCount(context.l10n, charCount),
        style: theme.textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
      ),
    );
  }

  Widget _buildUnsavedTagPill(BuildContext context, ThemeData theme) {
    final ColorScheme cs = theme.colorScheme;
    final Color bg = Color.alphaBlend(
      cs.error.withValues(alpha: 0.14),
      cs.surface,
    );
    final Color fg = cs.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg.withValues(alpha: 0.96),
        border: Border.all(color: fg.withValues(alpha: 0.28), width: 0.9),
      ),
      child: Text(
        context.l10n.editorUnsavedDraftLabel,
        style: theme.textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
      ),
    );
  }

  Widget _buildTagPill(
    String tag,
    ThemeData theme,
    Map<String, int> tagAccentArgbMap,
  ) {
    final (Color bg, Color fg) = tagResolvedAccentPair(
      tag,
      theme.colorScheme,
      tagAccentArgbMap,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg.withValues(alpha: 0.88),
        border: Border.all(color: fg.withValues(alpha: 0.34), width: 0.9),
      ),
      child: Text(
        tag,
        style: theme.textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
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
