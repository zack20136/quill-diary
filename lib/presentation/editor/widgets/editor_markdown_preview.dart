import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/editor/editor_body_blocks.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/diary/diary_markdown.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_checkbox_block_row.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/app_typography.dart';
import 'package:quill_diary/shared/presentation/editor_typography_visual.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/widgets/private_text.dart';

class EditorMarkdownPreview extends StatefulWidget {
  const EditorMarkdownPreview({
    super.key,
    required this.markdown,
    required this.typography,
    this.privateRanges = const [],
    this.interactiveCheckboxes = false,
    this.onMarkdownChanged,
  });

  final String markdown;
  final EditorTypographyPreferences typography;
  final List<PrivateTextRange> privateRanges;
  final bool interactiveCheckboxes;
  final ValueChanged<String>? onMarkdownChanged;

  @override
  State<EditorMarkdownPreview> createState() => _EditorMarkdownPreviewState();
}

class _EditorMarkdownPreviewState extends State<EditorMarkdownPreview> {
  late String _markdown;
  List<String> _lines = <String>[];
  List<int> _lineOffsets = <int>[];

  @override
  void initState() {
    super.initState();
    _syncSource(widget.markdown);
  }

  @override
  void didUpdateWidget(EditorMarkdownPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markdown != widget.markdown) {
      _syncSource(widget.markdown);
    }
  }

  void _syncSource(String markdown) {
    _markdown = markdown;
    final breaks = RegExp(r'\r\n|\r|\n');
    _lines = markdown.split(breaks);
    _lineOffsets = [
      0,
      for (final match in breaks.allMatches(markdown)) match.end,
    ];
  }

  void _setMarkdown(String next) {
    if (next == _markdown) {
      return;
    }
    setState(() {
      _syncSource(next);
    });
    widget.onMarkdownChanged?.call(next);
  }

  void _toggleCheckbox(int lineIndex, bool checked) {
    final String next = setCheckboxLineChecked(
      markdown: _markdown,
      lineIndex: lineIndex,
      checked: checked,
    );
    _setMarkdown(next);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors colors = context.appColors;
    final TextStyle bodyStyle = widget.typography.bodyTextStyle(
      theme.textTheme,
    );
    final List<String> lines = _lines;
    final List<Widget> children = <Widget>[];
    var inCodeBlock = false;
    final codeLines = <({String text, int offset})>[];

    void flushCodeBlock() {
      if (codeLines.isEmpty) {
        return;
      }
      final paragraph = _MarkdownParagraph(widget.privateRanges);
      final lastContent = codeLines.lastIndexWhere(
        (line) => line.text.trimRight().isNotEmpty,
      );
      for (var i = 0; i <= lastContent; i++) {
        final line = codeLines[i];
        paragraph.writeSource(
          i == lastContent ? line.text.trimRight() : line.text,
          line.offset,
        );
        if (i < lastContent) paragraph.write('\n');
      }
      children.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
          ),
          child: paragraph.build(
            AppTypography.mono(theme.textTheme.bodyMedium ?? const TextStyle())
                .copyWith(height: 1.45),
          ),
        ),
      );
      codeLines.clear();
    }

    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final String rawLine = lines[lineIndex];
      final String line = rawLine.trimRight();
      final sourceOffset = _lineOffsets[lineIndex];
      if (line.trimLeft().startsWith('```')) {
        if (inCodeBlock) {
          inCodeBlock = false;
          flushCodeBlock();
        } else {
          inCodeBlock = true;
        }
        continue;
      }
      if (inCodeBlock) {
        codeLines.add((text: rawLine, offset: sourceOffset));
        continue;
      }
      if (line.trim().isEmpty) {
        children.add(SizedBox(height: widget.typography.bodyParagraphSpacing));
        continue;
      }

      final RegExpMatch? checkboxMatch = markdownCheckboxLinePattern.firstMatch(
        line,
      );
      if (checkboxMatch != null) {
        final String marker = checkboxMatch.group(2) ?? ' ';
        final EditorCheckboxLine block = EditorCheckboxLine(
          id: 'preview-$lineIndex',
          text: checkboxMatch.group(3) ?? '',
          checked: marker.toLowerCase() == 'x',
        );
        final paragraph = _MarkdownParagraph(widget.privateRanges)
          ..writeSource(
            block.text,
            sourceOffset + line.length - block.text.length,
          );
        children.add(
          EditorCheckboxBlockRow(
            key: ValueKey<String>('preview-checkbox-$lineIndex'),
            block: block,
            typography: widget.typography,
            bodyStyle: bodyStyle,
            privateRanges: paragraph.ranges,
            editable: false,
            onCheckedChanged: widget.interactiveCheckboxes
                ? (bool checked) => _toggleCheckbox(lineIndex, checked)
                : null,
            onTextChanged: (_) {},
          ),
        );
        continue;
      }

      final RegExpMatch? heading = RegExp(r'^(#{1,6})\s+(.+)$')
          .firstMatch(line);
      if (heading != null) {
        final String text = heading.group(2)!.trim();
        children.add(
          Padding(
            padding: EdgeInsets.only(
              top: children.isEmpty
                  ? 0
                  : widget.typography.bodyParagraphSpacing,
              bottom: widget.typography.bodyParagraphSpacing,
            ),
            child: _inlineMarkdownText(
              text,
              sourceOffset +
                  line.indexOf(text, line.length - heading.group(2)!.length),
              widget.typography.titleTextStyle(
                theme.textTheme,
                fontWeight: FontWeight.w800,
              ),
              colors.inlineCodeBackground,
            ),
          ),
        );
        continue;
      }

      if (line.startsWith('>')) {
        children.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh.withValues(alpha: 0.58),
              border: Border(left: BorderSide(color: cs.primary, width: 3)),
            ),
            child: _inlineMarkdownText(
              line.replaceFirst(RegExp(r'^>\s?'), ''),
              sourceOffset + RegExp(r'^>\s?').firstMatch(line)!.end,
              bodyStyle.copyWith(color: cs.onSurfaceVariant),
              colors.inlineCodeBackground,
            ),
          ),
        );
        continue;
      }

      final RegExpMatch? listItem = RegExp(r'^(\s*)([-*]|\d+\.)\s+(.+)$')
          .firstMatch(line);
      if (listItem != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 28,
                  child: Text(
                    listItem.group(2)!,
                    style: bodyStyle.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  child: _inlineMarkdownText(
                    listItem.group(3)!.trim(),
                    sourceOffset + line.length - listItem.group(3)!.length,
                    bodyStyle,
                    colors.inlineCodeBackground,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      children.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: widget.typography.bodyParagraphSpacing,
          ),
          child: _inlineMarkdownText(
            line,
            sourceOffset,
            bodyStyle,
            colors.inlineCodeBackground,
          ),
        ),
      );
    }

    if (inCodeBlock) {
      flushCodeBlock();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _inlineMarkdownText(
    String text,
    int sourceOffset,
    TextStyle baseStyle,
    Color inlineCodeBackground,
  ) {
    final paragraph = _MarkdownParagraph(widget.privateRanges);
    final RegExp pattern = RegExp(
      r'(\[[^\]]+\]\([^)]+\)|\*\*[^*]+\*\*|__[^_]+__|\*[^*]+\*|_[^_]+_|`[^`]+`)',
    );
    var cursor = 0;
    for (final RegExpMatch match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        paragraph.writeSource(
          text.substring(cursor, match.start),
          sourceOffset + cursor,
        );
      }
      final String token = match.group(0)!;
      final RegExpMatch? link = RegExp(r'^\[([^\]]+)\]\(([^)]+)\)$')
          .firstMatch(token);
      if (link != null) {
        const linkStyle = TextStyle(
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w600,
        );
        paragraph.writeSource(
          link.group(1)!,
          sourceOffset + match.start + 1,
          style: linkStyle,
        );
        paragraph.write(' (', style: linkStyle);
        paragraph.writeSource(
          link.group(2)!,
          sourceOffset + match.start + token.indexOf('](') + 2,
          style: linkStyle,
        );
        paragraph.write(')', style: linkStyle);
      } else if (token.startsWith('**') || token.startsWith('__')) {
        paragraph.writeSource(
          token.substring(2, token.length - 2),
          sourceOffset + match.start + 2,
          style: const TextStyle(fontWeight: FontWeight.w700),
        );
      } else if (token.startsWith('`')) {
        paragraph.writeSource(
          token.substring(1, token.length - 1),
          sourceOffset + match.start + 1,
          style: AppTypography.mono(const TextStyle())
              .copyWith(backgroundColor: inlineCodeBackground),
        );
      } else {
        paragraph.writeSource(
          token.substring(1, token.length - 1),
          sourceOffset + match.start + 1,
          style: const TextStyle(fontStyle: FontStyle.italic),
        );
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      paragraph.writeSource(text.substring(cursor), sourceOffset + cursor);
    }
    return paragraph.build(baseStyle);
  }
}

/// 每段只維護來源到可見文字的位移；移除的語法及新增的標點不算隱藏文字。
class _MarkdownParagraph {
  _MarkdownParagraph(this.sourceRanges);

  final List<PrivateTextRange> sourceRanges;
  final List<InlineSpan> _spans = [];
  final List<PrivateTextRange> ranges = [];
  int _length = 0;

  void write(String text, {TextStyle? style}) {
    _spans.add(TextSpan(text: text, style: style));
    _length += text.length;
  }

  void writeSource(String text, int sourceOffset, {TextStyle? style}) {
    final localRanges = mergePrivateRanges([
      for (final range in sourceRanges)
        PrivateTextRange(range.start - sourceOffset, range.end - sourceOffset),
    ], text.length);
    var cursor = 0;
    for (final range in localRanges) {
      if (cursor < range.start) {
        write(text.substring(cursor, range.start), style: style);
      }
      ranges.add(PrivateTextRange(_length, _length + range.end - range.start));
      write(
        text.substring(range.start, range.end),
        style: style?.backgroundColor == null
            ? style
            : style!.copyWith(backgroundColor: Colors.transparent),
      );
      cursor = range.end;
    }
    if (cursor < text.length) write(text.substring(cursor), style: style);
  }

  Widget build(TextStyle style) => PrivateText.rich(
    TextSpan(style: style, children: _spans),
    ranges: ranges,
  );
}
