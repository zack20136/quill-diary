import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/persona/persona.dart';

/// 姓名只在記憶體呈現，原文與隱藏座標仍以儲存代號為準。
class PersonaContent {
  PersonaContent(
    PersonaCandidate card,
    Map<String, String> names, {
    required String Function(int) unknownPerson,
  }) : source = card.text {
    final output = StringBuffer();
    var cursor = 0;
    for (final match in personaTokenPattern.allMatches(source)) {
      final token = match[0]!;
      if (!card.tokens.containsKey(token)) continue;
      output.write(source.substring(cursor, match.start));
      final name =
          names[card.tokens[token]] ??
          unknownPerson(
            int.parse(token.substring(2, token.length - 1), radix: 16),
          );
      references.add((
        source: PrivateTextRange(match.start, match.end),
        visible: PrivateTextRange(output.length, output.length + name.length),
        token: token,
      ));
      output.write(name);
      cursor = match.end;
    }
    output.write(source.substring(cursor));
    text = output.toString();
  }

  final String source;
  late final String text;
  final references =
      <({PrivateTextRange source, PrivateTextRange visible, String token})>[];
  bool get hasUnresolvedReferences => personaBareTokenPattern.hasMatch(source);

  List<PrivateTextRange> visibleRanges(Iterable<PrivateTextRange> ranges) => [
    for (final range in ranges)
      PrivateTextRange(
        _mapOffset(range.start, isEnd: false, toVisible: true),
        _mapOffset(range.end, isEnd: true, toVisible: true),
      ),
  ];

  List<PrivateTextRange> sourceRanges(Iterable<PrivateTextRange> ranges) => [
    for (final range in ranges)
      PrivateTextRange(
        _mapOffset(range.start, isEnd: false, toVisible: false),
        _mapOffset(range.end, isEnd: true, toVisible: false),
      ),
  ];

  int _mapOffset(int value, {required bool isEnd, required bool toVisible}) {
    var delta = 0;
    for (final reference in references) {
      final from = toVisible ? reference.source : reference.visible;
      final to = toVisible ? reference.visible : reference.source;
      if (value <= from.start) return value + delta;
      if (value < from.end) return isEnd ? to.end : to.start;
      delta += (to.end - to.start) - (from.end - from.start);
    }
    return value + delta;
  }
}
