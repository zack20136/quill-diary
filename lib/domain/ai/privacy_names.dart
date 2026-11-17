import 'package:quill_diary/domain/ai/privacy_text_processor.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/people/person_name_matcher.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';

/// 一次姓名掃描的結果。可確定的人名換人物代號，重名只當私密隱藏。
class PersonNameHits {
  const PersonNameHits({required this.people, required this.ambiguous});

  static const empty = PersonNameHits(people: [], ambiguous: []);

  final List<PersonTextRange> people;
  final List<PrivateTextRange> ambiguous;
}

PersonNameHits personNameRanges(String text, PersonNameMatcher? matcher) {
  if (matcher == null) return PersonNameHits.empty;
  final people = <PersonTextRange>[];
  final ambiguous = <PrivateTextRange>[];
  for (final span in matcher.findSpans(text)) {
    if (span.isAmbiguous) {
      ambiguous.add(PrivateTextRange(span.start, span.end));
    } else {
      people.add(PersonTextRange(span.start, span.end, span.personId));
    }
  }
  return PersonNameHits(people: people, ambiguous: ambiguous);
}

/// 聊天與整理共用的代號對照。欄位都指向呼叫端既有的 map，不另存格式。
class PrivacyLedger {
  PrivacyLedger({
    required this.originals,
    Map<String, String>? personTokens,
    Map<String, List<String>>? surfaces,
    Set<String>? automaticTokens,
  }) : personTokens = personTokens ?? <String, String>{},
       surfaces = surfaces ?? <String, List<String>>{},
       automaticTokens = automaticTokens ?? <String>{};

  final Map<String, String> originals;
  final Map<String, String> personTokens;
  final Map<String, List<String>> surfaces;
  final Set<String> automaticTokens;

  PrivacyTextProcessor processor({String reservedText = ''}) =>
      PrivacyTextProcessor(
        originals,
        personTokens: personTokens,
        reservedText: reservedText,
      );

  void record(ProtectedText result) {
    automaticTokens
      ..addAll(result.automaticTokens)
      ..removeAll(result.manualTokens);
    surfaces.addAll(result.surfaces);
    surfaces.removeWhere(
      (token, values) => values.every((surface) => surface == originals[token]),
    );
  }

  void writePersonSourceKeys(Map<String, String> tokenBySourceKey) {
    for (final entry in personTokens.entries) {
      tokenBySourceKey['person:${entry.key}'] = entry.value;
    }
  }
}

/// 已知人名換成人物代號。和人名起迄相同的手動選取也是人物代號；
/// 較長的手動選取、重名與既有代號字面走私密代號。
///
/// 只給 [nameMatcher]、且沒有另外指定人名時，沿用處理器自己的掃描，
/// 讓聊天既有的手動選取優先於自動人名。
ProtectedText protectNamedText(
  PrivacyTextProcessor processor,
  String text, {
  List<PrivateTextRange> manualRanges = const [],
  List<PersonTextRange> people = const [],
  List<PrivateTextRange> ambiguous = const [],
  PersonNameMatcher? nameMatcher,
  List<PrivateTextRange> extraAutomaticRanges = const [],
  List<PrivateTextRange> revealedRanges = const [],
  bool distinctSelections = false,
  bool protectLiteralTokens = false,
}) {
  if (nameMatcher != null &&
      people.isEmpty &&
      ambiguous.isEmpty &&
      !distinctSelections &&
      !protectLiteralTokens) {
    return processor.protect(
      text,
      manualRanges: manualRanges,
      nameMatcher: nameMatcher,
      extraAutomaticRanges: extraAutomaticRanges,
      revealedRanges: revealedRanges,
      distinctSelections: distinctSelections,
    );
  }
  final hits = nameMatcher == null ? null : personNameRanges(text, nameMatcher);
  final known = hits?.people ?? people;
  final unclear = hits?.ambiguous ?? ambiguous;
  return processor.protect(
    text,
    manualRanges: [
      ...manualRanges,
      if (protectLiteralTokens)
        for (final match in privacyTokenPattern.allMatches(text))
          PrivateTextRange(match.start, match.end),
    ],
    people: known,
    extraAutomaticRanges: [...extraAutomaticRanges, ...unclear],
    revealedRanges: revealedRanges,
    distinctSelections: distinctSelections,
  );
}
