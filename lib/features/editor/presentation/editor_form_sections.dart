import 'package:flutter/material.dart';

import '../../../infrastructure/preferences/editor_typography_preferences.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/presentation/display_format.dart';
import '../../../app/app_colors.dart';
import '../../../shared/presentation/page_style.dart';
import '../../../shared/presentation/tag_visual.dart';
import '../../../shared/presentation/widgets/tag_chip.dart';
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
                      _TagsWrap(
                        theme: theme,
                        tagsCsv: tagsController.text,
                        bodyCharCount: bodyCharCount,
                        showCharCount: true,
                        showUnsavedTag: showUnsavedTag,
                        tagAccentArgbMap: tagAccentArgbMap,
                      ),
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
                    _TagsWrap(
                      theme: theme,
                      tagsCsv: tagsController.text,
                      bodyCharCount: bodyCharCount,
                      showCharCount: true,
                      showUnsavedTag: false,
                      tagAccentArgbMap: tagAccentArgbMap,
                    ),
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
                      color: context.appColors.mutedForeground,
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
            decoration: InputDecoration(
              filled: false,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              hintText: context.l10n.editorBodyHint,
            ),
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
