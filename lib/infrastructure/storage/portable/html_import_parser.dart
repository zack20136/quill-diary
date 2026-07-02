// HTML 匯入解析：從 Quill Diary 匯出的單一或多篇 HTML 擷取內容並轉回 Markdown。

bool isQuillDiaryExportHtml(String html) {
  return RegExp(
    r'<article\b[^>]*\bclass\s*=\s*"[^"]*\bentry\b',
    caseSensitive: false,
  ).hasMatch(html);
}

List<String> splitQuillDiaryArticles(String bodyHtml) {
  final RegExp pattern = RegExp(
    r'<article\b[^>]*\bclass\s*=\s*"[^"]*\bentry\b[^>]*>([\s\S]*?)</article>',
    caseSensitive: false,
  );

  return pattern
      .allMatches(bodyHtml)
      .map((Match match) => (match.group(1) ?? '').trim())
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);
}

String? extractBlockInnerHtml(String html, String tagName, String className) {
  final String lowerTag = tagName.toLowerCase();
  final RegExp opener = RegExp(
    "<$lowerTag\\b[^>]*\\bclass\\s*=\\s*['\"][^'\"]*\\b"
    '${RegExp.escape(className)}'
    "\\b[^'\"]*['\"][^>]*>",
    caseSensitive: false,
  );

  for (final Match match in opener.allMatches(html)) {
    final String? inner = extractBalancedElementInnerHtml(
      html: html,
      contentStart: match.end,
      tagName: lowerTag,
    );
    final String trimmed = inner?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

List<String> extractQuillDiaryTags(String articleHtml) {
  final String? tagsHtml = extractBlockInnerHtml(articleHtml, 'ul', 'tags');
  if (tagsHtml == null) {
    return const <String>[];
  }

  final RegExp itemPattern = RegExp(
    r'<li\b[^>]*>([\s\S]*?)</li>',
    caseSensitive: false,
  );
  return itemPattern
      .allMatches(tagsHtml)
      .map(
        (Match match) =>
            decodeHtmlEntities(stripHtmlTags(match.group(1) ?? '')).trim(),
      )
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);
}

String exportHtmlBodyToMarkdown(String html) {
  String output = html.trim();
  if (output.isEmpty) {
    return '';
  }

  output = output.replaceAllMapped(
    RegExp(r'<pre>\s*<code>([\s\S]*?)</code>\s*</pre>', caseSensitive: false),
    (Match match) =>
        '```\n${decodeHtmlEntities(match.group(1) ?? '').trimRight()}\n```\n\n',
  );
  for (int level = 6; level >= 1; level--) {
    output = output.replaceAllMapped(
      RegExp('<h$level\\b[^>]*>([\\s\\S]*?)</h$level>', caseSensitive: false),
      (Match match) =>
          '${'#' * level} ${inlineExportHtmlToMarkdown(match.group(1) ?? '')}\n\n',
    );
  }
  output = output.replaceAllMapped(
    RegExp(
      "<ul\\b[^>]*\\bclass\\s*=\\s*[\"'][^\"']*\\btask-list\\b[^\"']*[\"'][^>]*>([\\s\\S]*?)</ul>",
      caseSensitive: false,
    ),
    (Match match) {
      final String items = (match.group(1) ?? '').replaceAllMapped(
        RegExp(r'<li\b[^>]*>([\s\S]*?)</li>', caseSensitive: false),
        (Match itemMatch) {
          final String inner = itemMatch.group(1) ?? '';
          final bool checked = RegExp(
            '<input\\b[^>]*\\btype\\s*=\\s*["\']checkbox["\'][^>]*\\bchecked\\b',
            caseSensitive: false,
          ).hasMatch(inner);
          final String text = inner.replaceAll(
            RegExp(r'<input\b[^>]*>', caseSensitive: false),
            '',
          );
          final String marker = checked ? 'x' : ' ';
          return '- [$marker] ${inlineExportHtmlToMarkdown(text)}\n';
        },
      );
      return '$items\n';
    },
  );
  output = output.replaceAllMapped(
    RegExp(r'<ul\b[^>]*>([\s\S]*?)</ul>', caseSensitive: false),
    (Match match) {
      final String items = (match.group(1) ?? '').replaceAllMapped(
        RegExp(r'<li\b[^>]*>([\s\S]*?)</li>', caseSensitive: false),
        (Match itemMatch) =>
            '- ${inlineExportHtmlToMarkdown(itemMatch.group(1) ?? '')}\n',
      );
      return '$items\n';
    },
  );
  output = output.replaceAllMapped(
    RegExp(r'<p\b[^>]*>([\s\S]*?)</p>', caseSensitive: false),
    (Match match) {
      final String content = (match.group(1) ?? '').replaceAllMapped(
        RegExp(r'<br\s*/?>', caseSensitive: false),
        (_) => '\n',
      );
      return '${inlineExportHtmlToMarkdown(content)}\n\n';
    },
  );

  output = decodeHtmlEntities(stripHtmlTags(output));
  output = output.replaceAll(RegExp(r'\r\n?'), '\n');
  output = output.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  output = output.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  return output.trimRight();
}

String inlineExportHtmlToMarkdown(String html) {
  String output = html;
  output = output.replaceAllMapped(
    RegExp(r'<strong\b[^>]*>([\s\S]*?)</strong>', caseSensitive: false),
    (Match match) => '**${stripHtmlTags(match.group(1) ?? '')}**',
  );
  output = output.replaceAllMapped(
    RegExp(r'<em\b[^>]*>([\s\S]*?)</em>', caseSensitive: false),
    (Match match) => '*${stripHtmlTags(match.group(1) ?? '')}*',
  );
  output = output.replaceAllMapped(
    RegExp(r'<code\b[^>]*>([\s\S]*?)</code>', caseSensitive: false),
    (Match match) =>
        '`${decodeHtmlEntities(stripHtmlTags(match.group(1) ?? ''))}`',
  );
  output = output.replaceAllMapped(
    RegExp(
      r'''<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)</a>''',
      caseSensitive: false,
    ),
    (Match match) {
      final String href = match.group(1) ?? '';
      final String text = stripHtmlTags(match.group(2) ?? '');
      final String label = text.isEmpty ? href : text;
      return '[${escapeMarkdownText(label)}]($href)';
    },
  );
  return decodeHtmlEntities(stripHtmlTags(output)).trim();
}

String extractHtmlBody(String html) {
  final Match? match = RegExp(
    r'<body\b[^>]*>([\s\S]*?)</body>',
    caseSensitive: false,
  ).firstMatch(html);
  return match?.group(1) ?? html;
}

String? extractFirstHtmlTagText(String html, String tagName) {
  final Match? match = RegExp(
    '<$tagName\\b[^>]*>([\\s\\S]*?)</$tagName>',
    caseSensitive: false,
  ).firstMatch(html);
  if (match == null) {
    return null;
  }

  final String text = decodeHtmlEntities(
    stripHtmlTags(match.group(1) ?? ''),
  ).trim();
  return text.isEmpty ? null : text;
}

String? extractHtmlClassText(String html, String className) {
  final String? innerHtml = extractHtmlClassInnerHtml(html, className);
  if (innerHtml == null) {
    return null;
  }

  final String text = decodeHtmlEntities(stripHtmlTags(innerHtml)).trim();
  return text.isEmpty ? null : text;
}

String? extractHtmlClassInnerHtml(String html, String className) {
  final List<String> matches = extractAllHtmlClassInnerHtml(html, className);
  return matches.isEmpty ? null : matches.first;
}

List<String> extractAllHtmlClassInnerHtml(String html, String className) {
  final RegExp opener = RegExp(
    "<([a-zA-Z][a-zA-Z0-9]*)[^>]*\\bclass\\s*=\\s*['\"][^'\"]*\\b"
    '${RegExp.escape(className)}'
    "\\b[^'\"]*['\"][^>]*>",
    caseSensitive: false,
  );

  final List<String> results = <String>[];
  for (final Match match in opener.allMatches(html)) {
    final String tagName = (match.group(1) ?? '').toLowerCase();
    if (tagName.isEmpty) {
      continue;
    }
    final String? inner = extractBalancedElementInnerHtml(
      html: html,
      contentStart: match.end,
      tagName: tagName,
    );
    final String trimmed = inner?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      results.add(trimmed);
    }
  }
  return results;
}

String? extractBalancedElementInnerHtml({
  required String html,
  required int contentStart,
  required String tagName,
}) {
  final String lowerTag = tagName.toLowerCase();
  final RegExp openTag = RegExp('<$lowerTag\\b', caseSensitive: false);
  final RegExp closeTag = RegExp('</$lowerTag\\s*>', caseSensitive: false);

  var depth = 1;
  var index = contentStart;

  while (index < html.length && depth > 0) {
    final Match? nextOpen =
        openTag.matchAsPrefix(html, index) ??
        _nextRegExpMatch(openTag, html, index);
    final Match? nextClose =
        closeTag.matchAsPrefix(html, index) ??
        _nextRegExpMatch(closeTag, html, index);

    final int? openAt = nextOpen?.start;
    final int? closeAt = nextClose?.start;
    if (closeAt == null) {
      return null;
    }
    if (openAt != null && openAt < closeAt) {
      depth++;
      final int? tagEnd = _indexOfHtmlTagEnd(html, openAt);
      if (tagEnd == null) {
        return null;
      }
      index = tagEnd + 1;
      continue;
    }

    depth--;
    if (depth == 0) {
      return html.substring(contentStart, closeAt);
    }
    index = nextClose!.end;
  }

  return null;
}

Match? _nextRegExpMatch(RegExp pattern, String html, int from) {
  for (final Match match in pattern.allMatches(html, from)) {
    return match;
  }
  return null;
}

int? _indexOfHtmlTagEnd(String html, int openBracketIndex) {
  final int tagEnd = html.indexOf('>', openBracketIndex);
  return tagEnd < 0 ? null : tagEnd;
}

String stripHtmlTags(String input) {
  return input.replaceAll(RegExp(r'<[^>]+>'), ' ');
}

String decodeHtmlEntities(String input) {
  String output = input
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");

  output = output.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (
    Match match,
  ) {
    final int? codePoint = int.tryParse(match.group(1) ?? '', radix: 16);
    return codePoint == null ? match.group(0)! : String.fromCharCode(codePoint);
  });
  output = output.replaceAllMapped(RegExp(r'&#(\d+);'), (Match match) {
    final int? codePoint = int.tryParse(match.group(1) ?? '');
    return codePoint == null ? match.group(0)! : String.fromCharCode(codePoint);
  });
  return output;
}

String escapeMarkdownText(String input) {
  return input.replaceAll('[', r'\[').replaceAll(']', r'\]');
}

List<String> extractHtmlAttachmentReferences(String html) {
  final List<String> references = <String>[];
  final RegExp imgPattern = RegExp(
    r'''<img\b[^>]*\bsrc\s*=\s*(["'])([\s\S]*?)\1''',
    caseSensitive: false,
  );
  for (final Match match in imgPattern.allMatches(html)) {
    final String value = (match.group(2) ?? '').trim();
    if (value.isNotEmpty) {
      references.add(value);
    }
  }

  final RegExp linkPattern = RegExp(
    r'''<a\b[^>]*\bhref\s*=\s*(["'])([\s\S]*?)\1''',
    caseSensitive: false,
  );
  for (final Match match in linkPattern.allMatches(html)) {
    final String value = (match.group(2) ?? '').trim();
    if (value.isNotEmpty && !isIgnoredImportReference(value)) {
      references.add(value);
    }
  }

  return references;
}

bool isIgnoredImportReference(String reference) {
  final String lower = reference.toLowerCase();
  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('mailto:') ||
      lower.startsWith('tel:') ||
      lower.startsWith('#');
}
