import 'package:intl/intl.dart';
import 'package:ulid/ulid.dart';

typedef VaultId = String;
typedef EntryId = String;
typedef AssetId = String;
typedef BackupId = String;
typedef DeviceSlotId = String;

/// 穩定前綴 ID 使匯出檔案可讀，並避免跨類型混淆。
String generateVaultId() => 'vlt_${Ulid().toCanonical().toUpperCase()}';

String generateEntryId() => 'jrn_${Ulid().toCanonical().toUpperCase()}';

String generateAssetId() => 'att_${Ulid().toCanonical().toUpperCase()}';

String generateBackupId() => 'bkp_${Ulid().toCanonical().toUpperCase()}';

String generateDeviceSlotId() => 'dev_${Ulid().toCanonical().toUpperCase()}';

String normalizeText(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

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

final RegExp _markdownCheckboxLinePattern = RegExp(
  r'^\s*-\s*\[([ xX])\]\s*(.*)$',
);

bool markdownHasCheckboxLines(String markdown) {
  return markdown.replaceAll('\r\n', '\n').split('\n').any((String line) {
    return _markdownCheckboxLinePattern.hasMatch(line.trimRight());
  });
}

String previewMarkdownExcerpt(String markdown, {int maxLength = 600}) {
  final String normalized = markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
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
    final RegExpMatch? checkboxMatch = _markdownCheckboxLinePattern.firstMatch(
      line,
    );
    if (checkboxMatch != null) {
      lines.add(
        MarkdownPreviewCheckboxLine(
          checked: (checkboxMatch.group(1) ?? ' ').toLowerCase() == 'x',
          text: (checkboxMatch.group(2) ?? '').trim(),
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
    final RegExpMatch? checkboxMatch = _markdownCheckboxLinePattern.firstMatch(
      line,
    );
    final String plainLine = checkboxMatch != null
        ? (checkboxMatch.group(2) ?? '').trim()
        : line;
    if (plainLine.isEmpty) {
      continue;
    }
    if (buffer.isNotEmpty) {
      buffer.write(' ');
    }
    buffer.write(
      plainLine.replaceAll(RegExp(r'[#>*_`\[\]\(\)!-]'), ' ').replaceAll(
        RegExp(r'\s+'),
        ' ',
      ).trim(),
    );
  }
  return buffer.toString().trim();
}

/// 以 `yyyy-MM-dd` 儲存、不含時區語意的日曆日期。
class DateOnly {
  const DateOnly(this.value);

  factory DateOnly.fromDateTime(DateTime dateTime) {
    return DateOnly(DateFormat('yyyy-MM-dd').format(dateTime));
  }

  factory DateOnly.parse(String value) => DateOnly(value);

  final String value;

  int get year => int.parse(value.substring(0, 4));

  String get monthPadded => value.substring(5, 7);

  String get yearString => value.substring(0, 4);

  DateTime toDateTime() => DateTime.parse(value);

  @override
  String toString() => value;
}
