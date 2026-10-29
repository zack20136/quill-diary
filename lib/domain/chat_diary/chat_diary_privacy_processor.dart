import '../people/person.dart';
import '../people/person_name_matcher.dart';
import 'chat_diary_session.dart';

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
  final Set<String> _branchTokens = {};
  final Set<String> _diaryTokens = {};
  final Set<String> _restoreTokens = {};
  Set<String> get requestPrivateTokens =>
      Set.unmodifiable(_requestPrivateTokens);
  String get _tokenPattern => chat.originalTextByToken.isEmpty
      ? r'(?!)'
      : chat.originalTextByToken.keys.map(RegExp.escape).join('|');

  /// 只替換 [ranges] 標記的區間，不搜尋其他副本。
  String protect(
    String text, [
    List<ChatDiaryPrivateRange> ranges = const [],
    bool rememberPrivate = true,
  ]) => _apply(text, ranges, rememberPrivate, false);

  /// 提示詞另把已經標記過的私密原文換成同一個代號。
  String protectPrompt(String text) => _apply(text, const [], true, true);

  String _apply(
    String text,
    List<ChatDiaryPrivateRange> ranges,
    bool rememberPrivate,
    bool propagateKnownSecrets,
  ) {
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
      result.write(
        _protectText(text.substring(cursor, range.start), scanTokens),
      );
      final originalText = text.substring(range.start, range.end);
      result.write(_token('private:$originalText', originalText, 'S'));
      cursor = range.end;
    }
    result.write(_protectText(text.substring(cursor), scanTokens));
    return result.toString();
  }

  String _protectText(String text, Set<String> activeTokens) {
    final originals = {
      for (final token in activeTokens) chat.originalTextByToken[token]!: token,
    };
    if (originals.isEmpty) return _protectPeople(text);
    final values = originals.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final pattern = RegExp(
      '$_tokenPattern|${values.map(RegExp.escape).join('|')}',
    );
    final protected = text.replaceAllMapped(
      pattern,
      (match) => originals[match[0]] ?? match[0]!,
    );
    return _protectPeople(protected);
  }

  String _protectPeople(String text) {
    if (!chat.hidePersonNames) return text;
    final tokens = RegExp(_tokenPattern).allMatches(text).toList();
    final result = StringBuffer();
    var cursor = 0;
    for (final span in _matcher.findSpans(text)) {
      if (tokens.any(
        (token) => span.start < token.end && span.end > token.start,
      )) {
        continue;
      }
      result.write(text.substring(cursor, span.start));
      result.write(
        _token(
          'person:${span.personId}',
          text.substring(span.start, span.end),
          'P',
        ),
      );
      cursor = span.end;
    }
    result.write(text.substring(cursor));
    return result.toString();
  }

  String _token(String sourceKey, String originalText, String prefix) {
    final existing = chat.tokenBySourceKey[sourceKey];
    if (existing != null) {
      _restoreTokens.add(existing);
      return existing;
    }
    var nextNumber = 1;
    for (final token in chat.originalTextByToken.keys) {
      final match = RegExp(r'^⟦[PS]([0-9A-F]{2,})⟧$').firstMatch(token);
      if (match == null) continue;
      final number = int.parse(match[1]!, radix: 16);
      if (number >= nextNumber) nextNumber = number + 1;
    }
    final number = nextNumber.toRadixString(16).toUpperCase().padLeft(2, '0');
    final token = '⟦$prefix$number⟧';
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

List<ChatDiaryPrivateRange> mergePrivateRanges(
  List<ChatDiaryPrivateRange> ranges,
  int length,
) {
  final sorted =
      ranges
          .map(
            (range) => ChatDiaryPrivateRange(
              range.start.clamp(0, length),
              range.end.clamp(0, length),
            ),
          )
          .where((range) => range.start < range.end)
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  final result = <ChatDiaryPrivateRange>[];
  for (final range in sorted) {
    if (result.isNotEmpty && range.start <= result.last.end) {
      final last = result.removeLast();
      result.add(
        ChatDiaryPrivateRange(
          last.start,
          range.end > last.end ? range.end : last.end,
        ),
      );
    } else {
      result.add(range);
    }
  }
  return result;
}

List<ChatDiaryPrivateRange> removePrivateRange(
  List<ChatDiaryPrivateRange> ranges,
  int start,
  int end,
) => [
  for (final range in ranges)
    if (end <= range.start || start >= range.end)
      range
    else ...[
      if (range.start < start) ChatDiaryPrivateRange(range.start, start),
      if (range.end > end) ChatDiaryPrivateRange(end, range.end),
    ],
];

/// 編輯碰到私密範圍時，替換的新文字也保持隱藏；不因組字或貼上洩漏。
List<ChatDiaryPrivateRange> updatePrivateRanges(
  String oldText,
  String newText,
  List<ChatDiaryPrivateRange> ranges,
) {
  if (oldText == newText) return ranges;
  var start = 0;
  while (start < oldText.length &&
      start < newText.length &&
      oldText.codeUnitAt(start) == newText.codeUnitAt(start)) {
    start++;
  }
  var oldEnd = oldText.length;
  var newEnd = newText.length;
  while (oldEnd > start &&
      newEnd > start &&
      oldText.codeUnitAt(oldEnd - 1) == newText.codeUnitAt(newEnd - 1)) {
    oldEnd--;
    newEnd--;
  }
  final delta = newText.length - oldText.length;
  return mergePrivateRanges([
    for (final range in ranges)
      if (oldEnd < range.start)
        ChatDiaryPrivateRange(range.start + delta, range.end + delta)
      else if (start > range.end)
        range
      else
        ChatDiaryPrivateRange(
          range.start < start ? range.start : start,
          range.end + delta > newEnd ? range.end + delta : newEnd,
        ),
  ], newText.length);
}
