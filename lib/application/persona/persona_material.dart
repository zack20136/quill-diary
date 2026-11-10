import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/domain/persona/persona_privacy.dart';

/// 閱讀預覽與請求序列化共用已遮罩文字，不保存另一份原文。
class PersonaMaterial {
  const PersonaMaterial.diary({
    required this.label,
    required this.date,
    required this.text,
  }) : isDiary = true,
       speakerRole = null,
       speaker = null,
       styleText = null;

  const PersonaMaterial.chat({
    required this.label,
    required this.date,
    required this.text,
    required this.speakerRole,
    required this.speaker,
    required this.styleText,
  }) : isDiary = false;

  final String label;
  final String date;
  final String text;
  final bool isDiary;
  final PersonaSpeakerRole? speakerRole;
  final String? speaker;
  final String? styleText;

  bool get hasToneEvidence =>
      speakerRole == PersonaSpeakerRole.personaSubject &&
      personaHasVisibleText(styleText ?? '');

  Map<String, Object?> toRequestJson() => isDiary
      ? {'source': 'diary', 'author_role': 'user', 'date': date, 'text': text}
      : {
          'source': 'line',
          'speaker_role': speakerRole!.requestValue,
          'speaker': speaker,
          'sent_at_local': date,
          'text': text,
          'style_text': styleText,
        };
}
