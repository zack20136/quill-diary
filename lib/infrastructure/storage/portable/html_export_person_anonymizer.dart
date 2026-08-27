import '../../../domain/people/person.dart';
import '../../../domain/people/person_name_matcher.dart';
import '../../../domain/shared/value_objects.dart';

/// 可攜式匯出時把名冊姓名換成穩定代號（人物A／Person A），不動 vault。
final class HtmlExportPersonAnonymizer {
  HtmlExportPersonAnonymizer({
    required Iterable<Person> people,
    required this.useEnglishLabels,
  }) : _matcher = PersonNameMatcher(people);

  final PersonNameMatcher _matcher;
  final bool useEnglishLabels;
  final Map<PersonId, String> _labelsByPersonId = <PersonId, String>{};
  var _nextIndex = 0;

  String anonymizePlainText(String text) {
    if (text.isEmpty) {
      return text;
    }
    final List<PersonNameSpan> spans = _matcher.findSpans(text);
    if (spans.isEmpty) {
      return text;
    }
    final StringBuffer buffer = StringBuffer();
    var cursor = 0;
    for (final PersonNameSpan span in spans) {
      if (span.start < cursor) {
        continue;
      }
      buffer.write(text.substring(cursor, span.start));
      buffer.write(_labelFor(span.personId));
      cursor = span.end;
    }
    buffer.write(text.substring(cursor));
    return buffer.toString();
  }

  /// 替換標題／標籤／正文可見區的姓名；略過 fenced code、inline code 與連結 destination。
  String anonymizeMarkdownBody(String markdown) {
    if (markdown.isEmpty) {
      return markdown;
    }

    final List<String> protected = <String>[];
    String working = markdown;

    String protect(Match match) {
      protected.add(match.group(0)!);
      return '\uE000${protected.length - 1}\uE001';
    }

    working = working.replaceAllMapped(
      RegExp(r'```[\s\S]*?```|~~~[\s\S]*?~~~'),
      protect,
    );
    working = working.replaceAllMapped(RegExp(r'`[^`\n]+`'), protect);
    working = working.replaceAllMapped(RegExp(r'\]\([^)]*\)'), protect);
    working = working.replaceAllMapped(
      RegExp(r'<https?://[^>\s]+>'),
      protect,
    );

    working = anonymizePlainText(working);

    return working.replaceAllMapped(RegExp(r'\uE000(\d+)\uE001'), (
      Match match,
    ) {
      final int index = int.parse(match.group(1)!);
      return protected[index];
    });
  }

  String _labelFor(PersonId personId) {
    final String? existing = _labelsByPersonId[personId];
    if (existing != null) {
      return existing;
    }
    final String label = useEnglishLabels
        ? 'Person ${_indexToLetters(_nextIndex)}'
        : '人物${_indexToLetters(_nextIndex)}';
    _nextIndex += 1;
    _labelsByPersonId[personId] = label;
    return label;
  }

  /// 0 → A, 25 → Z, 26 → AA。
  static String _indexToLetters(int index) {
    var value = index;
    final StringBuffer buffer = StringBuffer();
    do {
      buffer.write(String.fromCharCode(0x41 + (value % 26)));
      value = value ~/ 26 - 1;
    } while (value >= 0);
    return buffer.toString().split('').reversed.join();
  }
}
