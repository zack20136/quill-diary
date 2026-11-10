import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/person_name_matcher.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';

const personaHiddenText = '⟦已隱藏⟧';

bool personaHasVisibleText(String text) =>
    text.replaceAll(personaHiddenText, '').trim().isNotEmpty;

/// 一次生成共用外送對照；已登錄人物共用代號，匿名人物則依來源區分。
class PersonaTokenRegistry {
  PersonaTokenRegistry(
    Iterable<Person> people, {
    required this.hideNames,
    this.reservedText = '',
  }) : people = {for (final p in people) p.id: p},
       matcher = PersonNameMatcher(people);
  final Map<String, Person> people;
  final PersonNameMatcher matcher;
  final bool hideNames;
  final String reservedText;
  final Map<String, String> _tokenByIdentity = {};
  final Map<String, String?> _personByToken = {};
  final Map<String, String> _identityByToken = {};
  final Set<String> _literalCodes = {};

  String person(String personId) => _bind('person:$personId', personId);
  String anonymous(String identity) => _bind('anonymous:$identity', null);
  String _bind(String identity, String? personId) =>
      _tokenByIdentity.putIfAbsent(identity, () {
        final token = nextPrivacyToken(
          _personByToken.keys,
          prefix: 'P',
          reservedText: reservedText,
        );
        _personByToken[token] = personId;
        _identityByToken[token] = identity;
        return token;
      });

  String protect(
    String text, {
    required String scope,
    Map<String, String?> tokens = const {},
    List<PrivateTextRange> ranges = const [],
  }) {
    validatePersonaRanges(text, ranges);
    final merged = mergePrivateRanges(ranges, text.length);
    final result = StringBuffer();
    var cursor = 0;
    for (final range in merged) {
      result.write(
        _protectPiece(text.substring(cursor, range.start), scope, tokens),
      );
      result.write(personaHiddenText);
      cursor = range.end;
    }
    result.write(_protectPiece(text.substring(cursor), scope, tokens));
    return result.toString();
  }

  String protectEvidence(String text) =>
      _protectPiece(text, 'evidence', const {}, preserveOutbound: true);

  String _protectPiece(
    String text,
    String scope,
    Map<String, String?> tokens, {
    bool preserveOutbound = false,
  }) {
    if (!preserveOutbound) {
      _literalCodes.addAll(
        personaBareTokenPattern.allMatches(text).map((m) => m[0]!),
      );
    }
    final spans = <({int start, int end, String replacement})>[];
    final existing = personaTokenPattern.allMatches(text).toList();
    for (final match in existing) {
      final token = match[0]!;
      final String replacement;
      if (preserveOutbound && _personByToken.containsKey(token)) {
        replacement = token;
      } else if (!tokens.containsKey(token)) {
        if (!preserveOutbound) {
          _literalCodes.add(token.substring(1, token.length - 1));
        }
        replacement = '［${token.substring(1, token.length - 1)}］';
      } else {
        final id = tokens[token];
        replacement = id == null
            ? anonymous('$scope:$token')
            : !hideNames && people[id] != null
            ? people[id]!.name
            : person(id);
      }
      spans.add((start: match.start, end: match.end, replacement: replacement));
    }
    if (hideNames) {
      for (final match in matcher.findSpans(text)) {
        if (existing.any((e) => match.start < e.end && match.end > e.start)) {
          continue;
        }
        if (preserveOutbound &&
            !_tokenByIdentity.containsKey('person:${match.personId}')) {
          throw const FormatException('模型回傳未提供的人物姓名');
        }
        spans.add((
          start: match.start,
          end: match.end,
          replacement: person(match.personId),
        ));
      }
    }
    spans.sort((a, b) => a.start.compareTo(b.start));
    final out = StringBuffer();
    var cursor = 0;
    for (final span in spans) {
      if (span.start < cursor) continue;
      out.write(text.substring(cursor, span.start));
      out.write(span.replacement);
      cursor = span.end;
    }
    out.write(text.substring(cursor));
    return out.toString();
  }

  void validateOutputTokens(String text, String requestData) {
    if (personaBareTokenPattern
        .allMatches(text)
        .any((m) => !_literalCodes.contains(m[0]))) {
      throw const FormatException('模型省略了人物代號的完整格式');
    }
    for (final match in personaTokenPattern.allMatches(text)) {
      if (!_personByToken.containsKey(match[0]) ||
          !requestData.contains(match[0]!)) {
        throw const FormatException('模型回傳未知人物或私密代號');
      }
    }
    if (text.contains(personaHiddenText)) {
      throw const FormatException('候選仍包含隱藏佔位符');
    }
  }

  PersonaCandidate candidate(
    String text,
    PersonaCardKind kind,
    PersonaCard? current, {
    String? requestData,
  }) {
    validateOutputTokens(text, requestData ?? text);
    text = protectEvidence(text);
    if (requestData != null) validateOutputTokens(text, requestData);
    final bindings = <String, String?>{};
    final assigned = <String, String>{};
    final reserved = {...?current?.tokens.keys};
    final converted = text.replaceAllMapped(privacyTokenPattern, (match) {
      final outbound = match[0]!;
      if (!_personByToken.containsKey(outbound)) {
        throw const FormatException('未知人物代號');
      }
      return assigned.putIfAbsent(outbound, () {
        final personId = _personByToken[outbound];
        String? stored;
        for (final entry
            in current?.tokens.entries ?? <MapEntry<String, String?>>[]) {
          if (personId != null && entry.value == personId ||
              personId == null &&
                  _identityByToken[outbound] ==
                      'anonymous:card:${kind.name}:${entry.key}') {
            stored = entry.key;
            break;
          }
        }
        stored ??= nextPrivacyToken({
          ...reserved,
          ...bindings.keys,
        }, prefix: 'P');
        bindings[stored] = personId;
        return stored;
      });
    });
    final candidate = PersonaCandidate(text: converted, tokens: bindings);
    candidate.validate(kind);
    return candidate;
  }
}
