import '../shared/value_objects.dart';
import 'person.dart';

/// 純規則姓名比對：只接受已正規化文字與人物名稱。
///
/// - 純 CJK（不含 ASCII 字母數字）名稱：任意位置子字串、最長優先非重疊。
/// - 含拉丁／數字名稱：僅在 ASCII 字母數字 run 起點起，由左最長優先串接
///   （如 `test65485` 可同時命中 `test` 與 `65485`；`latest` 不誤吃 `test`）。
final class PersonNameMatcher {
  PersonNameMatcher(Iterable<Person> people) {
    for (final Person person in people) {
      for (final String name in person.allNormalizedNames) {
        if (name.isEmpty) {
          continue;
        }
        final List<int> runes = name.runes.toList(growable: false);
        final bool hasAscii = runes.any(_isAsciiLetterOrDigit);
        (hasAscii ? _alnumRoot : _cjkRoot).insert(runes, person.id);
      }
    }
  }

  final _PersonNameTrieNode _cjkRoot = _PersonNameTrieNode();
  final _PersonNameTrieNode _alnumRoot = _PersonNameTrieNode();

  /// 回傳文字中命中的人物 ID（同篇多次／多別名只算一次）。
  Set<PersonId> match(String normalizedText) {
    if (normalizedText.isEmpty ||
        (_cjkRoot.children.isEmpty && _alnumRoot.children.isEmpty)) {
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
      if (_isAsciiLetterOrDigit(runes[index])) {
        final int runEnd = _alnumRunEnd(runes, index);
        int pos = index;
        while (pos < runEnd) {
          final _TrieMatch? best = _longestMatchAt(
            runes,
            pos,
            _alnumRoot,
            maxEnd: runEnd,
          );
          if (best == null) {
            // 無法再由左串接：不在 run 中間任意 offset 重試拉丁匹配。
            break;
          }
          hits.addAll(best.personIds);
          pos += best.length;
        }
        index = runEnd;
        continue;
      }

      final _TrieMatch? best = _longestMatchAt(runes, index, _cjkRoot);
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

_TrieMatch? _longestMatchAt(
  List<int> haystack,
  int start,
  _PersonNameTrieNode root, {
  int? maxEnd,
}) {
  final int limit = maxEnd ?? haystack.length;
  _PersonNameTrieNode? node = root;
  _TrieMatch? longest;
  for (int index = start; index < limit; index++) {
    node = node?.children[haystack[index]];
    if (node == null) {
      break;
    }
    if (node.personIds.isNotEmpty) {
      longest = _TrieMatch(node.personIds, index - start + 1);
    }
  }
  return longest;
}

int _alnumRunEnd(List<int> runes, int start) {
  int end = start;
  while (end < runes.length && _isAsciiLetterOrDigit(runes[end])) {
    end += 1;
  }
  return end;
}

bool _isAsciiLetterOrDigit(int code) {
  return (code >= 0x30 && code <= 0x39) ||
      (code >= 0x41 && code <= 0x5A) ||
      (code >= 0x61 && code <= 0x7A);
}
