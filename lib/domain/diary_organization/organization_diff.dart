import 'package:flutter/widgets.dart' show StringCharacters;

enum OrganizationDiffKind { same, removed, added }

class OrganizationDiffSpan {
  const OrganizationDiffSpan(this.kind, this.text);
  final OrganizationDiffKind kind;
  final String text;
}

class OrganizationDiffLine {
  const OrganizationDiffLine(this.kind, this.text, this.spans);
  final OrganizationDiffKind kind;
  final String text;
  final List<OrganizationDiffSpan> spans;
}

List<OrganizationDiffLine> organizationDiffLines(
  String original,
  String revised,
) {
  final alignment = _compare(_splitLines(original), _splitLines(revised));
  final aligned = alignment.spans;
  var remainingCells = 250000 - alignment.cells;
  final result = <OrganizationDiffLine>[];
  var index = 0;
  while (index < aligned.length) {
    final span = aligned[index];
    if (span.kind == OrganizationDiffKind.same) {
      for (final line in _splitLines(span.text)) {
        result.add(
          OrganizationDiffLine(span.kind, line, [
            OrganizationDiffSpan(span.kind, line),
          ]),
        );
      }
      index++;
      continue;
    }
    final removed = <String>[];
    final added = <String>[];
    while (index < aligned.length &&
        aligned[index].kind != OrganizationDiffKind.same) {
      final change = aligned[index++];
      (change.kind == OrganizationDiffKind.removed ? removed : added).addAll(
        _splitLines(change.text),
      );
    }
    final oldLines = <OrganizationDiffLine>[];
    final newLines = <OrganizationDiffLine>[];
    final count = removed.length > added.length ? removed.length : added.length;
    for (var i = 0; i < count; i++) {
      final before = i < removed.length ? removed[i] : '';
      final after = i < added.length ? added[i] : '';
      final comparison = _compare(
        before.characters.toList(),
        after.characters.toList(),
        maxCells: remainingCells,
      );
      remainingCells -= comparison.cells;
      final changes = comparison.spans;
      if (i < removed.length) {
        oldLines.add(
          OrganizationDiffLine(
            OrganizationDiffKind.removed,
            before,
            changes.where((s) => s.kind != OrganizationDiffKind.added).toList(),
          ),
        );
      }
      if (i < added.length) {
        newLines.add(
          OrganizationDiffLine(
            OrganizationDiffKind.added,
            after,
            changes
                .where((s) => s.kind != OrganizationDiffKind.removed)
                .toList(),
          ),
        );
      }
    }
    result.addAll(oldLines);
    result.addAll(newLines);
  }
  return result;
}

List<String> _splitLines(String text) =>
    RegExp(r'[^\r\n]*(?:\r\n|\r|\n)|[^\r\n]+$')
        .allMatches(text)
        .map((m) => m[0]!)
        .toList();

({List<OrganizationDiffSpan> spans, int cells}) _compare(
  List<String> left,
  List<String> right, {
  int maxCells = 250000,
}) {
  final result = <OrganizationDiffSpan>[];
  var buffer = StringBuffer();
  var kind = OrganizationDiffKind.same;
  void flush() {
    if (buffer.isNotEmpty) {
      result.add(OrganizationDiffSpan(kind, buffer.toString()));
      buffer = StringBuffer();
    }
  }

  void add(OrganizationDiffKind next, String text) {
    if (text.isEmpty) return;
    if (kind != next) {
      flush();
      kind = next;
    }
    buffer.write(text);
  }

  var prefix = 0;
  while (prefix < left.length &&
      prefix < right.length &&
      left[prefix] == right[prefix]) {
    prefix++;
  }
  add(OrganizationDiffKind.same, left.take(prefix).join());
  var suffix = 0;
  while (suffix < left.length - prefix &&
      suffix < right.length - prefix &&
      left[left.length - 1 - suffix] == right[right.length - 1 - suffix]) {
    suffix++;
  }
  final a = left.sublist(prefix, left.length - suffix);
  final b = right.sublist(prefix, right.length - suffix);
  // 行對齊與字素比較共用整份對比的矩陣額度，長文不逐行重設上限。
  var cells = 0;
  if (a.isEmpty || b.isEmpty || (a.length + 1) * (b.length + 1) > maxCells) {
    add(OrganizationDiffKind.removed, a.join());
    add(OrganizationDiffKind.added, b.join());
  } else {
    cells = (a.length + 1) * (b.length + 1);
    final lengths = List.generate(
      a.length + 1,
      (_) => List.filled(b.length + 1, 0),
    );
    for (var i = a.length - 1; i >= 0; i--) {
      for (var j = b.length - 1; j >= 0; j--) {
        lengths[i][j] = a[i] == b[j]
            ? 1 + lengths[i + 1][j + 1]
            : (lengths[i + 1][j] > lengths[i][j + 1]
                  ? lengths[i + 1][j]
                  : lengths[i][j + 1]);
      }
    }
    var i = 0;
    var j = 0;
    while (i < a.length || j < b.length) {
      if (i < a.length && j < b.length && a[i] == b[j]) {
        add(OrganizationDiffKind.same, a[i++]);
        j++;
      } else if (j == b.length ||
          i < a.length && lengths[i + 1][j] >= lengths[i][j + 1]) {
        add(OrganizationDiffKind.removed, a[i++]);
      } else {
        add(OrganizationDiffKind.added, b[j++]);
      }
    }
  }
  add(OrganizationDiffKind.same, left.skip(left.length - suffix).join());
  flush();
  return (spans: result, cells: cells);
}
