import 'dart:convert';

import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_chat_patterns.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/shared/data_versions.dart';

enum PersonaSpeakerRole {
  user,
  personaSubject,
  other,
  unknown;

  /// 請求中的角色值使用提示詞約定的 snake_case，儲存則沿用 enum 名稱。
  String get requestValue => switch (this) {
    PersonaSpeakerRole.personaSubject => 'persona_subject',
    _ => name,
  };
}

class PersonaImportSpeaker {
  PersonaImportSpeaker({
    required this.id,
    required this.label,
    this.role = PersonaSpeakerRole.unknown,
  });
  final String id;
  final String label;
  PersonaSpeakerRole role;
  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'role': role.name,
  };
  factory PersonaImportSpeaker.fromJson(Map<String, dynamic> json) =>
      PersonaImportSpeaker(
        id: json['id'] as String,
        label: json['label'] as String,
        role: PersonaSpeakerRole.values.byName(json['role'] as String),
      );
}

class PersonaImportMessage {
  const PersonaImportMessage({
    required this.id,
    required this.speakerId,
    required this.text,
    required this.sentAtLocal,
    this.system = false,
    this.quoteRanges = const [],
  });
  final String id;
  final String? speakerId;
  final String text;
  final String sentAtLocal;
  final bool system;
  final List<PrivateTextRange> quoteRanges;
  Map<String, Object?> toJson() => {
    'id': id,
    'speaker_id': speakerId,
    'text': text,
    'sent_at_local': sentAtLocal,
    'system': system,
    'quote_ranges': quoteRanges.map((r) => r.toJson()).toList(),
  };
  factory PersonaImportMessage.fromJson(Map<String, dynamic> json) =>
      PersonaImportMessage(
        id: json['id'] as String,
        speakerId: json['speaker_id'] as String?,
        text: json['text'] as String,
        sentAtLocal: json['sent_at_local'] as String,
        system: json['system'] as bool,
        quoteRanges: (json['quote_ranges'] as List)
            .map(
              (r) => PrivateTextRange.fromJson(
                Map<String, dynamic>.from(r as Map),
              ),
            )
            .toList(),
      );
}

enum PersonaChatImportKind { messages, raw }

class PersonaChatImport {
  PersonaChatImport({
    required this.vaultId,
    required this.personId,
    required this.personaId,
    required this.importId,
    required this.importedAt,
    required this.speakers,
    required this.messages,
    this.kind = PersonaChatImportKind.messages,
    this.rawText = '',
    List<PrivateTextRange>? rawHidden,
  }) : rawHidden = List.of(rawHidden ?? []);

  /// 無法辨識的檔案整份保留。不升版：缺 `kind` 的舊檔仍是逐則訊息。
  PersonaChatImport.raw({
    required String vaultId,
    required String personId,
    required String personaId,
    String? importId,
    DateTime? importedAt,
    required String text,
    required List<PersonaImportSpeaker> speakers,
    required List<PrivateTextRange> hidden,
  }) : this(
         vaultId: vaultId,
         personId: personId,
         personaId: personaId,
         importId: importId ?? generatePersonaImportId(),
         importedAt: importedAt ?? DateTime.now(),
         speakers: speakers,
         messages: const [],
         kind: PersonaChatImportKind.raw,
         rawText: text,
         rawHidden: hidden,
       );

  final String vaultId;
  final String personId;
  final String personaId;
  final String importId;
  final DateTime importedAt;
  final List<PersonaImportSpeaker> speakers;
  final List<PersonaImportMessage> messages;
  final PersonaChatImportKind kind;
  final String rawText;
  final List<PrivateTextRange> rawHidden;

  bool get isRaw => kind == PersonaChatImportKind.raw;

  Iterable<PersonaImportMessage> messagesInWindow(PersonaChatSource source) {
    if (isRaw) return const Iterable.empty();
    final roles = {for (final speaker in speakers) speaker.id: speaker.role};
    return messages.where(
      (message) =>
          !message.system &&
          roles.containsKey(message.speakerId) &&
          roles[message.speakerId] != PersonaSpeakerRole.unknown &&
          (source.fromDate == null ||
              message.sentAtLocal
                      .substring(0, 10)
                      .compareTo(source.fromDate!) >=
                  0) &&
          (source.toDate == null ||
              message.sentAtLocal.substring(0, 10).compareTo(source.toDate!) <=
                  0),
    );
  }

  void validate() {
    if (!isPrefixedId(personId, 'per') ||
        !isPrefixedId(personaId, 'prs') ||
        !isPrefixedId(importId, 'pim') ||
        speakers.map((s) => s.id).toSet().length != speakers.length ||
        messages.map((m) => m.id).toSet().length != messages.length) {
      throw const FormatException('匯入聊天識別不正確');
    }
    final speakerIds = speakers.map((s) => s.id).toSet();
    if (isRaw) {
      if (messages.isNotEmpty || rawText.trim().isEmpty) {
        throw const FormatException('原文匯入不正確');
      }
      validatePersonaRanges(rawText, rawHidden);
      return;
    }
    for (final message in messages) {
      if (!message.system && !speakerIds.contains(message.speakerId) ||
          DateTime.tryParse(message.sentAtLocal) == null) {
        throw const FormatException('匯入聊天訊息不正確');
      }
      validatePersonaRanges(message.text, message.quoteRanges);
    }
  }

  Map<String, Object?> toJson() => {
    'schema_version': DataVersions.personaImport,
    'vault_id': vaultId,
    'person_id': personId,
    'persona_id': personaId,
    'import_id': importId,
    'imported_at': importedAt.toUtc().toIso8601String(),
    'speakers': speakers.map((s) => s.toJson()).toList(),
    'messages': messages.map((m) => m.toJson()).toList(),
    if (isRaw) ...{
      'kind': kind.name,
      'text': rawText,
      'hidden_ranges': rawHidden.map((r) => r.toJson()).toList(),
    },
  };
  factory PersonaChatImport.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] is! int ||
        json['schema_version'] != DataVersions.personaImport) {
      throw const FormatException('不支援的聊天匯入格式');
    }
    final kind = switch (json['kind']) {
      null || 'messages' => PersonaChatImportKind.messages,
      'raw' => PersonaChatImportKind.raw,
      _ => throw const FormatException('不支援的聊天匯入格式'),
    };
    final raw = kind == PersonaChatImportKind.raw;
    final result = PersonaChatImport(
      vaultId: json['vault_id'] as String,
      personId: json['person_id'] as String,
      personaId: json['persona_id'] as String,
      importId: json['import_id'] as String,
      importedAt: DateTime.parse(json['imported_at'] as String),
      speakers: (json['speakers'] as List)
          .map(
            (v) => PersonaImportSpeaker.fromJson(
              Map<String, dynamic>.from(v as Map),
            ),
          )
          .toList(),
      messages: raw
          ? const []
          : (json['messages'] as List)
                .map(
                  (v) => PersonaImportMessage.fromJson(
                    Map<String, dynamic>.from(v as Map),
                  ),
                )
                .toList(),
      kind: kind,
      rawText: raw ? json['text'] as String : '',
      rawHidden: raw
          ? (json['hidden_ranges'] as List)
                .map(
                  (r) => PrivateTextRange.fromJson(
                    Map<String, dynamic>.from(r as Map),
                  ),
                )
                .toList()
          : const [],
    );
    result.validate();
    return result;
  }
}

/// 依內容辨識 LINE 文字、Messenger／Instagram JSON 或 Messenger 加密備份。
PersonaChatImport parsePersonaChat(
  String input, {
  required String vaultId,
  required String personId,
  required String personaId,
}) => parsePersonaChatReport(
  input,
  vaultId: vaultId,
  personId: personId,
  personaId: personaId,
).chat;

/// 與 [parsePersonaChat] 相同，並回傳 LINE 文字裡略過的行數。JSON 的略過行數為 0。
({PersonaChatImport chat, int skippedLines}) parsePersonaChatReport(
  String input, {
  required String vaultId,
  required String personId,
  required String personaId,
}) {
  final trimmed = input.replaceFirst('\uFEFF', '').trimLeft();
  if (trimmed.startsWith('{')) {
    return (
      chat: _parseChatJson(
        trimmed,
        vaultId: vaultId,
        personId: personId,
        personaId: personaId,
      ),
      skippedLines: 0,
    );
  }
  return _parseLineTextChat(
    input,
    vaultId: vaultId,
    personId: personId,
    personaId: personaId,
  );
}

/// 內建格式可解析時回傳結果；完全無法辨識時回傳 null，交給規則對話框。
({PersonaChatImport chat, int skippedLines})? tryBuiltinPersonaChat(
  String input, {
  required String vaultId,
  required String personId,
  required String personaId,
}) {
  try {
    return parsePersonaChatReport(
      input,
      vaultId: vaultId,
      personId: personId,
      personaId: personaId,
    );
  } on FormatException {
    return null;
  }
}

/// 把每份已解析的匯出合成一份。單份保留原匯入識別，多份才重新合併。
({PersonaChatImport chat, int skippedLines}) combinePersonaChatReports(
  List<({PersonaChatImport chat, int skippedLines})> reports, {
  required String vaultId,
  required String personId,
  required String personaId,
}) {
  if (reports.isEmpty) {
    throw const FormatException('無法辨識聊天匯出格式');
  }
  final skippedLines = reports.fold<int>(
    0,
    (sum, report) => sum + report.skippedLines,
  );
  if (reports.length == 1) {
    return (chat: reports.single.chat, skippedLines: skippedLines);
  }
  return (
    chat: _mergeImports(
      [for (final report in reports) report.chat],
      vaultId: vaultId,
      personId: personId,
      personaId: personaId,
    ),
    skippedLines: skippedLines,
  );
}

PersonaChatImport _parseChatJson(
  String input, {
  required String vaultId,
  required String personId,
  required String personaId,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(input);
  } on FormatException {
    throw const FormatException('無法辨識聊天匯出格式');
  }
  if (decoded is! Map) {
    throw const FormatException('無法辨識聊天匯出格式');
  }
  final json = Map<String, dynamic>.from(decoded);
  final messages = json['messages'];
  if (messages is! List || messages.isEmpty) {
    throw const FormatException('無法辨識聊天匯出格式');
  }
  final first = messages.whereType<Map>().firstOrNull;
  if (first == null) {
    throw const FormatException('無法辨識聊天匯出格式');
  }
  if (first.containsKey('sender_name')) {
    return _parseMetaMessages(
      json,
      repairMojibake: true,
      vaultId: vaultId,
      personId: personId,
      personaId: personaId,
    );
  }
  if (first.containsKey('senderName')) {
    return _parseMetaMessages(
      json,
      repairMojibake: false,
      vaultId: vaultId,
      personId: personId,
      personaId: personaId,
    );
  }
  throw const FormatException('無法辨識聊天匯出格式');
}

/// Messenger 一般匯出與 Instagram 使用 `sender_name`，文字是 Latin-1 誤讀的 UTF-8。
/// 加密備份使用 `senderName`，文字已是正確 Unicode，不可再修復。
PersonaChatImport _parseMetaMessages(
  Map<String, dynamic> json, {
  required bool repairMojibake,
  required String vaultId,
  required String personId,
  required String personaId,
}) {
  final source = repairMojibake ? _repairFacebookStrings(json) : json;
  final repaired = source is Map ? Map<String, dynamic>.from(source) : json;
  final encrypted = !repairMojibake;
  final incoming = <_IncomingMessage>[];
  for (final raw in repaired['messages'] as List? ?? const []) {
    if (raw is! Map) continue;
    final message = Map<String, dynamic>.from(raw);
    if (message['isUnsent'] == true || message['is_unsent'] == true) continue;
    final name = encrypted ? message['senderName'] : message['sender_name'];
    final text = encrypted ? message['text'] : message['content'];
    final stamp = encrypted ? message['timestamp'] : message['timestamp_ms'];
    if (name is! String || name.isEmpty || text is! String || text.isEmpty) {
      continue;
    }
    final millis = stamp is int
        ? stamp
        : stamp is num
        ? stamp.toInt()
        : null;
    if (millis == null) continue;
    incoming.add(
      _IncomingMessage(
        label: name,
        text: text,
        sentAtLocal: _sentAtFromEpochMilliseconds(millis),
      ),
    );
  }
  return _assemble(
    incoming,
    vaultId: vaultId,
    personId: personId,
    personaId: personaId,
  );
}

Object? _repairFacebookStrings(Object? value) {
  if (value is String) return _repairFacebookString(value);
  if (value is List) {
    return [for (final item in value) _repairFacebookStrings(item)];
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key: _repairFacebookStrings(entry.value),
    };
  }
  return value;
}

String _repairFacebookString(String value) {
  try {
    return utf8.decode(latin1.encode(value));
  } on ArgumentError {
    return value;
  } on FormatException {
    return value;
  }
}

String _sentAtFromEpochMilliseconds(int milliseconds) {
  final local = DateTime.fromMillisecondsSinceEpoch(
    milliseconds,
    isUtc: true,
  ).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-'
      '${two(local.month)}-${two(local.day)}T'
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

class _IncomingMessage {
  const _IncomingMessage({
    required this.label,
    required this.text,
    required this.sentAtLocal,
    this.system = false,
    this.quoteRanges = const [],
  });

  final String label;
  final String text;
  final String sentAtLocal;
  final bool system;
  final List<PrivateTextRange> quoteRanges;
}

PersonaChatImport _assemble(
  List<_IncomingMessage> incoming, {
  required String vaultId,
  required String personId,
  required String personaId,
  Set<String> namedSpeakerLabels = const {},
}) {
  final ordered = [...incoming]
    ..sort((a, b) => a.sentAtLocal.compareTo(b.sentAtLocal));
  final seen = <String>{};
  final speakers = <String, PersonaImportSpeaker>{};
  final messages = <PersonaImportMessage>[];
  for (final item in ordered) {
    // 重複鍵是說話者、秒級時間與文字前 64 個 UTF-16 code units。
    final head = item.text.length <= 64
        ? item.text
        : item.text.substring(0, 64);
    final key =
        '${item.label}\u0000${item.sentAtLocal}\u0000$head\u0000${item.system}';
    if (!seen.add(key)) continue;
    final speaker = item.system || item.label.isEmpty
        ? null
        : speakers.putIfAbsent(
            item.label,
            () => PersonaImportSpeaker(
              // named- 表示這次由名字步驟指定。送出時這些 label 用 import: 代號；內建匯入沒有此前綴。
              id: '${namedSpeakerLabels.contains(item.label) ? 'named-' : ''}s${speakers.length + 1}',
              label: item.label,
            ),
          );
    messages.add(
      PersonaImportMessage(
        id: 'm${messages.length + 1}',
        speakerId: speaker?.id,
        text: item.text,
        sentAtLocal: item.sentAtLocal,
        system: item.system,
        quoteRanges: item.quoteRanges,
      ),
    );
  }
  if (messages.where((message) => !message.system).isEmpty) {
    throw const FormatException('無法辨識聊天匯出格式');
  }
  final result = PersonaChatImport(
    vaultId: vaultId,
    personId: personId,
    personaId: personaId,
    importId: generatePersonaImportId(),
    importedAt: DateTime.now(),
    speakers: speakers.values.toList(),
    messages: messages,
  );
  result.validate();
  return result;
}

PersonaChatImport _mergeImports(
  List<PersonaChatImport> parts, {
  required String vaultId,
  required String personId,
  required String personaId,
}) {
  final incoming = <_IncomingMessage>[];
  for (final part in parts) {
    final names = {
      for (final speaker in part.speakers) speaker.id: speaker.label,
    };
    for (final message in part.messages) {
      incoming.add(
        _IncomingMessage(
          label: message.speakerId == null
              ? ''
              : names[message.speakerId] ?? '',
          text: message.text,
          sentAtLocal: message.sentAtLocal,
          system: message.system,
          quoteRanges: message.quoteRanges,
        ),
      );
    }
  }
  final masked = <String>{};
  final roles = <String, PersonaSpeakerRole>{};
  for (final part in parts) {
    for (final speaker in part.speakers) {
      if (speaker.id.startsWith('named-')) masked.add(speaker.label);
      final current = roles[speaker.label];
      if (current == null || current == PersonaSpeakerRole.unknown) {
        roles[speaker.label] = speaker.role;
      }
    }
  }
  final chat = _assemble(
    incoming,
    vaultId: vaultId,
    personId: personId,
    personaId: personaId,
    namedSpeakerLabels: masked,
  );
  for (final speaker in chat.speakers) {
    final role = roles[speaker.label];
    if (role != null) speaker.role = role;
  }
  return chat;
}

enum _LineAccept { added, omitted, invalid }

const _linePeriod = '(上午|下午|午前|午後|am|pm)';

/// 只解析 LINE 已知的日期、分隔符與引用標記，不從自然語言推測發言者。
({PersonaChatImport chat, int skippedLines}) _parseLineTextChat(
  String input, {
  required String vaultId,
  required String personId,
  required String personaId,
}) {
  final speakers = <String, PersonaImportSpeaker>{};
  final messages = <PersonaImportMessage>[];
  var skippedLines = 0;
  var allowContinuation = false;
  String? date;
  final androidMessage = RegExp(
    '^(?:$_linePeriod\\s*)?(\\d{1,2}):(\\d{2})(?:\\s*$_linePeriod)?\\t([^\\t]+)\\t(.*)\$',
    caseSensitive: false,
  );
  final desktopMessage = RegExp(
    '^(?:$_linePeriod\\s*)?(\\d{1,2}):(\\d{2})(?:\\s*$_linePeriod)? +(\\S+) +(.*)\$',
    caseSensitive: false,
  );
  final iosMessage = RegExp(
    r'^\[(\d{4})[/.\-](\d{1,2})[/.\-](\d{1,2}),?\s+(\d{1,2}):(\d{2})(?::\d{2})?\]\s+([^:]+):\s?(.*)$',
  );
  final attachment = RegExp(
    r'^\[(?:貼圖|照片|圖片|影片|語音訊息|檔案|Sticker|Photo|Video|Voice message|File)\]$',
    caseSensitive: false,
  );
  final unsent = RegExp(
    r'^(?:您已收回訊息|.+已收回訊息|You unsent a message\.?)$',
    caseSensitive: false,
  );
  final brokenTime = RegExp(
    '^(?:$_linePeriod\\s*)?\\d{1,2}:\\d{2}(?:\\s*(?:am|pm))?\\t',
    caseSensitive: false,
  );

  void skip() {
    allowContinuation = false;
    skippedLines++;
  }

  _LineAccept add(
    String day,
    String hour,
    String minute,
    String name,
    String text, {
    String? period,
  }) {
    allowContinuation = false;
    final trimmed = text.trim();
    if (attachment.hasMatch(trimmed) || unsent.hasMatch(trimmed)) {
      return _LineAccept.omitted;
    }
    final parsedHour = int.tryParse(hour);
    final parsedMinute = int.tryParse(minute);
    if (parsedHour == null || parsedMinute == null) return _LineAccept.invalid;
    final clock = formatTextChatClock(
      hour: parsedHour,
      minute: parsedMinute,
      marker: period,
    );
    if (clock == null) return _LineAccept.invalid;
    final speaker = speakers.putIfAbsent(
      name,
      () => PersonaImportSpeaker(id: 's${speakers.length + 1}', label: name),
    );
    messages.add(
      PersonaImportMessage(
        id: 'm${messages.length + 1}',
        speakerId: speaker.id,
        text: text,
        sentAtLocal: '${day}T$clock',
      ),
    );
    allowContinuation = true;
    return _LineAccept.added;
  }

  void takeMessage(RegExpMatch message) {
    if (date == null) {
      skip();
      return;
    }
    if (add(
          date,
          message[2]!,
          message[3]!,
          message[5]!,
          message[6]!,
          period: message[1] ?? message[4],
        ) ==
        _LineAccept.invalid) {
      skip();
    }
  }

  for (final raw in input.replaceFirst('\uFEFF', '').split(RegExp(r'\r?\n'))) {
    final ios = iosMessage.firstMatch(raw);
    if (ios != null) {
      final parsedDay = textChatDay(ios[1]!, ios[2]!, ios[3]!);
      if (parsedDay == null) {
        skip();
        continue;
      }
      date = parsedDay;
      if (add(date, ios[4]!, ios[5]!, ios[6]!, ios[7]!) ==
          _LineAccept.invalid) {
        skip();
      }
      continue;
    }
    final heading = textChatDateLine.firstMatch(raw);
    if (heading != null) {
      final parsedDay = textChatDay(heading[1]!, heading[2]!, heading[3]!);
      allowContinuation = false;
      if (parsedDay == null) {
        skippedLines++;
        continue;
      }
      date = parsedDay;
      continue;
    }
    final tabbed = androidMessage.firstMatch(raw);
    if (tabbed != null) {
      takeMessage(tabbed);
      continue;
    }
    final spaced = desktopMessage.firstMatch(raw);
    if (spaced != null) {
      takeMessage(spaced);
      continue;
    }
    if (date == null || raw.trim().isEmpty) continue;
    if (unsent.hasMatch(raw.split('\t').last.trim())) {
      allowContinuation = false;
      continue;
    }
    if (brokenTime.hasMatch(raw)) {
      allowContinuation = false;
      messages.add(
        PersonaImportMessage(
          id: 'm${messages.length + 1}',
          speakerId: null,
          text: raw,
          sentAtLocal: '${date}T00:00:00',
          system: true,
        ),
      );
      continue;
    }
    if (allowContinuation && messages.isNotEmpty && !messages.last.system) {
      final last = messages.removeLast();
      messages.add(
        PersonaImportMessage(
          id: last.id,
          speakerId: last.speakerId,
          text: '${last.text}\n$raw',
          sentAtLocal: last.sentAtLocal,
        ),
      );
      continue;
    }
    skip();
  }
  if (messages.where((m) => !m.system).isEmpty) {
    throw const FormatException('無法辨識 LINE 文字匯出格式');
  }
  PersonaImportMessage finish(PersonaImportMessage message) {
    final text = message.system ? message.text : _unwrapLineQuote(message.text);
    return PersonaImportMessage(
      id: message.id,
      speakerId: message.speakerId,
      text: text,
      sentAtLocal: message.sentAtLocal,
      system: message.system,
      quoteRanges: [
        for (final q in RegExp(r'^>.*$', multiLine: true).allMatches(text))
          if (q.start < q.end) PrivateTextRange(q.start, q.end),
      ],
    );
  }

  final result = PersonaChatImport(
    vaultId: vaultId,
    personId: personId,
    personaId: personaId,
    importId: generatePersonaImportId(),
    importedAt: DateTime.now(),
    speakers: speakers.values.toList(),
    messages: [for (final message in messages) finish(message)],
  );
  result.validate();
  return (chat: result, skippedLines: skippedLines);
}

String _unwrapLineQuote(String text) {
  if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
    return text.substring(1, text.length - 1);
  }
  return text;
}
