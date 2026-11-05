import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/editor/editor_body_blocks.dart';
import 'package:quill_diary/application/people/person_mention_controller.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_hybrid_body.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_keyboard_chrome.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_markdown_preview.dart';
import 'package:quill_diary/presentation/people/widgets/person_mention_text_field.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/shared/presentation/editor_typography_visual.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/tag_visual.dart';
import 'package:quill_diary/shared/presentation/widgets/accent_chip.dart';

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
    this.mentionController,
    this.onMentionKeyEvent,
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
  final PersonMentionController? mentionController;
  final KeyEventResult Function(FocusNode node, KeyEvent event)?
  onMentionKeyEvent;

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
                    children: <Widget>[const SizedBox(height: 10), tagsWrap],
                  )
                : const SizedBox(
                    key: ValueKey<String>('editor-title-tags-hidden'),
                    width: double.infinity,
                  ),
          ),
        ],
      );
    }

    final InputDecoration titleDecoration = InputDecoration(
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
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (mentionController == null)
          TextField(
            controller: titleController,
            textInputAction: TextInputAction.next,
            style: titleStyle,
            decoration: titleDecoration,
          )
        else
          PersonMentionTextField(
            controller: titleController,
            mentionController: mentionController,
            onMentionKeyEvent: onMentionKeyEvent,
            textInputAction: TextInputAction.next,
            style: titleStyle,
            decoration: titleDecoration,
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
                  children: <Widget>[const SizedBox(height: 10), tagsWrap],
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
    required this.onBodyChanged,
    this.onPreviewCheckboxChanged,
    this.hybridBodyKey,
    this.mentionController,
    this.onMentionKeyEvent,
  });

  final bool previewMode;
  final TextEditingController bodyController;
  final EditorTypographyPreferences typography;
  final VoidCallback onBodyChanged;
  final ValueChanged<String>? onPreviewCheckboxChanged;
  final GlobalKey<EditorHybridBodyState>? hybridBodyKey;
  final PersonMentionController? mentionController;
  final KeyEventResult Function(FocusNode node, KeyEvent event)?
  onMentionKeyEvent;

  @override
  Widget build(BuildContext context) {
    final ThemeData paneTheme = Theme.of(context);
    final TextStyle bodyStyle = typography.bodyTextStyle(paneTheme.textTheme);
    final Widget body = previewMode
        ? ValueListenableBuilder<TextEditingValue>(
            valueListenable: bodyController,
            builder: (context, value, _) => SelectionArea(
              child: SingleChildScrollView(
                child: value.text.isEmpty
                    ? Text(
                        context.l10n.editorBodyEmptyPreview,
                        style: bodyStyle.copyWith(
                          fontStyle: FontStyle.italic,
                          color: context.appColors.mutedForeground,
                        ),
                      )
                    : EditorMarkdownPreview(
                        markdown: value.text,
                        typography: typography,
                        interactiveCheckboxes: editorBodyHasCheckboxBlocks(
                          value.text,
                        ),
                        onMarkdownChanged: (markdown) {
                          bodyController.text = markdown;
                          onPreviewCheckboxChanged?.call(markdown);
                        },
                      ),
              ),
            ),
          )
        : EditorHybridBody(
            key: hybridBodyKey,
            bodyController: bodyController,
            typography: typography,
            onBodyChanged: onBodyChanged,
            mentionController: mentionController,
            onMentionKeyEvent: onMentionKeyEvent,
          );

    final AppColors colors = context.appColors;
    return DecoratedBox(
      key: const ValueKey<String>('editor-body-section-background'),
      decoration: BoxDecoration(
        color: colors.previewPanel,
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
        border: Border.fromBorderSide(colors.outlineBorder()),
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
            AccentChip.pair(
              label: context.l10n.editorUnsavedDraftLabel,
              pair: tagUnsavedPair(context.appColors),
            ),
          if (showCharCount && bodyCharCount > 0)
            AccentChip.pair(
              label: DisplayFormat.formatCharCount(context.l10n, bodyCharCount),
              pair: tagNeutralAccentPair(theme.colorScheme),
            ),
          ...tags.map(
            (String tag) => AccentChip.pair(
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
