import 'package:flutter/material.dart';

import '../../../infrastructure/preferences/editor_typography_preferences.dart';
import '../../../shared/presentation/app_typography.dart';
import '../../../app/app_colors.dart';
import '../../../shared/presentation/page_style.dart';

class EditorMarkdownPreview extends StatelessWidget {
  const EditorMarkdownPreview({
    super.key,
    required this.markdown,
    required this.typography,
  });

  final String markdown;
  final EditorTypographyPreferences typography;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors colors = context.appColors;
    final TextStyle bodyStyle = typography.bodyTextStyle(theme.textTheme);
    final List<String> lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final List<Widget> children = <Widget>[];
    var inCodeBlock = false;
    final StringBuffer codeBuffer = StringBuffer();

    void flushCodeBlock() {
      if (codeBuffer.isEmpty) {
        return;
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
          child: SelectableText(
            codeBuffer.toString().trimRight(),
            style: AppTypography.mono(
              theme.textTheme.bodyMedium ?? const TextStyle(),
            ).copyWith(height: 1.45),
          ),
        ),
      );
      codeBuffer.clear();
    }

    for (final String rawLine in lines) {
      final String line = rawLine.trimRight();
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
        codeBuffer.writeln(rawLine);
        continue;
      }
      if (line.trim().isEmpty) {
        children.add(SizedBox(height: typography.bodyParagraphSpacing));
        continue;
      }

      final RegExpMatch? heading = RegExp(
        r'^(#{1,6})\s+(.+)$',
      ).firstMatch(line);
      if (heading != null) {
        final String text = heading.group(2)!.trim();
        children.add(
          Padding(
            padding: EdgeInsets.only(
              top: children.isEmpty ? 0 : typography.bodyParagraphSpacing,
              bottom: typography.bodyParagraphSpacing,
            ),
            child: SelectableText.rich(
              _inlineMarkdownSpan(
                text,
                typography.titleTextStyle(
                  theme.textTheme,
                  fontWeight: FontWeight.w800,
                ),
                colors.inlineCodeBackground,
              ),
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
            child: SelectableText.rich(
              _inlineMarkdownSpan(
                line.replaceFirst(RegExp(r'^>\s?'), ''),
                bodyStyle.copyWith(color: cs.onSurfaceVariant),
                colors.inlineCodeBackground,
              ),
            ),
          ),
        );
        continue;
      }

      final RegExpMatch? listItem = RegExp(
        r'^(\s*)([-*]|\d+\.)\s+(.+)$',
      ).firstMatch(line);
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
                  child: SelectableText.rich(
                    _inlineMarkdownSpan(
                      listItem.group(3)!.trim(),
                      bodyStyle,
                      colors.inlineCodeBackground,
                    ),
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
          padding: EdgeInsets.only(bottom: typography.bodyParagraphSpacing),
          child: SelectableText.rich(
            _inlineMarkdownSpan(line, bodyStyle, colors.inlineCodeBackground),
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

  TextSpan _inlineMarkdownSpan(
    String text,
    TextStyle baseStyle,
    Color inlineCodeBackground,
  ) {
    final List<InlineSpan> spans = <InlineSpan>[];
    final RegExp pattern = RegExp(
      r'(\[[^\]]+\]\([^)]+\)|\*\*[^*]+\*\*|__[^_]+__|\*[^*]+\*|_[^_]+_|`[^`]+`)',
    );
    var cursor = 0;
    for (final RegExpMatch match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final String token = match.group(0)!;
      final RegExpMatch? link = RegExp(
        r'^\[([^\]]+)\]\(([^)]+)\)$',
      ).firstMatch(token);
      if (link != null) {
        spans.add(
          TextSpan(
            text: '${link.group(1)} (${link.group(2)})',
            style: const TextStyle(
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else if (token.startsWith('**') || token.startsWith('__')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('`')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: AppTypography.mono(
              const TextStyle(),
            ).copyWith(backgroundColor: inlineCodeBackground),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: baseStyle, children: spans);
  }
}
