import 'package:quill_diary/domain/ai/privacy_names.dart';
import 'package:quill_diary/domain/ai/privacy_text_processor.dart';
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
      for (final token in chat.originalTextByToken.keys)
        if (privacyTokenHasKind(token, PrivacyTokenKind.person)) token,
    };
    for (final message in messages ?? chat.activeMessages) {
      _restoreTokens.addAll(
        RegExp(_tokenPattern)
            .allMatches(
              message.isUser
                  ? message.outboundText
                  : '${message.outboundText}\n${message.systemPromptSnapshot}',
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
  List<PrivateTextRange> _requestAutomaticRanges = const [];
  final Set<String> _branchTokens = {};
  final Set<String> _diaryTokens = {};
  final Set<String> _restoreTokens = {};
  late final PrivacyLedger _ledger = PrivacyLedger(
    originals: chat.originalTextByToken,
    personTokens: {
      for (final entry in chat.tokenBySourceKey.entries)
        if (entry.key.startsWith('person:'))
          entry.key.substring('person:'.length): entry.value,
    },
  );
  late final _processor = _ledger.processor();
  Set<String> get lastRequestPrivateTokens =>
      Set.unmodifiable(_requestPrivateTokens);

  String personaPersonToken(String personId, String surface) =>
      chat.hidePersonNames ? _personToken(personId, surface) : surface;

  String personaAnonymousToken(String scope, String label) =>
      _token('persona:$scope', label, PrivacyTokenKind.person);
  List<PersonTextRange> get lastRequestPersonRanges =>
      List.unmodifiable(_requestPersonRanges);
  List<PrivateTextRange> get lastRequestAutomaticRanges =>
      List.unmodifiable(_requestAutomaticRanges);
  String get _tokenPattern => chat.originalTextByToken.isEmpty
      ? r'(?!)'
      : chat.originalTextByToken.keys.map(RegExp.escape).join('|');

  final revealedSecrets = <String>{};

  /// 只替換 [ranges] 標記的區間，不搜尋其他副本。
  String protect(
    String text, [
    List<PrivateTextRange> ranges = const [],
    bool trackForDiaryFootnotes = true,
    List<PersonTextRange>? personRanges,
    List<PrivateTextRange> automaticRanges = const [],
    List<PrivateTextRange> revealedRanges = const [],
  ]) => _apply(
    text,
    ranges,
    trackForDiaryFootnotes,
    false,
    personRanges,
    automaticRanges,
    revealedRanges,
  );

  /// 提示詞另把已經標記過的私密原文換成同一個代號。
  String protectPrompt(String text) =>
      _apply(text, const [], true, true, null, const [], const []);

  String _apply(
    String text,
    List<PrivateTextRange> ranges,
    bool trackForDiaryFootnotes,
    bool propagateKnownSecrets,
    List<PersonTextRange>? personRanges,
    List<PrivateTextRange> automaticRanges,
    List<PrivateTextRange> revealedRanges,
  ) {
    final known = propagateKnownSecrets
        ? {..._branchTokens, ..._requestPrivateTokens}
        : const <String>{};
    final propagated = <PrivateTextRange>[];
    for (final token in known) {
      final original = chat.originalTextByToken[token]!;
      if (original.isEmpty) continue;
      for (final match in RegExp(RegExp.escape(original)).allMatches(text)) {
        propagated.add(PrivateTextRange(match.start, match.end));
      }
    }
    final result = protectNamedText(
      _processor,
      text,
      manualRanges: [...ranges, ...propagated],
      nameMatcher: chat.hidePersonNames && personRanges == null
          ? _matcher
          : null,
      people: chat.hidePersonNames ? personRanges ?? const [] : const [],
      extraAutomaticRanges: automaticRanges,
      revealedRanges: revealedRanges,
    );
    revealedSecrets.addAll(result.revealedSecrets);
    _requestPersonRanges
      ..clear()
      ..addAll(result.personRanges);
    _requestAutomaticRanges = result.automaticRanges;
    if (!propagateKnownSecrets) {
      _requestPrivateTokens.addAll(result.manualTokens);
      if (trackForDiaryFootnotes) _diaryTokens.addAll(result.manualTokens);
    }
    _restoreTokens.addAll({...result.manualTokens, ...result.automaticTokens});
    _ledger.writePersonSourceKeys(chat.tokenBySourceKey);
    for (final person in result.personRanges) {
      _restoreTokens.add(_processor.personTokens[person.personId]!);
    }
    return result.text;
  }

  String _personToken(String personId, String surface) {
    final token = _processor.personToken(personId, surface, text: surface);
    chat.tokenBySourceKey['person:$personId'] = token;
    _restoreTokens.add(token);
    return token;
  }

  String _token(String sourceKey, String originalText, PrivacyTokenKind kind) {
    final existing = chat.tokenBySourceKey[sourceKey];
    if (existing != null) {
      _restoreTokens.add(existing);
      return existing;
    }
    final token = nextPrivacyToken(
      chat.originalTextByToken.keys,
      kind: kind,
      reservedText: originalText,
    );
    chat.tokenBySourceKey[sourceKey] = token;
    chat.originalTextByToken[token] = originalText;
    _restoreTokens.add(token);
    return token;
  }

  void registerRestoreTokensFromRequest(Iterable<String> tokens) {
    _restoreTokens.addAll(tokens.where(chat.originalTextByToken.containsKey));
  }

  String restore(String text) => restorePrivacyText(text, {
    for (final token in _restoreTokens) token: chat.originalTextByToken[token]!,
  }).text;

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
