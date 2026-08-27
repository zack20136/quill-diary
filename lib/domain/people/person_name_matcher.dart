import '../shared/value_objects.dart';
import 'person.dart';

/// 純規則姓名比對：中文、英數與混合姓名共用最長優先的非重疊掃描。
///
/// 姓名首尾若與相鄰文字同為 ASCII 英數就不算完整邊界；中文、空白與
/// 標點皆可作為邊界，避免 `test` 誤命中 `testing`，同時支援 `張1a`。
final class PersonNameMatcher {
  PersonNameMatcher(Iterable<Person> people) {
    for (final Person person in people) {
      for (final String name in person.allNormalizedNames) {
        if (name.isEmpty) {
          continue;
        }
        _root.insert(name.runes.toList(growable: false), person.id);
      }
    }
  }

  final _PersonNameTrieNode _root = _PersonNameTrieNode();

  /// 回傳文字中命中的人物 ID（同篇多次／多別名只算一次）。
  Set<PersonId> match(String normalizedText) {
    if (normalizedText.isEmpty || _root.children.isEmpty) {
      return const <PersonId>{};
    }
    final String haystack = normalizePersonName(normalizedText);
    if (haystack.isEmpty) {
      return const <PersonId>{};
    }

    final Set<PersonId> hits = <PersonId>{};
    final List<int> runes = haystack.runes.toList(growable: false);
    int index = 0;
    while (index < runes.length) {
      final _TrieMatch? best = _longestValidMatchAt(runes, index, _root);
      if (best == null) {
        index += 1;
        continue;
      }
      hits.addAll(best.personIds);
      index += best.length;
    }
    return hits;
  }

  /// 標題與正文結果聯集。
  Set<PersonId> matchTitleAndBody({
    required String title,
    required String body,
  }) {
    return <PersonId>{...match(title), ...match(body)};
  }

  /// 找出原文中非重疊的姓名命中區間（最長優先），供匯出匿名化使用。
  ///
  /// 掃描規則與 [match] 相同（trim、小寫、連續空白合併為單一空白），
  /// 但 [start]/[end] 映射回原文字串的 UTF-16 code unit 索引。
  List<PersonNameSpan> findSpans(String text) {
    if (text.isEmpty || _root.children.isEmpty) {
      return const <PersonNameSpan>[];
    }

    final _NormalizedScan scan = _buildNormalizedScan(text);
    if (scan.runes.isEmpty) {
      return const <PersonNameSpan>[];
    }

    final List<PersonNameSpan> spans = <PersonNameSpan>[];
    var index = 0;
    while (index < scan.runes.length) {
      final _TrieMatch? best = _longestValidMatchAt(scan.runes, index, _root);
      if (best == null) {
        index += 1;
        continue;
      }
      final List<PersonId> ids = best.personIds.toList(growable: false)..sort();
      final int endRune = index + best.length;
      spans.add(
        PersonNameSpan(
          start: scan.origStarts[index],
          end: scan.origEnds[endRune - 1],
          personId: ids.first,
        ),
      );
      index = endRune;
    }
    return spans;
  }
}

/// 原文中的一處人物姓名命中。
final class PersonNameSpan {
  const PersonNameSpan({
    required this.start,
    required this.end,
    required this.personId,
  });

  final int start;
  final int end;
  final PersonId personId;
}

final class _PersonNameTrieNode {
  final Map<int, _PersonNameTrieNode> children = <int, _PersonNameTrieNode>{};
  final Set<PersonId> personIds = <PersonId>{};

  void insert(List<int> runes, PersonId personId) {
    _PersonNameTrieNode node = this;
    for (final int rune in runes) {
      node = node.children.putIfAbsent(rune, _PersonNameTrieNode.new);
    }
    node.personIds.add(personId);
  }
}

final class _TrieMatch {
  const _TrieMatch(this.personIds, this.length);

  final Set<PersonId> personIds;
  final int length;
}

final class _NormalizedScan {
  const _NormalizedScan({
    required this.runes,
    required this.origStarts,
    required this.origEnds,
  });

  final List<int> runes;
  final List<int> origStarts;
  final List<int> origEnds;
}

/// 與 [normalizePersonName] 同規則，並保留每個正規化 rune 對應的原文區間。
_NormalizedScan _buildNormalizedScan(String text) {
  final List<int> runes = text.runes.toList(growable: false);
  final List<int> runeStarts = <int>[];
  var codeUnitOffset = 0;
  for (final int rune in runes) {
    runeStarts.add(codeUnitOffset);
    codeUnitOffset += rune > 0xFFFF ? 2 : 1;
  }

  int start = 0;
  while (start < runes.length && _isWhitespace(runes[start])) {
    start += 1;
  }
  var end = runes.length;
  while (end > start && _isWhitespace(runes[end - 1])) {
    end -= 1;
  }

  final List<int> normRunes = <int>[];
  final List<int> origStarts = <int>[];
  final List<int> origEnds = <int>[];

  var index = start;
  while (index < end) {
    final int rune = runes[index];
    if (_isWhitespace(rune)) {
      final int wsStartCu = runeStarts[index];
      while (index < end && _isWhitespace(runes[index])) {
        index += 1;
      }
      final int wsEndCu = index < runeStarts.length
          ? runeStarts[index]
          : text.length;
      if (normRunes.isEmpty || normRunes.last != 0x20) {
        normRunes.add(0x20);
        origStarts.add(wsStartCu);
        origEnds.add(wsEndCu);
      } else {
        origEnds[origEnds.length - 1] = wsEndCu;
      }
      continue;
    }

    final int lower = (rune >= 0x41 && rune <= 0x5A) ? rune + 32 : rune;
    final int next = index + 1;
    normRunes.add(lower);
    origStarts.add(runeStarts[index]);
    origEnds.add(next < runeStarts.length ? runeStarts[next] : text.length);
    index = next;
  }

  return _NormalizedScan(
    runes: normRunes,
    origStarts: origStarts,
    origEnds: origEnds,
  );
}

_TrieMatch? _longestValidMatchAt(
  List<int> haystack,
  int start,
  _PersonNameTrieNode root,
) {
  _PersonNameTrieNode? node = root;
  _TrieMatch? longest;
  for (int index = start; index < haystack.length; index++) {
    node = node?.children[haystack[index]];
    if (node == null) {
      break;
    }
    if (node.personIds.isNotEmpty &&
        _hasValidAsciiBoundaries(haystack, start, index)) {
      longest = _TrieMatch(node.personIds, index - start + 1);
    }
  }
  return longest;
}

bool _hasValidAsciiBoundaries(List<int> runes, int start, int end) {
  if (start > 0 &&
      _isAsciiLetterOrDigit(runes[start - 1]) &&
      _isAsciiLetterOrDigit(runes[start])) {
    return false;
  }
  if (end + 1 < runes.length &&
      _isAsciiLetterOrDigit(runes[end]) &&
      _isAsciiLetterOrDigit(runes[end + 1])) {
    return false;
  }
  return true;
}

bool _isAsciiLetterOrDigit(int code) {
  return (code >= 0x30 && code <= 0x39) ||
      (code >= 0x41 && code <= 0x5A) ||
      (code >= 0x61 && code <= 0x7A);
}

bool _isWhitespace(int code) {
  // 與 [normalizePersonName] 的 `\s+` 對齊常見空白。
  return code == 0x09 ||
      code == 0x0A ||
      code == 0x0B ||
      code == 0x0C ||
      code == 0x0D ||
      code == 0x20 ||
      code == 0x85 ||
      code == 0xA0 ||
      code == 0x1680 ||
      (code >= 0x2000 && code <= 0x200A) ||
      code == 0x2028 ||
      code == 0x2029 ||
      code == 0x202F ||
      code == 0x205F ||
      code == 0x3000;
}
