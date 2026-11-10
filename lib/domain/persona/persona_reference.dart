import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

class PersonaReference {
  const PersonaReference({required this.personId, required this.personaId});
  final String personId;
  final String personaId;
  bool matches(PersonaRecord? record) =>
      record?.available == true &&
      record!.personId == personId &&
      record.personaId == personaId;
  Map<String, Object?> toJson() => {
    'person_id': personId,
    'persona_id': personaId,
  };
  factory PersonaReference.fromJson(Map<String, dynamic> json) {
    final value = PersonaReference(
      personId: json['person_id'] as String,
      personaId: json['persona_id'] as String,
    );
    if (!isPrefixedId(value.personId, 'per') ||
        !isPrefixedId(value.personaId, 'prs')) {
      throw const FormatException('分身參照不正確');
    }
    return value;
  }
}

class PersonaParticipant {
  const PersonaParticipant({required this.name, this.accentArgb});
  final String name;
  final int? accentArgb;
  Map<String, Object?> toJson() => {'name': name, 'accent_argb': accentArgb};
  factory PersonaParticipant.fromJson(Map<String, dynamic> json) =>
      PersonaParticipant(
        name: json['name'] as String,
        accentArgb: json['accent_argb'] as int?,
      );
}
