import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:quill_diary/domain/shared/value_objects.dart';

class HomeEntryPreviewBody extends StatelessWidget {
  const HomeEntryPreviewBody({
    super.key,
    required this.previewMarkdown,
    required this.fallbackText,
    required this.textStyle,
    this.maxLines = 3,
    this.lineSpacing,
  });

  final String previewMarkdown;
  final String fallbackText;
  final TextStyle textStyle;
  final int maxLines;
  final double? lineSpacing;

  @override
  Widget build(BuildContext context) {
    final String markdown = previewMarkdown.trim();
    if (markdown.isNotEmpty && markdownHasCheckboxLines(markdown)) {
      return _OrderedMarkdownPreview(
        lines: previewLinesFromMarkdown(markdown),
        textStyle: textStyle,
        maxLines: maxLines,
        lineSpacing: lineSpacing ?? _defaultLineSpacing(textStyle),
      );
    }

    final String text = markdown.isNotEmpty ? markdown : fallbackText;
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      previewTextFromMarkdown(text, maxLength: 240),
      style: textStyle,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

double _defaultLineSpacing(TextStyle textStyle) {
  return math.max(6, (textStyle.fontSize ?? 14) * 0.5);
}

class _PreviewLineSpec {
  const _PreviewLineSpec({required this.line, required this.maxTextLines});

  final MarkdownPreviewLine line;
  final int maxTextLines;
}

int _measureTextVisualLines({
  required String text,
  required TextStyle textStyle,
  required double maxWidth,
}) {
  if (text.trim().isEmpty || maxWidth <= 0) {
    return 0;
  }

  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: textStyle),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
  return painter.computeLineMetrics().length;
}

List<_PreviewLineSpec> _buildPreviewLineSpecs({
  required List<MarkdownPreviewLine> lines,
  required int maxVisualLines,
  required TextStyle textStyle,
  required double maxWidth,
}) {
  if (lines.isEmpty || maxVisualLines <= 0) {
    return const <_PreviewLineSpec>[];
  }

  int remaining = maxVisualLines;
  final List<_PreviewLineSpec> specs = <_PreviewLineSpec>[];

  for (final MarkdownPreviewLine line in lines) {
    if (remaining <= 0) {
      break;
    }

    switch (line) {
      case MarkdownPreviewTextLine(:final String text):
        final String trimmed = text.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final int naturalLines = _measureTextVisualLines(
          text: trimmed,
          textStyle: textStyle,
          maxWidth: maxWidth,
        );
        if (naturalLines <= 0) {
          continue;
        }
        final int allocatedLines = math.min(naturalLines, remaining);
        specs.add(_PreviewLineSpec(line: line, maxTextLines: allocatedLines));
        remaining -= allocatedLines;
      case MarkdownPreviewCheckboxLine():
        specs.add(_PreviewLineSpec(line: line, maxTextLines: 1));
        remaining -= 1;
    }
  }

  return specs;
}

class _OrderedMarkdownPreview extends StatelessWidget {
  const _OrderedMarkdownPreview({
    required this.lines,
    required this.textStyle,
    required this.maxLines,
    required this.lineSpacing,
  });

  final List<MarkdownPreviewLine> lines;
  final TextStyle textStyle;
  final int maxLines;
  final double lineSpacing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<MarkdownPreviewLine> visibleLines = lines.where((
      MarkdownPreviewLine line,
    ) {
      return switch (line) {
        MarkdownPreviewTextLine(:final String text) => text.trim().isNotEmpty,
        MarkdownPreviewCheckboxLine() => true,
      };
    }).toList();

    if (visibleLines.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final List<_PreviewLineSpec> specs = _buildPreviewLineSpecs(
          lines: visibleLines,
          maxVisualLines: maxLines,
          textStyle: textStyle,
          maxWidth: constraints.maxWidth,
        );
        if (specs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int index = 0; index < specs.length; index++) ...<Widget>[
              if (index > 0) SizedBox(height: lineSpacing),
              _PreviewLine(
                line: specs[index].line,
                textStyle: textStyle,
                colorScheme: cs,
                maxTextLines: specs[index].maxTextLines,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
    required this.line,
    required this.textStyle,
    required this.colorScheme,
    required this.maxTextLines,
  });

  final MarkdownPreviewLine line;
  final TextStyle textStyle;
  final ColorScheme colorScheme;
  final int maxTextLines;

  @override
  Widget build(BuildContext context) {
    return switch (line) {
      MarkdownPreviewTextLine(:final String text) => Text(
        text.trim(),
        style: textStyle,
        maxLines: maxTextLines,
        overflow: TextOverflow.ellipsis,
      ),
      MarkdownPreviewCheckboxLine(:final bool checked, :final String text) =>
        _PreviewCheckboxRow(
          checked: checked,
          text: text.trim(),
          textStyle: textStyle,
          colorScheme: colorScheme,
          maxTextLines: maxTextLines,
        ),
    };
  }
}

class _PreviewCheckboxRow extends StatelessWidget {
  const _PreviewCheckboxRow({
    required this.checked,
    required this.text,
    required this.textStyle,
    required this.colorScheme,
    required this.maxTextLines,
  });

  final bool checked;
  final String text;
  final TextStyle textStyle;
  final ColorScheme colorScheme;
  final int maxTextLines;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = textStyle.copyWith(
      color: checked
          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.72)
          : null,
      decoration: checked ? TextDecoration.lineThrough : null,
      decorationColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
    );
    final double checkboxSize = math.max(18, (textStyle.fontSize ?? 14) * 1.25);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: SizedBox(
            width: checkboxSize,
            height: checkboxSize,
            child: Checkbox(
              value: checked,
              onChanged: null,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: text.isEmpty
              ? const SizedBox.shrink()
              : Text(
                  text,
                  style: labelStyle,
                  maxLines: maxTextLines,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ],
    );
  }
}
