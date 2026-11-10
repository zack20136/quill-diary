import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

Person personaPerson(String name) => Person(
  id: generatePersonId(),
  name: name,
  createdAt: DateTime.utc(2026, 11, 6),
  updatedAt: DateTime.utc(2026, 11, 6),
);

PersonaRecord personaDraftRecord(String vaultId, String personId) =>
    PersonaRecord(
      vaultId: vaultId,
      personId: personId,
      personaId: generatePersonaId(),
      draft: PersonaDraft(
        target: PersonaUpdateTarget.both,
        baseUpdatedAt: {for (final kind in PersonaCardKind.values) kind: null},
      ),
    );

Map<PersonaCardKind, PersonaCandidate> personaCandidates({
  String memory = '既有記憶',
  String tone = '簡短自然',
}) => {
  PersonaCardKind.memory: PersonaCandidate(text: memory),
  PersonaCardKind.tone: PersonaCandidate(text: tone),
};
