import 'package:quill_diary/domain/ai/privacy_text_processor.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/person_name_matcher.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';

/// 私密代號不算可見文字；人物代號仍算可見。
bool personaHasVisibleText(String text) {
  final visible = text.replaceAllMapped(privacyTokenPattern, (match) {
    final token = PrivacyToken.parse(match[0]!);
    return token.kind == PrivacyTokenKind.private ? '' : match[0]!;
  });
  return visible.trim().isNotEmpty;
}

bool _boundedImportName(String text, int start, int end) {
  bool asciiLetterOrDigit(int unit) =>
      (unit >= 0x30 && unit <= 0x39) ||
      (unit >= 0x41 && unit <= 0x5A) ||
      (unit >= 0x61 && unit <= 0x7A);
  if (start > 0 &&
      asciiLetterOrDigit(text.codeUnitAt(start - 1)) &&
      asciiLetterOrDigit(text.codeUnitAt(start))) {
    return false;
  }
  if (end < text.length &&
      asciiLetterOrDigit(text.codeUnitAt(end - 1)) &&
      asciiLetterOrDigit(text.codeUnitAt(end))) {
    return false;
  }
  return true;
}

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
  final revealedSecrets = <String>{};
  final Map<String, String> _tokenByIdentity = {};
  late final _processor = PrivacyTextProcessor(
    {},
    personTokens: _tokenByIdentity,
    reservedText: reservedText,
  );
  final Map<String, String?> _personByToken = {};
  final Map<String, String> _identityByToken = {};
  final Set<String> _literalCodes = {};
  final Map<String, List<String>> _importNamesByScope = {};
  final Map<String, List<String>> _subjectNamesByScope = {};
  final Map<String, String> _subjectPersonIdByScope = {};

  void registerImport(PersonaChatImport chat) {
    replaceImportNames([
      for (final speaker in chat.speakers)
        if (speaker.id.startsWith('named-') &&
            !(chat.isRaw && speaker.role == PersonaSpeakerRole.personaSubject))
          speaker.label,
    ], scope: chat.importId);
    bindSubjectImportNames(chat.personId, [
      if (chat.isRaw)
        for (final speaker in chat.speakers)
          if (speaker.role == PersonaSpeakerRole.personaSubject) speaker.label,
    ], scope: chat.importId);
  }

  /// 這次匯入指定過的名字。之後 [protect] 或 [protectForDisplay] 設 `maskImportNames` 才會替換內文。
  void replaceImportNames(Iterable<String> names, {String scope = 'global'}) {
    final unique =
        names
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    _importNamesByScope[scope] = unique;
    for (final name in unique) {
      anonymous('import:${scope == 'global' ? '' : '$scope:'}$name');
    }
  }

  /// 原文匯入裡標成目標對象的名字。遮罩成這位人物的代號，而不是匿名 import 代號。
  void bindSubjectImportNames(
    String personId,
    Iterable<String> names, {
    String scope = 'global',
  }) {
    final unique =
        names
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    _subjectNamesByScope[scope] = unique;
    if (unique.isEmpty) {
      _subjectPersonIdByScope.remove(scope);
      return;
    }
    person(personId);
    _subjectPersonIdByScope[scope] = personId;
  }

  String person(String personId) => _bind('person:$personId', personId);
  String anonymous(String identity) => _bind('anonymous:$identity', null);
  String _bind(String identity, String? personId) {
    final token = _processor.personToken(identity, '', text: reservedText);
    _personByToken[token] = personId;
    _identityByToken[token] = identity;
    return token;
  }

  String protect(
    String text, {
    required String scope,
    Map<String, String?> tokens = const {},
    List<PrivateTextRange> ranges = const [],
    List<PrivateTextRange> revealedRanges = const [],
    bool maskImportNames = false,
    List<PrivateTextRange>? automaticRanges,
  }) {
    final protected = protectForDisplay(
      text,
      scope: scope,
      tokens: tokens,
      ranges: ranges,
      revealedRanges: revealedRanges,
      maskImportNames: maskImportNames,
      automaticRanges: automaticRanges,
    );
    revealedSecrets.addAll(protected.revealedSecrets);
    return protected.text;
  }

  /// 遮罩文字並回傳畫面上要標出的原文區間。外送請用 [protect]。
  ProtectedText protectForDisplay(
    String text, {
    required String scope,
    Map<String, String?> tokens = const {},
    List<PrivateTextRange> ranges = const [],
    List<PrivateTextRange> revealedRanges = const [],
    bool maskImportNames = false,
    List<PrivateTextRange>? automaticRanges,
  }) {
    validatePersonaRanges(text, ranges);
    validatePersonaRanges(text, revealedRanges);
    return _protectPiece(
      text,
      scope,
      tokens,
      ranges: ranges,
      revealedRanges: revealedRanges,
      automaticRanges: automaticRanges,
      maskImportNames: maskImportNames,
    );
  }

  String protectEvidence(
    String text, {
    List<PrivateTextRange> revealedRanges = const [],
  }) => _protectPiece(
    text,
    'evidence',
    const {},
    preserveOutbound: true,
    revealedRanges: revealedRanges,
  ).text;

  ProtectedText _protectPiece(
    String text,
    String scope,
    Map<String, String?> tokens, {
    bool preserveOutbound = false,
    bool maskImportNames = false,
    List<PrivateTextRange> ranges = const [],
    List<PrivateTextRange> revealedRanges = const [],
    List<PrivateTextRange>? automaticRanges,
  }) {
    if (!preserveOutbound) {
      _literalCodes.addAll(
        personaBareTokenPattern.allMatches(text).map((m) => m[0]!),
      );
    }
    final spans = <({int start, int end, String replacement})>[];
    final existing = privacyTokenPattern.allMatches(text).toList();
    for (final match in existing) {
      final token = match[0]!;
      final String replacement;
      if (preserveOutbound && _personByToken.containsKey(token)) {
        replacement = token;
      } else if (!tokens.containsKey(token)) {
        final body = token.substring(2, token.length - 2);
        if (!preserveOutbound) _literalCodes.add(body);
        replacement = '［$body］';
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
    if (maskImportNames) {
      final importScope =
          _importNamesByScope.containsKey(scope.split(':').first) ||
              _subjectNamesByScope.containsKey(scope.split(':').first)
          ? scope.split(':').first
          : 'global';
      final subjectId = _subjectPersonIdByScope[importScope];
      final importNames = _importNamesByScope[importScope] ?? const <String>[];
      final subjectImportNames =
          _subjectNamesByScope[importScope] ?? const <String>[];
      final names = [
        for (final name in subjectImportNames)
          if (subjectId != null) (name: name, token: person(subjectId)),
        for (final name in importNames)
          if (!subjectImportNames.contains(name))
            (
              name: name,
              token: anonymous(
                'import:${importScope == 'global' ? '' : '$importScope:'}$name',
              ),
            ),
      ]..sort((a, b) => b.name.length.compareTo(a.name.length));
      for (final named in names) {
        final name = named.name;
        final token = named.token;
        var start = 0;
        while (start < text.length) {
          final index = text.indexOf(name, start);
          if (index < 0) break;
          final end = index + name.length;
          // 較長的名字先掃。ASCII 英數緊貼兩邊不算完整名字，避免 Ann 命中 Anne。
          final overlaps = spans.any(
            (span) => index < span.end && end > span.start,
          );
          if (!overlaps && _boundedImportName(text, index, end)) {
            spans.add((start: index, end: end, replacement: token));
          }
          start = end;
        }
      }
    }
    final hiddenNames = <PrivateTextRange>[];
    if (hideNames) {
      for (final match in matcher.findSpans(text)) {
        if (spans.any((e) => match.start < e.end && match.end > e.start)) {
          continue;
        }
        if (privateRangeOverlaps(revealedRanges, match.start, match.end)) {
          if (!match.isAmbiguous &&
              !preserveOutbound &&
              !_tokenByIdentity.containsKey('person:${match.personId}')) {
            person(match.personId);
          }
          continue;
        }
        if (preserveOutbound &&
            !_tokenByIdentity.containsKey('person:${match.personId}')) {
          throw const FormatException('模型回傳未提供的人物姓名');
        }
        if (match.isAmbiguous) {
          hiddenNames.add(PrivateTextRange(match.start, match.end));
          continue;
        }
        spans.add((
          start: match.start,
          end: match.end,
          replacement: person(match.personId),
        ));
      }
    }
    return _processor.protect(
      text,
      manualRanges: ranges,
      replacements: spans,
      detectAutomatically: automaticRanges == null,
      extraAutomaticRanges: [...hiddenNames, ...?automaticRanges],
      revealedRanges: revealedRanges,
    );
  }

  void validateOutputTokens(String text, String requestData) {
    if (personaBareTokenPattern
        .allMatches(text)
        .any((m) => !_literalCodes.contains(m[0]))) {
      throw const FormatException('模型省略了人物代號的完整格式');
    }
    for (final match in privacyTokenPattern.allMatches(text)) {
      if (!_personByToken.containsKey(match[0]) ||
          !requestData.contains(match[0]!)) {
        throw const FormatException('模型回傳未知人物或私密代號');
      }
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
        }, kind: PrivacyTokenKind.person);
        bindings[stored] = personId;
        return stored;
      });
    });
    final candidate = PersonaCandidate(text: converted, tokens: bindings);
    candidate.validate(kind);
    return candidate;
  }
}
