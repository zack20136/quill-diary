import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/ai/sensitive_text.dart';
import 'package:quill_diary/domain/people/person_name_matcher.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';

typedef PrivacyReplacement = ({int start, int end, String replacement});

class ProtectedText {
  const ProtectedText({
    required this.text,
    required this.manualTokens,
    required this.automaticTokens,
    required this.automaticRanges,
    required this.personRanges,
    required this.surfaces,
    required this.highlightRanges,
    this.revealedSecrets = const {},
  });
  final String text;
  final Set<String> manualTokens;
  final Set<String> automaticTokens;
  final List<PrivateTextRange> automaticRanges;
  final List<PersonTextRange> personRanges;
  final Map<String, List<String>> surfaces;
  final List<PrivateTextRange> highlightRanges;

  /// 使用者取消自動隱藏後，這次沒有改寫的原文。
  final Set<String> revealedSecrets;
}

/// 來源選擇由功能層決定；所有隱藏方式共用原文座標、代號與替換規則。
class PrivacyTextProcessor {
  PrivacyTextProcessor(
    this.originals, {
    Map<String, String>? personTokens,
    this.reservedText = '',
  }) : personTokens = personTokens ?? {};
  final Map<String, String> originals;
  final Map<String, String> personTokens;
  final String reservedText;

  String personToken(String id, String surface, {String text = ''}) =>
      privacyTokenForPerson(
        personId: id,
        surface: surface,
        tokenByPersonId: personTokens,
        originals: originals,
        reservedText: '$reservedText$text',
      );

  String _privateToken(String surface, String text, {bool reuse = true}) {
    final existing = reuse
        ? originals.entries
              .where(
                (entry) =>
                    privacyTokenHasKind(entry.key, PrivacyTokenKind.private) &&
                    entry.value == surface,
              )
              .firstOrNull
        : null;
    final token =
        existing?.key ??
        nextPrivacyToken(originals.keys, reservedText: '$reservedText$text');
    originals[token] = surface;
    return token;
  }

  ProtectedText protect(
    String text, {
    List<PrivateTextRange> manualRanges = const [],
    List<PersonTextRange> people = const [],
    PersonNameMatcher? nameMatcher,
    List<PrivateTextRange> extraAutomaticRanges = const [],
    List<PrivateTextRange> revealedRanges = const [],
    Set<String> revealedSecrets = const {},
    List<PrivacyReplacement> replacements = const [],
    bool detectAutomatically = true,
    bool distinctSelections = false,
  }) {
    validatePrivateRanges(text, manualRanges);
    validatePrivateRanges(text, extraAutomaticRanges);
    validatePrivateRanges(text, revealedRanges);
    final manual = mergePrivateRanges(manualRanges, text.length);
    final revealed = mergePrivateRanges(revealedRanges, text.length);
    final keptSecrets = <String>{};
    final automaticSources = <PrivateTextRange>[];
    bool revealedAt(int start, int end) =>
        privateRangeOverlaps(revealed, start, end);
    void addAutomatic(int start, int end, {bool bySecret = false}) {
      final surface = text.substring(start, end);
      if (revealedAt(start, end) ||
          (bySecret && revealedSecrets.contains(surface))) {
        keptSecrets.add(surface);
        return;
      }
      automaticSources.add(PrivateTextRange(start, end));
    }

    final matches = nameMatcher?.findSpans(text) ?? <PersonNameSpan>[];
    for (final match in matches) {
      if (match.isAmbiguous) addAutomatic(match.start, match.end);
    }
    for (final range in extraAutomaticRanges) {
      addAutomatic(range.start, range.end);
    }
    if (detectAutomatically) {
      for (final span in detectSensitiveText(text)) {
        addAutomatic(span.start, span.end, bySecret: true);
      }
    }
    final automatic = mergePrivateRanges(automaticSources, text.length);
    var remaining = automatic;
    // 不把自動命中的外圍文字併入手動選取，補記只保留使用者真正圈選的原文。
    for (final range in manual) {
      remaining = removePrivateRange(remaining, range.start, range.end);
    }
    bool sameSpan(int start, int end, int otherStart, int otherEnd) =>
        start == otherStart && end == otherEnd;
    bool exactPerson(int start, int end) =>
        people.any(
          (person) => sameSpan(start, end, person.start, person.end),
        ) ||
        matches.any(
          (match) =>
              !match.isAmbiguous &&
              sameSpan(start, end, match.start, match.end),
        ) ||
        replacements.any(
          (replacement) =>
              sameSpan(start, end, replacement.start, replacement.end) &&
              privacyTokenHasKind(
                replacement.replacement,
                PrivacyTokenKind.person,
              ),
        );
    final spans = <PrivacyReplacement>[];
    final manualTokens = <String>{};
    final automaticTokens = <String>{};
    for (final range in manual) {
      if (exactPerson(range.start, range.end)) continue;
      final token = _privateToken(
        text.substring(range.start, range.end),
        text,
        reuse: !distinctSelections,
      );
      manualTokens.add(token);
      spans.add((start: range.start, end: range.end, replacement: token));
    }
    for (final range in remaining) {
      final token = _privateToken(text.substring(range.start, range.end), text);
      automaticTokens.add(token);
      spans.add((start: range.start, end: range.end, replacement: token));
    }
    bool overlaps(int start, int end) =>
        spans.any((span) => start < span.end && end > span.start);
    for (final replacement in replacements) {
      final surface = text.substring(replacement.start, replacement.end);
      final keepsLiteralToken =
          privacyTokenPattern.stringMatch(surface) == surface;
      if (!keepsLiteralToken &&
          revealedAt(replacement.start, replacement.end)) {
        continue;
      }
      if (!overlaps(replacement.start, replacement.end)) spans.add(replacement);
    }
    final personRanges = <PersonTextRange>[];
    final surfaces = <String, List<String>>{};
    for (final person in [
      ...people,
      for (final match in matches)
        if (!match.isAmbiguous)
          PersonTextRange(match.start, match.end, match.personId),
    ]) {
      validatePrivateRanges(text, [PrivateTextRange(person.start, person.end)]);
      if (revealedAt(person.start, person.end)) continue;
      if (overlaps(person.start, person.end)) continue;
      final surface = text.substring(person.start, person.end);
      final token = personToken(person.personId, surface, text: text);
      spans.add((start: person.start, end: person.end, replacement: token));
      personRanges.add(person);
      surfaces.putIfAbsent(token, () => []).add(surface);
    }
    automaticTokens.removeAll(manualTokens);
    return ProtectedText(
      text: replacePrivacySpans(text, spans),
      manualTokens: Set.unmodifiable(manualTokens),
      automaticTokens: Set.unmodifiable(automaticTokens),
      automaticRanges: List.unmodifiable(remaining),
      personRanges: List.unmodifiable(personRanges),
      surfaces: Map.unmodifiable(surfaces),
      highlightRanges: List.unmodifiable(
        mergePrivateRanges([
          for (final span in spans)
            if (privacyTokenPattern.stringMatch(span.replacement) ==
                span.replacement)
              PrivateTextRange(span.start, span.end),
        ], text.length),
      ),
      revealedSecrets: Set.unmodifiable(keptSecrets),
    );
  }
}

String replacePrivacySpans(String text, List<PrivacyReplacement> spans) {
  final sorted = [...spans]..sort((a, b) => a.start.compareTo(b.start));
  final result = StringBuffer();
  var cursor = 0;
  for (final span in sorted) {
    validatePrivateRanges(text, [PrivateTextRange(span.start, span.end)]);
    if (span.start < cursor) throw const FormatException('保護區間重疊');
    result.write(text.substring(cursor, span.start));
    result.write(span.replacement);
    cursor = span.end;
  }
  result.write(text.substring(cursor));
  return result.toString();
}

({String text, List<PrivateTextRange> ranges, List<String> tokens})
restorePrivacyText(
  String text,
  Map<String, String> originals, {
  Map<String, List<String>> surfaces = const {},
}) {
  final queues = {
    for (final entry in surfaces.entries) entry.key: List.of(entry.value),
  };
  final output = StringBuffer();
  final ranges = <PrivateTextRange>[];
  final tokens = <String>[];
  var cursor = 0;
  for (final match in privacyTokenPattern.allMatches(text)) {
    output.write(text.substring(cursor, match.start));
    final token = match[0]!;
    final original = queues[token]?.firstOrNull ?? originals[token];
    if (original == null) {
      output.write(token);
    } else {
      if (queues[token]?.isNotEmpty == true) queues[token]!.removeAt(0);
      ranges.add(
        PrivateTextRange(output.length, output.length + original.length),
      );
      tokens.add(token);
      output.write(original);
    }
    cursor = match.end;
  }
  output.write(text.substring(cursor));
  return (text: output.toString(), ranges: ranges, tokens: tokens);
}

/// 只算畫面上要標出的區間，不保留代號對照。
List<PrivateTextRange> privacyHighlightRanges(
  String text, {
  List<PrivateTextRange> manualRanges = const [],
  List<PrivateTextRange> revealedRanges = const [],
  PersonNameMatcher? nameMatcher,
}) => PrivacyTextProcessor({})
    .protect(
      text,
      manualRanges: manualRanges,
      revealedRanges: revealedRanges,
      nameMatcher: nameMatcher,
    )
    .highlightRanges;
