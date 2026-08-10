/// 日記索引需要的通用文字；不包含任何人物資訊。
final class EntryIndexText {
  const EntryIndexText({
    required this.previewText,
    required this.searchText,
    required this.visibleText,
  });

  final String previewText;
  final String searchText;
  final String visibleText;

  factory EntryIndexText.fromMarkdown(String markdown) {
    final ({String searchText, String visibleText}) text = _extractText(
      markdown,
    );
    final String previewText = text.searchText.length <= 80
        ? text.searchText
        : '${text.searchText.substring(0, 80).trim()}…';
    return EntryIndexText(
      previewText: previewText,
      searchText: text.searchText,
      visibleText: text.visibleText,
    );
  }
}

({String searchText, String visibleText}) _extractText(String markdown) {
  final String normalized = markdown
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final StringBuffer searchBuffer = StringBuffer();
  final StringBuffer visibleBuffer = StringBuffer();
  bool inFence = false;

  for (final String rawLine in normalized.split('\n')) {
    final String trimmed = rawLine.trimRight();
    final String searchLine = _searchableMarkdownLine(trimmed);
    if (searchLine.isNotEmpty) {
      if (searchBuffer.isNotEmpty) {
        searchBuffer.write(' ');
      }
      searchBuffer.write(searchLine);
    }
    final String fenceProbe = trimmed.trimLeft();
    if (fenceProbe.startsWith('```') || fenceProbe.startsWith('~~~')) {
      inFence = !inFence;
      continue;
    }
    if (inFence) {
      continue;
    }
    final String visible = _stripMarkdownLine(trimmed);
    if (visible.isEmpty) {
      continue;
    }
    if (visibleBuffer.isNotEmpty) {
      visibleBuffer.write(' ');
    }
    visibleBuffer.write(visible);
  }
  return (
    searchText: searchBuffer.toString().trim(),
    visibleText: visibleBuffer.toString().trim(),
  );
}

String _searchableMarkdownLine(String line) {
  final String trimmed = line.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final String withoutCheckbox = trimmed.replaceFirst(
    RegExp(r'^-\s*\[[ xX]\]\s*'),
    '',
  );
  return withoutCheckbox
      .toLowerCase()
      .replaceAll(RegExp(r'[#>*_`\[\]\(\)!-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _stripMarkdownLine(String line) {
  String text = line.trim();
  if (text.isEmpty) {
    return '';
  }

  text = text.replaceFirst(RegExp(r'^#{1,6}\s+'), '');
  text = text.replaceFirst(RegExp(r'^>\s?'), '');
  text = text.replaceFirst(RegExp(r'^[-*+]\s+\[[ xX]\]\s+'), '');
  text = text.replaceFirst(RegExp(r'^[-*+]\s+'), '');
  text = text.replaceFirst(RegExp(r'^\d+\.\s+'), '');
  text = text.replaceAll(RegExp(r'`[^`]*`'), ' ');
  text = text.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
    (Match match) => match.group(1) ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]*\)'),
    (Match match) => match.group(1) ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\[[^\]]*\]'),
    (Match match) => match.group(1) ?? '',
  );
  text = text.replaceAll(RegExp(r'[*_]{1,3}'), '');
  text = text.replaceAll(RegExp(r'<https?://[^>]+>'), ' ');
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
