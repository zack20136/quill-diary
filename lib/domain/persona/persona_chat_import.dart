import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/persona/persona.dart';
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

class PersonaChatImport {
  PersonaChatImport({
    required this.vaultId,
    required this.personId,
    required this.personaId,
    required this.importId,
    required this.importedAt,
    required this.speakers,
    required this.messages,
  });
  final String vaultId;
  final String personId;
  final String personaId;
  final String importId;
  final DateTime importedAt;
  final List<PersonaImportSpeaker> speakers;
  final List<PersonaImportMessage> messages;

  Iterable<PersonaImportMessage> messagesInWindow(PersonaChatSource source) {
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
  };
  factory PersonaChatImport.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] is! int ||
        json['schema_version'] != DataVersions.personaImport) {
      throw const FormatException('不支援的聊天匯入格式');
    }
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
      messages: (json['messages'] as List)
          .map(
            (v) => PersonaImportMessage.fromJson(
              Map<String, dynamic>.from(v as Map),
            ),
          )
          .toList(),
    );
    result.validate();
    return result;
  }
}

/// 只解析 LINE 已知的日期、分隔符與引用標記，不從自然語言推測發言者。
PersonaChatImport parsePersonaLineChat(
  String input, {
  required String vaultId,
  required String personId,
  required String personaId,
}) {
  final speakers = <String, PersonaImportSpeaker>{};
  final messages = <PersonaImportMessage>[];
  bool allowContinuation = false;
  String? date;
  final datePattern = RegExp(
    r'^(\d{4})[/.\-](\d{1,2})[/.\-](\d{1,2})(?:\s*[（(][^）)\r\n]+[）)])?\s*$',
  );
  final androidMessage = RegExp(r'^(\d{1,2}):(\d{2})\t([^\t]+)\t(.*)$');
  final iosMessage = RegExp(
    r'^\[(\d{4})[/.\-](\d{1,2})[/.\-](\d{1,2}),?\s+(\d{1,2}):(\d{2})(?::\d{2})?\]\s+([^:]+):\s?(.*)$',
  );
  final attachment = RegExp(
    r'^\[(?:貼圖|照片|圖片|影片|語音訊息|檔案|Sticker|Photo|Video|Voice message|File)\]$',
    caseSensitive: false,
  );
  void add(String day, String hour, String minute, String name, String text) {
    allowContinuation = false;
    if (attachment.hasMatch(text.trim())) return;
    final h = int.parse(hour);
    if (h > 23 || int.parse(minute) > 59) {
      throw const FormatException('LINE 時間不正確');
    }
    final speaker = speakers.putIfAbsent(
      name,
      () => PersonaImportSpeaker(id: 's${speakers.length + 1}', label: name),
    );
    messages.add(
      PersonaImportMessage(
        id: 'm${messages.length + 1}',
        speakerId: speaker.id,
        text: text,
        sentAtLocal: '${day}T${hour.padLeft(2, '0')}:$minute:00',
      ),
    );
    allowContinuation = true;
  }

  String day(String y, String m, String d) {
    final value = '$y-${m.padLeft(2, '0')}-${d.padLeft(2, '0')}';
    if (DateOnly.tryParse(value) == null) {
      throw const FormatException('LINE 日期不正確');
    }
    return value;
  }

  for (final raw in input.replaceFirst('\uFEFF', '').split(RegExp(r'\r?\n'))) {
    final ios = iosMessage.firstMatch(raw);
    if (ios != null) {
      date = day(ios[1]!, ios[2]!, ios[3]!);
      add(date, ios[4]!, ios[5]!, ios[6]!, ios[7]!);
      continue;
    }
    final heading = datePattern.firstMatch(raw);
    if (heading != null) {
      allowContinuation = false;
      date = day(heading[1]!, heading[2]!, heading[3]!);
      continue;
    }
    final message = androidMessage.firstMatch(raw);
    if (message != null) {
      if (date == null) throw const FormatException('LINE 訊息缺少日期');
      add(date, message[1]!, message[2]!, message[3]!, message[4]!);
      continue;
    }
    if (date == null || raw.trim().isEmpty) continue;
    if (RegExp(r'^\d{1,2}:\d{2}\t').hasMatch(raw)) {
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
    } else if (allowContinuation &&
        messages.isNotEmpty &&
        !messages.last.system) {
      final last = messages.removeLast();
      final text = '${last.text}\n$raw';
      messages.add(
        PersonaImportMessage(
          id: last.id,
          speakerId: last.speakerId,
          text: text,
          sentAtLocal: last.sentAtLocal,
        ),
      );
    }
  }
  if (messages.where((m) => !m.system).isEmpty) {
    throw const FormatException('無法辨識 LINE 文字匯出格式');
  }
  final result = PersonaChatImport(
    vaultId: vaultId,
    personId: personId,
    personaId: personaId,
    importId: generatePersonaImportId(),
    importedAt: DateTime.now(),
    speakers: speakers.values.toList(),
    messages: [
      for (final m in messages)
        PersonaImportMessage(
          id: m.id,
          speakerId: m.speakerId,
          text: m.text,
          sentAtLocal: m.sentAtLocal,
          system: m.system,
          quoteRanges: [
            for (final q in RegExp(
              r'^>.*$',
              multiLine: true,
            ).allMatches(m.text))
              if (q.start < q.end) PrivateTextRange(q.start, q.end),
          ],
        ),
    ],
  );
  result.validate();
  return result;
}
