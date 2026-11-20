import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/domain/persona/persona_privacy.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

final _previousDayWording = RegExp(
  r'昨[天日晚]|\byesterday\b|\blast night\b',
  caseSensitive: false,
);

/// 閱讀預覽與請求序列化共用已遮罩文字，不保存另一份原文。
class PersonaMaterial {
  const PersonaMaterial.diary({
    required this.label,
    required this.date,
    required this.text,
  }) : isDiary = true,
       isRaw = false,
       speakerRole = null,
       speaker = null,
       speakerName = null,
       styleText = null;

  const PersonaMaterial.chat({
    required this.label,
    required this.date,
    required this.text,
    required this.speakerRole,
    required this.speaker,
    required this.styleText,
    this.speakerName,
  }) : isDiary = false,
       isRaw = false;

  /// 整份原文。沒有逐則說話者或時間，也不提供風格證據。
  const PersonaMaterial.raw({required this.label, required this.text})
    : isDiary = false,
      isRaw = true,
      date = '',
      speakerRole = null,
      speaker = null,
      speakerName = null,
      styleText = null;

  final String label;
  final String date;
  final String text;
  final bool isDiary;
  final bool isRaw;
  final PersonaSpeakerRole? speakerRole;
  final String? speaker;

  /// 其他人在確認頁上的閱讀用名字。請求仍送 [speaker] 代號。
  final String? speakerName;
  final String? styleText;

  bool get hasToneEvidence => isDiary
      ? personaHasVisibleText(text)
      : !isRaw &&
            speakerRole == PersonaSpeakerRole.personaSubject &&
            personaHasVisibleText(styleText ?? '');

  Map<String, Object?> toRequestJson() {
    if (isRaw) return {'source': 'chat', 'text': text};
    final previousDay = _previousLocalDate;
    return {
      'source': isDiary ? 'diary' : 'chat',
      if (isDiary) ...{
        'author_role': 'user',
        'date': date,
      } else ...{
        'speaker_role': speakerRole!.requestValue,
        'speaker': speaker,
        'sent_at_local': date,
        'style_text': styleText,
      },
      if (previousDay != null) 'previous_local_date': previousDay,
      'text': text,
    };
  }

  String? get _previousLocalDate {
    if (!_previousDayWording.hasMatch(text) || date.length < 10) return null;
    final sourceDay = DateOnly.tryParse(date.substring(0, 10));
    if (sourceDay == null) return null;
    final day = sourceDay.toDateTime();
    final previousDay = DateTime.utc(day.year, day.month, day.day - 1);
    return DateOnly.fromDateTime(previousDay).value;
  }
}
