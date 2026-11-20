import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/ai/privacy_text_processor.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/ai/sensitive_text.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';

class AiInputImage {
  const AiInputImage({
    required this.id,
    required this.mimeType,
    required this.bytes,
  });
  final String id;
  final String mimeType;
  final Uint8List bytes;
}

class AiInputMessage {
  const AiInputMessage({
    required this.isUser,
    required this.text,
    this.images = const [],
  });
  final bool isUser;
  final String text;
  final List<AiInputImage> images;
}

/// 背景只辨識原文區間；套用對照與保存仍由原工作階段負責。
Future<PreparedAiRequest> prepareAiRequest({
  required AiConnectionConfig connection,
  required String instructions,
  required List<AiInputMessage> messages,
  required Map<String, String> originals,
  String? diaryBody,
  Set<String> optionalPrivateTokens = const {},
  Set<String> revealedSecrets = const {},
  bool background = false,
}) async {
  final texts = _requestTexts(connection, instructions, diaryBody, messages);
  final detections = background
      ? await Isolate.run(() => _detectTexts(texts))
      : _detectTexts(texts);
  return PreparedAiRequest._build(
    connection: connection,
    instructions: instructions,
    messages: messages,
    originals: originals,
    diaryBody: diaryBody,
    optionalPrivateTokens: optionalPrivateTokens,
    revealedSecrets: revealedSecrets,
    detections: detections,
  );
}

class PreparedAiRequest {
  PreparedAiRequest._({
    required this.connection,
    required this.instructions,
    required this.diaryBody,
    required this.messages,
    required this.requestFields,
    required this.internalInstructions,
    required this.internalDiary,
    required this.internalMessages,
    required this.knownTokens,
    required this.automaticTokenIds,
    required this._literalByStored,
    required this._reservedTokens,
  });

  static PreparedAiRequest _build({
    required AiConnectionConfig connection,
    required String instructions,
    required List<AiInputMessage> messages,
    required Map<String, String> originals,
    String? diaryBody,
    required Set<String> optionalPrivateTokens,
    Set<String> revealedSecrets = const {},
    required Map<String, List<PrivateTextRange>> detections,
  }) {
    final processor = PrivacyTextProcessor(originals);
    final mandatory = {
      for (final text in [
        instructions,
        diaryBody ?? '',
        for (final message in messages) message.text,
      ])
        ...privacyTokenPattern.allMatches(text).map((match) => match[0]!),
    }.difference(optionalPrivateTokens);
    final automatic = <String>{...optionalPrivateTokens};
    List<PrivateTextRange> detected(String text) => [
      for (final span in detections[text] ?? const <PrivateTextRange>[])
        if (!revealedSecrets.contains(text.substring(span.start, span.end)))
          span,
    ];
    String protect(String text, {String? field}) {
      final result = processor.protect(
        text,
        detectAutomatically: false,
        extraAutomaticRanges: [
          ...detected(text),
          if (text.isNotEmpty && isCredentialField(field))
            PrivateTextRange(0, text.length),
        ],
      );
      automatic.addAll(result.automaticTokens);
      return result.text;
    }

    final protectedInstructions = protect(instructions);
    final internalDiary = diaryBody == null ? null : protect(diaryBody);
    final internalMessages = List<AiInputMessage>.unmodifiable([
      for (final message in messages)
        AiInputMessage(
          isUser: message.isUser,
          text: protect(message.text),
          images: List.unmodifiable(message.images),
        ),
    ]);
    final fields = _mapStrings(
      thinkingRequestFields(connection),
      (text, field) => protect(text, field: field),
    );
    final automaticTokenIds = Set<String>.unmodifiable(
      automatic.difference(mandatory),
    );
    final literalByStored = <String, String>{};
    final literalByText = <String, String>{};
    final provided = <String>{};
    String encode(String text) {
      text = text.replaceAllMapped(_literalWirePattern, (match) {
        final original = match[0]!;
        if (originals.containsKey(original)) return original;
        final token = literalByText.putIfAbsent(
          original,
          () => nextPrivacyToken({
            ...originals.keys,
            ...literalByStored.keys,
          }, reservedText: text),
        );
        literalByStored[token] = original;
        return token;
      });
      for (final match in privacyTokenPattern.allMatches(text)) {
        final token = match[0]!;
        if (originals.containsKey(token)) provided.add(token);
      }
      return text;
    }

    final encodedInstructions = encode(protectedInstructions);
    final encodedDiary = internalDiary == null ? null : encode(internalDiary);
    final encodedMessages = List<AiInputMessage>.unmodifiable([
      for (final message in internalMessages)
        AiInputMessage(
          isUser: message.isUser,
          text: encode(message.text),
          images: message.images,
        ),
    ]);
    final requestFields =
        _mapStrings(fields, (text, _) => encode(text)) as Map<String, Object?>;
    final knownTokens = Set<String>.unmodifiable(provided);
    return PreparedAiRequest._(
      connection: connection,
      instructions: encodedInstructions,
      diaryBody: encodedDiary,
      messages: encodedMessages,
      requestFields: requestFields,
      internalInstructions: protectedInstructions,
      internalDiary: internalDiary,
      internalMessages: internalMessages,
      knownTokens: knownTokens,
      automaticTokenIds: automaticTokenIds,
      literalByStored: literalByStored,
      reservedTokens: Set.unmodifiable({
        ...originals.keys,
        ...literalByStored.keys,
      }),
    );
  }

  static final _literalWirePattern = RegExp(r'\{\{[^{}\n]+_[0-9]+\}\}');
  final AiConnectionConfig connection;
  final Map<String, String> _literalByStored;
  final Set<String> _reservedTokens;
  final Set<String> knownTokens;
  final Set<String> automaticTokenIds;
  final String internalInstructions;
  final String? internalDiary;
  final List<AiInputMessage> internalMessages;
  final String instructions;
  final String? diaryBody;
  final List<AiInputMessage> messages;
  final Map<String, Object?> requestFields;
  String get internalSystemPrompt =>
      aiSystemPrompt(internalInstructions, internalDiary);
  String get systemPrompt => aiSystemPrompt(instructions, diaryBody);

  void verify(AiConnectionConfig destination) {
    if (jsonEncode(connection.toSnapshotJson()) !=
        jsonEncode(destination.toSnapshotJson())) {
      throw const AiFailure(AiErrorCode.privacy);
    }
  }

  /// 已知代號原樣還原；字面 `{{…_數字}}` 還原成原文。未知代號改配未使用槽位。
  Stream<String> decode(Stream<String> source) async* {
    final unknown = <String, String>{};
    String unknownToken(String value, PrivacyTokenKind kind) =>
        unknown.putIfAbsent(
          value,
          () => nextPrivacyToken({
            ..._reservedTokens,
            ...unknown.values,
          }, kind: kind),
        );
    String resolve(String token) {
      if (_literalByStored.containsKey(token)) return _literalByStored[token]!;
      if (knownTokens.contains(token)) return token;
      return unknownToken(token, PrivacyToken.parse(token).kind);
    }

    var pending = '';
    await for (final delta in source) {
      pending += delta;
      final ready = _takeReadyPrivacyTokens(pending, resolve);
      pending = ready.pending;
      if (ready.text.isNotEmpty) yield ready.text;
    }
    if (pending.isNotEmpty) yield pending;
  }
}

/// 完整代號回傳長度；仍可能是前綴時回傳 null；確定不是時回傳 0。
int? _leadingPrivacyTokenLength(String text) {
  if (text.isEmpty || text[0] != '{') return text.isEmpty ? null : 0;
  if (text.length == 1) return null;
  if (text[1] != '{') return 0;
  const labels = ['PER', 'PRI'];
  final rest = text.substring(2);
  final label = labels.where(rest.startsWith).firstOrNull;
  if (label == null) {
    return labels.any((candidate) => candidate.startsWith(rest)) ? null : 0;
  }
  var index = 2 + label.length;
  if (text.length == index) return null;
  if (text[index] != '_') return 0;
  index++;
  final hexStart = index;
  while (index < text.length) {
    final unit = text.codeUnitAt(index);
    final hex =
        (unit >= 0x30 && unit <= 0x39) || (unit >= 0x41 && unit <= 0x46);
    if (!hex) break;
    index++;
  }
  if (index == text.length) return null;
  if (index - hexStart < 2 || text[index] != '}') return 0;
  if (index + 1 == text.length) return null;
  if (text[index + 1] != '}') return 0;
  return index + 2;
}

({String text, String pending}) _takeReadyPrivacyTokens(
  String pending,
  String Function(String token) resolve,
) {
  final output = StringBuffer();
  while (pending.isNotEmpty) {
    final start = pending.indexOf('{{');
    if (start < 0) {
      if (pending.endsWith('{')) {
        output.write(pending.substring(0, pending.length - 1));
        pending = '{';
      } else {
        output.write(pending);
        pending = '';
      }
      break;
    }
    if (start > 0) {
      output.write(pending.substring(0, start));
      pending = pending.substring(start);
    }
    final length = _leadingPrivacyTokenLength(pending);
    if (length == null) break;
    if (length == 0) {
      output.write(pending[0]);
      pending = pending.substring(1);
      continue;
    }
    output.write(resolve(pending.substring(0, length)));
    pending = pending.substring(length);
  }
  return (text: output.toString(), pending: pending);
}

const aiConnectionTestPrompt = 'Reply with OK.';

String aiDiaryDataBlock(String original) =>
    '<diary_data>\n${jsonEncode({'original': original})}\n</diary_data>';

String aiSystemPrompt(String instructions, String? diary) => diary == null
    ? instructions
    : '$instructions\n\n${aiDiaryDataBlock(diary)}';

Object? _mapStrings(
  Object? value,
  String Function(String, String?) transform, {
  String? field,
}) => switch (value) {
  String() => transform(value, field),
  Map() => Map<String, Object?>.unmodifiable({
    for (final entry in value.entries)
      entry.key as String: _mapStrings(
        entry.value,
        transform,
        field: entry.key as String,
      ),
  }),
  List() => List<Object?>.unmodifiable([
    for (final item in value) _mapStrings(item, transform, field: field),
  ]),
  _ => value,
};

List<String> _requestTexts(
  AiConnectionConfig connection,
  String instructions,
  String? diaryBody,
  List<AiInputMessage> messages,
) {
  final texts = [
    instructions,
    ?diaryBody,
    for (final message in messages) message.text,
  ];
  _mapStrings(thinkingRequestFields(connection), (text, _) {
    texts.add(text);
    return text;
  });
  return texts;
}

Map<String, List<PrivateTextRange>> _detectTexts(List<String> texts) => {
  for (final text in texts) text: detectSensitiveText(text),
};
