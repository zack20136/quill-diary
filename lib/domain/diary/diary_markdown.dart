String normalizeSearchText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[#>*_`\[\]\(\)!-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String previewTextFromMarkdown(String markdown, {int maxLength = 80}) {
  final String compact = searchableTextFromMarkdown(markdown);
  if (compact.length <= maxLength) {
    return compact;
  }

  return '${compact.substring(0, maxLength).trim()}…';
}

final RegExp markdownCheckboxLinePattern = RegExp(
  r'^(\s*)-\s*\[([ xX])\]\s*(.*)$',
);

bool markdownHasCheckboxLines(String markdown) {
  return markdown
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .any((String line) {
        return markdownCheckboxLinePattern.hasMatch(line.trimRight());
      });
}

String previewMarkdownExcerpt(String markdown, {int maxLength = 600}) {
  final String normalized = markdown
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  if (normalized.length <= maxLength) {
    return normalized;
  }
  final int lineBreak = normalized.lastIndexOf('\n', maxLength);
  if (lineBreak >= maxLength ~/ 2) {
    return normalized.substring(0, lineBreak);
  }
  return normalized.substring(0, maxLength);
}

sealed class MarkdownPreviewLine {
  const MarkdownPreviewLine();
}

final class MarkdownPreviewTextLine extends MarkdownPreviewLine {
  const MarkdownPreviewTextLine(this.text);

  final String text;
}

final class MarkdownPreviewCheckboxLine extends MarkdownPreviewLine {
  const MarkdownPreviewCheckboxLine({
    required this.checked,
    required this.text,
  });

  final bool checked;
  final String text;
}

List<MarkdownPreviewLine> previewLinesFromMarkdown(
  String markdown, {
  int maxLines = 12,
}) {
  final List<MarkdownPreviewLine> lines = <MarkdownPreviewLine>[];
  for (final String rawLine
      in markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
    if (lines.length >= maxLines) {
      break;
    }
    final String line = rawLine.trimRight();
    if (line.trim().isEmpty) {
      continue;
    }
    final RegExpMatch? checkboxMatch = markdownCheckboxLinePattern.firstMatch(
      line,
    );
    if (checkboxMatch != null) {
      lines.add(
        MarkdownPreviewCheckboxLine(
          checked: (checkboxMatch.group(2) ?? ' ').toLowerCase() == 'x',
          text: (checkboxMatch.group(3) ?? '').trim(),
        ),
      );
      continue;
    }
    lines.add(MarkdownPreviewTextLine(line.trim()));
  }
  return lines;
}

String searchableTextFromMarkdown(String markdown) {
  final List<String> lines = markdown
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final StringBuffer buffer = StringBuffer();
  for (final String rawLine in lines) {
    final String line = rawLine.trimRight();
    if (line.trim().isEmpty) {
      continue;
    }
    final RegExpMatch? checkboxMatch = markdownCheckboxLinePattern.firstMatch(
      line,
    );
    final String plainLine = checkboxMatch != null
        ? (checkboxMatch.group(3) ?? '').trim()
        : line;
    if (plainLine.isEmpty) {
      continue;
    }
    if (buffer.isNotEmpty) {
      buffer.write(' ');
    }
    buffer.write(
      plainLine
          .replaceAll(RegExp(r'[#>*_`\[\]\(\)!-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
    );
  }
  return buffer.toString().trim();
}
