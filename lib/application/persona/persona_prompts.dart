import 'package:quill_diary/application/ai/ai_prompt_localizations.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_privacy_processor.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';
import 'package:quill_diary/l10n/l10n.dart';

String buildPersonaConversationPrompt({
  required String personId,
  required String personaId,
  required Map<PersonaCardKind, PersonaCandidate> cards,
  required Iterable<Person> people,
  required ChatDiaryPrivacyProcessor privacy,
  required AppLocalizations l10n,
  String? guidance,
}) {
  final names = {for (final person in people) person.id: person.name};
  final protectedCards = <PersonaCardKind, String>{};
  for (final kind in PersonaCardKind.values) {
    final card = cards[kind]!;
    card.validate(kind);
    protectedCards[kind] = privacy.protectPrompt(
      card.text.replaceAllMapped(privacyTokenPattern, (match) {
        final token = match[0]!;
        final id = card.tokens[token];
        return id == null || names[id] == null
            ? privacy.personaAnonymousToken(
                '$personaId:${kind.name}:$token',
                l10n.personaRoleSubject,
              )
            : privacy.personaPersonToken(id, names[id]!);
      }),
    );
  }
  final subject = privacy.personaPersonToken(
    personId,
    names[personId] ?? l10n.personaRoleSubject,
  );
  final instructions = privacy.protectPrompt(
    personaFixedInstructions(l10n: l10n, guidance: guidance),
  );
  return personaConversationInstructions(
    l10n,
    instructions: instructions,
    subject: subject,
    memory: protectedCards[PersonaCardKind.memory]!,
    tone: protectedCards[PersonaCardKind.tone]!,
  );
}

String personaConversationInstructions(
  AppLocalizations l10n, {
  required String instructions,
  required String subject,
  required String memory,
  required String tone,
}) => [
  instructions,
  '${l10n.personaSubjectHeading}\n$subject',
  '${l10n.personaMemory}\n$memory',
  '${l10n.personaTone}\n$tone',
].join('\n\n');

String personaAttributedMessage({
  required AppLocalizations l10n,
  required String text,
  required bool persona,
  String? personToken,
}) => persona
    ? '${l10n.personaSubjectHeading}\n$personToken\n\n$text'
    : '${l10n.personaDefaultName}\n\n$text';

String personaFixedInstructions({
  required AppLocalizations l10n,
  String? guidance,
}) =>
    '${l10n.personaIdentityPrompt}\n\n'
    '${l10n.chatDiaryConversationRules}\n\n'
    '${guidance ?? l10n.personaConversationGuidancePrompt}';

String personaGenerationInstructions(
  AppLocalizations l10n,
  PersonaUpdateTarget target, {
  bool compact = false,
}) => [
  if (target.kinds.contains(PersonaCardKind.memory))
    l10n.personaMemoryUpdatePrompt,
  if (target.kinds.contains(PersonaCardKind.tone)) l10n.personaToneUpdatePrompt,
  'target: ${target.name}',
  l10n.personaOutputRules(
    compact
        ? PersonaLimits.compactMemoryCodeUnits
        : PersonaLimits.memoryCodeUnits,
    compact ? PersonaLimits.compactToneCodeUnits : PersonaLimits.toneCodeUnits,
  ),
  compact ? l10n.personaCardRepairPrompt : l10n.personaCardOutputLanguage,
].join('\n\n');

String personaExtractionInstructions(
  AppLocalizations l10n,
  PersonaUpdateTarget target, {
  bool retry = false,
}) => [
  l10n.personaExtractionRules,
  'target: ${target.name}',
  if (retry) l10n.personaExtractionRetryPrompt,
  l10n.personaCardOutputLanguage,
].join('\n\n');
