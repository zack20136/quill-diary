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
