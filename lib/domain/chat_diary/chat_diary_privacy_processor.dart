import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/person_name_matcher.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';

class ChatDiaryPrivacyProcessor {
  ChatDiaryPrivacyProcessor(
    this.chat,
    Iterable<Person> people, {
    Iterable<ChatDiaryMessage>? messages,
  }) : _matcher = PersonNameMatcher(people) {
    final personTokens = {
      for (final entry in chat.tokenBySourceKey.entries)
        if (entry.key.startsWith('person:')) entry.value,
    };
    for (final message in messages ?? chat.activeMessages) {
      _restoreTokens.addAll(
        RegExp(_tokenPattern)
            .allMatches(
              message.isUser
                  ? message.outboundText
                  : message.systemPromptSnapshot,
            )
            .map((m) => m[0]!)
            .where((token) => personTokens.contains(token)),
      );
      if (!message.isUser) {
        continue;
      }
      _branchTokens.addAll(
        message.privateTokenIds.where(chat.originalTextByToken.containsKey),
      );
    }
    _diaryTokens.addAll(_branchTokens);
    _restoreTokens.addAll(_branchTokens);
  }
  final ChatDiarySession chat;
  final PersonNameMatcher _matcher;
  final Set<String> _requestPrivateTokens = {};
  final List<PersonTextRange> _requestPersonRanges = [];
  final Set<String> _branchTokens = {};
  final Set<String> _diaryTokens = {};
  final Set<String> _restoreTokens = {};
  var _personOrigin = 0;
  Set<String> get requestPrivateTokens =>
      Set.unmodifiable(_requestPrivateTokens);
  List<PersonTextRange> get requestPersonRanges =>
      List.unmodifiable(_requestPersonRanges);
  String get _tokenPattern => chat.originalTextByToken.isEmpty
      ? r'(?!)'
      : chat.originalTextByToken.keys.map(RegExp.escape).join('|');

  /// 只替換 [ranges] 標記的區間，不搜尋其他副本。
  String protect(
    String text, [
    List<PrivateTextRange> ranges = const [],
    bool rememberPrivate = true,
    List<PersonTextRange>? personRanges,
  ]) => _apply(text, ranges, rememberPrivate, false, personRanges);

  /// 提示詞另把已經標記過的私密原文換成同一個代號。
  String protectPrompt(String text) => _apply(text, const [], true, true, null);

  String _apply(
    String text,
    List<PrivateTextRange> ranges,
    bool rememberPrivate,
    bool propagateKnownSecrets,
    List<PersonTextRange>? personRanges,
  ) {
    _requestPersonRanges.clear();
    final merged = mergePrivateRanges(ranges, text.length);
    for (final range in merged) {
      final originalText = text.substring(range.start, range.end);
      final token = _token('private:$originalText', originalText, 'S');
      _requestPrivateTokens.add(token);
      if (rememberPrivate) {
        _diaryTokens.add(token);
      }
    }
    final scanTokens = propagateKnownSecrets
        ? {..._branchTokens, ..._requestPrivateTokens}
        : const <String>{};
    final result = StringBuffer();
    var cursor = 0;
    for (final range in merged) {
      _personOrigin = cursor;
      result.write(
        _protectText(
          text.substring(cursor, range.start),
          scanTokens,
          _peopleInside(personRanges, cursor, range.start),
        ),
      );
      final originalText = text.substring(range.start, range.end);
      result.write(_token('private:$originalText', originalText, 'S'));
      cursor = range.end;
    }
    _personOrigin = cursor;
    result.write(
      _protectText(
        text.substring(cursor),
        scanTokens,
        _peopleInside(personRanges, cursor, text.length),
      ),
    );
    return result.toString();
  }

  List<PersonTextRange>? _peopleInside(
    List<PersonTextRange>? ranges,
    int start,
    int end,
  ) {
    if (ranges == null) return null;
    return [
      for (final range in ranges)
        if (range.start >= start && range.end <= end)
          PersonTextRange(
            range.start - start,
            range.end - start,
            range.personId,
          ),
    ];
  }

  String _protectText(
    String text,
    Set<String> activeTokens,
    List<PersonTextRange>? personRanges,
  ) {
    final originals = {
      for (final token in activeTokens) chat.originalTextByToken[token]!: token,
    };
    if (originals.isEmpty) return _protectPeople(text, personRanges);
    final values = originals.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final pattern = RegExp(
      '$_tokenPattern|${values.map(RegExp.escape).join('|')}',
    );
    final protected = text.replaceAllMapped(
      pattern,
      (match) => originals[match[0]] ?? match[0]!,
    );
    return _protectPeople(protected, personRanges);
  }

  String _protectPeople(String text, List<PersonTextRange>? fixed) {
    if (!chat.hidePersonNames) return text;
    final spans =
        fixed ??
        [
          for (final span in _matcher.findSpans(text))
            PersonTextRange(span.start, span.end, span.personId),
        ];
    final tokens = RegExp(_tokenPattern).allMatches(text).toList();
    final result = StringBuffer();
    var cursor = 0;
    for (final span in spans) {
      if (span.start < cursor ||
          span.end > text.length ||
          span.end <= span.start ||
          tokens.any(
            (token) => span.start < token.end && span.end > token.start,
          )) {
        continue;
      }
      result.write(text.substring(cursor, span.start));
      result.write(
        _personToken(span.personId, text.substring(span.start, span.end)),
      );
      _requestPersonRanges.add(
        PersonTextRange(
          _personOrigin + span.start,
          _personOrigin + span.end,
          span.personId,
        ),
      );
      cursor = span.end;
    }
    result.write(text.substring(cursor));
    return result.toString();
  }

  String _personToken(String personId, String surface) {
    final people = {
      for (final entry in chat.tokenBySourceKey.entries)
        if (entry.key.startsWith('person:'))
          entry.key.substring('person:'.length): entry.value,
    };
    final token = privacyTokenForPerson(
      personId: personId,
      surface: surface,
      tokenByPersonId: people,
      originals: chat.originalTextByToken,
    );
    chat.tokenBySourceKey['person:$personId'] = token;
    _restoreTokens.add(token);
    return token;
  }

  String _token(String sourceKey, String originalText, String prefix) {
    final existing = chat.tokenBySourceKey[sourceKey];
    if (existing != null) {
      _restoreTokens.add(existing);
      return existing;
    }
    final token = nextPrivacyToken(
      chat.originalTextByToken.keys,
      prefix: prefix,
    );
    chat.tokenBySourceKey[sourceKey] = token;
    chat.originalTextByToken[token] = originalText;
    _restoreTokens.add(token);
    return token;
  }

  String restore(String text) {
    if (_restoreTokens.isEmpty) return text;
    final pattern = RegExp(_restoreTokens.map(RegExp.escape).join('|'));
    return text.replaceAllMapped(
      pattern,
      (match) => chat.originalTextByToken[match[0]]!,
    );
  }

  ChatDiaryDraft restoreDiary(String text, String privateNotesHeading) {
    final missing = _diaryTokens
        .where((token) => !text.contains(token))
        .map((token) => chat.originalTextByToken[token]!)
        .toList();
    final restored = restore(text);
    return ChatDiaryDraft.fromMarkdown(
      missing.isEmpty
          ? restored
          : '$restored\n\n## $privateNotesHeading\n\n${missing.join('\n\n')}',
    );
  }
}
