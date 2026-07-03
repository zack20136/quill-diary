import 'package:ulid/ulid.dart';

/// Markdown task-list line: `- [ ]` or `- [x]`.
final RegExp kEditorCheckboxLinePattern = RegExp(
  r'^(\s*)-\s*\[([ xX])\]\s*(.*)$',
);

String generateEditorLineId() => 'ln_${Ulid().toCanonical().toLowerCase()}';

sealed class EditorBodyLine {
  const EditorBodyLine();

  String get id;
}

class EditorTextLine extends EditorBodyLine {
  const EditorTextLine({required this.id, required this.text});

  @override
  final String id;
  final String text;

  EditorTextLine copyWith({String? id, String? text}) {
    return EditorTextLine(id: id ?? this.id, text: text ?? this.text);
  }
}

class EditorCheckboxLine extends EditorBodyLine {
  const EditorCheckboxLine({
    required this.id,
    required this.text,
    required this.checked,
  });

  @override
  final String id;
  final String text;
  final bool checked;

  EditorCheckboxLine copyWith({
    String? id,
    String? text,
    bool? checked,
  }) {
    return EditorCheckboxLine(
      id: id ?? this.id,
      text: text ?? this.text,
      checked: checked ?? this.checked,
    );
  }

  String toMarkdownLine() {
    final String marker = checked ? 'x' : ' ';
    if (text.isEmpty) {
      return '- [$marker]';
    }
    return '- [$marker] $text';
  }
}

bool editorBodyHasCheckboxBlocks(String markdown) {
  return editorLinesHaveCheckbox(parseEditorBodyLines(markdown));
}

bool editorLinesHaveCheckbox(List<EditorBodyLine> lines) {
  for (final EditorBodyLine line in lines) {
    if (line is EditorCheckboxLine) {
      return true;
    }
  }
  return false;
}

List<EditorBodyLine> parseEditorBodyLines(String markdown) {
  final List<String> rawLines = _normalizedLines(markdown);
  if (rawLines.isEmpty) {
    return <EditorBodyLine>[EditorTextLine(id: generateEditorLineId(), text: '')];
  }

  return rawLines
      .map((String line) => _parseMarkdownLine(line))
      .toList(growable: false);
}

/// Re-parses [markdown] while reusing line ids from [previousLines] when the
/// line kind and text still match at the same index.
List<EditorBodyLine> reparseEditorBodyLinesPreservingIds(
  String markdown, {
  List<EditorBodyLine> previousLines = const <EditorBodyLine>[],
}) {
  final List<EditorBodyLine> parsed = parseEditorBodyLines(markdown);
  if (previousLines.isEmpty) {
    return parsed;
  }
  return List<EditorBodyLine>.generate(parsed.length, (int index) {
    final EditorBodyLine line = parsed[index];
    if (index >= previousLines.length) {
      return line;
    }
    final EditorBodyLine previous = previousLines[index];
    if (previous is EditorTextLine && line is EditorTextLine) {
      if (previous.text == line.text) {
        return line.copyWith(id: previous.id);
      }
    }
    if (previous is EditorCheckboxLine && line is EditorCheckboxLine) {
      if (previous.text == line.text && previous.checked == line.checked) {
        return line.copyWith(id: previous.id);
      }
    }
    return line;
  });
}

EditorBodyLine _parseMarkdownLine(String line) {
  final RegExpMatch? checkboxMatch = kEditorCheckboxLinePattern.firstMatch(line);
  if (checkboxMatch != null) {
    final String marker = checkboxMatch.group(2) ?? ' ';
    return EditorCheckboxLine(
      id: generateEditorLineId(),
      text: checkboxMatch.group(3) ?? '',
      checked: marker.toLowerCase() == 'x',
    );
  }
  return EditorTextLine(id: generateEditorLineId(), text: line);
}

String serializeEditorBodyLines(List<EditorBodyLine> lines) {
  if (lines.isEmpty) {
    return '';
  }
  return lines
      .map((EditorBodyLine line) {
        if (line is EditorCheckboxLine) {
          return line.toMarkdownLine();
        }
        return (line as EditorTextLine).text;
      })
      .join('\n');
}

EditorCheckboxLine createEmptyCheckboxLine() {
  return EditorCheckboxLine(
    id: generateEditorLineId(),
    text: '',
    checked: false,
  );
}

/// 內文含 checkbox 時，保留尾端空白文字行供繼續輸入。
List<EditorBodyLine> ensureEditorBodyLinesForEditing(List<EditorBodyLine> lines) {
  final List<EditorBodyLine> editable = lines.isEmpty
      ? <EditorBodyLine>[createEmptyTextLine()]
      : lines;
  if (!editorLinesHaveCheckbox(editable)) {
    return editable;
  }
  final EditorBodyLine lastLine = editable.last;
  if (lastLine is EditorTextLine && lastLine.text.isEmpty) {
    return editable;
  }
  return <EditorBodyLine>[...editable, createEmptyTextLine()];
}

String normalizeEditorBodyMarkdownForSave(String markdown) {
  final String trimmedLeading = markdown.replaceFirst(RegExp(r'^\s+'), '');
  if (!editorBodyHasCheckboxBlocks(trimmedLeading)) {
    return trimmedLeading.trim();
  }
  final List<EditorBodyLine> lines = ensureEditorBodyLinesForEditing(
    parseEditorBodyLines(trimmedLeading),
  );
  return serializeEditorBodyLines(lines);
}

/// 離開 checkbox 編輯時，將 line blocks 收斂為純文字 markdown。
String collapseEditorBodyToPlainMarkdown(List<EditorBodyLine> lines) {
  if (editorLinesHaveCheckbox(lines)) {
    return serializeEditorBodyLines(lines);
  }
  return normalizeEditorBodyMarkdownForSave(serializeEditorBodyLines(lines));
}

EditorTextLine createEmptyTextLine() {
  return EditorTextLine(id: generateEditorLineId(), text: '');
}

/// 新插入 checkbox 後接續的行區塊。
///
/// 僅在 checkbox 插入於文件末尾時補上一行空白文字行；
/// 若後方已有內容，則原樣保留。
List<EditorBodyLine> tailLinesAfterCheckboxInsert({
  required List<EditorBodyLine> lines,
  required int consumedThroughIndex,
  required String afterText,
}) {
  final List<EditorBodyLine> remaining = lines.sublist(consumedThroughIndex + 1);
  if (afterText.isNotEmpty) {
    return <EditorBodyLine>[
      EditorTextLine(id: generateEditorLineId(), text: afterText),
      ...remaining,
    ];
  }
  if (remaining.isNotEmpty) {
    return remaining;
  }
  return <EditorBodyLine>[createEmptyTextLine()];
}

List<EditorBodyLine> reorderEditorBodyLines({
  required List<EditorBodyLine> lines,
  required int oldIndex,
  required int newIndex,
  bool newIndexAlreadyAdjusted = false,
}) {
  if (lines.isEmpty ||
      oldIndex < 0 ||
      oldIndex >= lines.length ||
      newIndex < 0 ||
      newIndex > lines.length) {
    return lines;
  }
  var targetIndex = newIndex;
  if (!newIndexAlreadyAdjusted && targetIndex > oldIndex) {
    targetIndex--;
  }
  final List<EditorBodyLine> next = List<EditorBodyLine>.from(lines);
  final EditorBodyLine moved = next.removeAt(oldIndex);
  next.insert(targetIndex, moved);
  return next;
}

({int lineIndex, int textOffset}) offsetToLinePosition(String markdown, int offset) {
  final String normalized = markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final int safeOffset = offset.clamp(0, normalized.length);
  var lineIndex = 0;
  var lineStart = 0;
  for (int index = 0; index < safeOffset; index++) {
    if (normalized.codeUnitAt(index) == 10) {
      lineIndex++;
      lineStart = index + 1;
    }
  }
  return (lineIndex: lineIndex, textOffset: safeOffset - lineStart);
}

({List<EditorBodyLine> lines, String checkboxId}) insertCheckboxAtLineIndex({
  required List<EditorBodyLine> lines,
  required int lineIndex,
  required int textOffset,
}) {
  if (lineIndex < 0 || lineIndex >= lines.length) {
    return (lines: lines, checkboxId: '');
  }

  final EditorBodyLine line = lines[lineIndex];
  final EditorCheckboxLine checkbox = createEmptyCheckboxLine();

  if (line is EditorTextLine) {
    final int safeOffset = textOffset.clamp(0, line.text.length);
    final String before = line.text.substring(0, safeOffset);
    final String after = line.text.substring(safeOffset);
    final List<EditorBodyLine> head = lines.sublist(0, lineIndex).toList();
    if (before.isNotEmpty) {
      head.add(line.copyWith(text: before));
    }
    head.add(checkbox);
    return (
      lines: <EditorBodyLine>[
        ...head,
        ...tailLinesAfterCheckboxInsert(
          lines: lines,
          consumedThroughIndex: lineIndex,
          afterText: after,
        ),
      ],
      checkboxId: checkbox.id,
    );
  }

  if (line is EditorCheckboxLine) {
    return (
      lines: <EditorBodyLine>[
        ...lines.sublist(0, lineIndex + 1),
        checkbox,
        ...tailLinesAfterCheckboxInsert(
          lines: lines,
          consumedThroughIndex: lineIndex,
          afterText: '',
        ),
      ],
      checkboxId: checkbox.id,
    );
  }

  return (lines: lines, checkboxId: '');
}

List<EditorBodyLine> insertTextLineAfter({
  required List<EditorBodyLine> lines,
  required int lineIndex,
  String text = '',
}) {
  final EditorTextLine next = EditorTextLine(
    id: generateEditorLineId(),
    text: text,
  );
  return <EditorBodyLine>[
    ...lines.sublist(0, lineIndex + 1),
    next,
    ...lines.sublist(lineIndex + 1),
  ];
}

List<String> _normalizedLines(String markdown) {
  return markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
}

String setCheckboxLineChecked({
  required String markdown,
  required int lineIndex,
  required bool checked,
}) {
  final List<String> lines = _normalizedLines(markdown);
  if (lineIndex < 0 || lineIndex >= lines.length) {
    return markdown;
  }
  final RegExpMatch? match = kEditorCheckboxLinePattern.firstMatch(
    lines[lineIndex],
  );
  if (match == null) {
    return markdown;
  }
  final String indent = match.group(1) ?? '';
  final String text = match.group(3) ?? '';
  final String marker = checked ? 'x' : ' ';
  lines[lineIndex] = '$indent- [$marker] $text';
  return lines.join('\n');
}
