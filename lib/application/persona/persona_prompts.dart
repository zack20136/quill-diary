import 'dart:convert';

import 'package:quill_diary/domain/chat_diary/chat_diary_privacy_processor.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';
import 'package:quill_diary/l10n/app_localizations.dart';

String buildPersonaConversationPrompt<T extends PersonaCandidate>({
  required String personId,
  required String personaId,
  required Map<PersonaCardKind, T> cards,
  required Iterable<Person> people,
  required ChatDiaryPrivacyProcessor privacy,
  required AppLocalizations l10n,
  String? guidance,
}) {
  final names = {for (final person in people) person.id: person.name};
  final protectedCards = <String, String>{};
  for (final kind in PersonaCardKind.values) {
    final card = cards[kind]!;
    card.validate(kind);
    protectedCards[kind.name] = privacy.protectPrompt(
      card.text.replaceAllMapped(privacyTokenPattern, (match) {
        final token = match[0]!;
        final id = card.tokens[token];
        return id == null || names[id] == null
            ? privacy.personaAnonymousToken(
                '$personaId:${kind.name}:$token',
                l10n.personaRoleFriend,
              )
            : privacy.personaPersonToken(id, names[id]!);
      }),
    );
  }
  final subject = privacy.personaPersonToken(
    personId,
    names[personId] ?? l10n.personaRoleFriend,
  );
  final instructions = privacy.protectPrompt(
    personaFixedInstructions(l10n: l10n, guidance: guidance),
  );
  return '$instructions\n\n${jsonEncode({'current_ai_persona': subject, 'cards': protectedCards})}';
}

/// 分身固定指令：身分句取代一般聊天的通用角色句，其餘與聊天相同。
String personaFixedInstructions({
  required AppLocalizations l10n,
  String? guidance,
}) =>
    '${l10n.personaIdentityPrompt}\n\n'
    '${l10n.chatDiaryConversationRulesPrompt}\n\n'
    '${guidance ?? l10n.chatDiaryConversationGuidancePrompt}';
