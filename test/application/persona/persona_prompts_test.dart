import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/persona/persona_prompts.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_privacy_processor.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../helpers/ai/ai_test_helpers.dart';
import '../../helpers/shared/test_l10n.dart';

void main() {
  final l10n = testZhL10n;

  test('分身固定指令以身分句開頭，並使用目前生效的對話引導', () {
    for (final language in AppLanguage.values) {
      final localized = lookupAppLocalizations(language.materialLocale);
      final defaults = personaFixedInstructions(l10n: localized);
      expect(defaults, startsWith(localized.personaIdentityPrompt));
      expect(defaults, contains(localized.chatDiaryConversationRules));
      expect(defaults, endsWith(localized.chatDiaryConversationGuidancePrompt));
      expect(
        defaults,
        isNot(contains(localized.chatDiaryConversationRoleLine)),
      );

      final overridden = personaFixedInstructions(
        l10n: localized,
        guidance: '本次共通引導',
      );
      expect(overridden, startsWith(localized.personaIdentityPrompt));
      expect(overridden, contains(localized.chatDiaryConversationRules));
      expect(overridden, endsWith('本次共通引導'));
      expect(
        overridden,
        isNot(contains(localized.chatDiaryConversationGuidancePrompt)),
      );
    }
  });

  test('聊天提示詞以標示段落附上指定人物、人物記憶與聊天風格', () {
    final person = Person(
      id: 'person-1',
      name: '王小明',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final privacy = ChatDiaryPrivacyProcessor(testChatDiarySession(), [person]);
    final prompt = buildPersonaConversationPrompt(
      personId: person.id,
      personaId: 'persona-1',
      cards: {
        PersonaCardKind.memory: PersonaCandidate(text: '2026-04-02｜一起吃晚餐'),
        PersonaCardKind.tone: PersonaCandidate(text: '句子偏短'),
      },
      people: [person],
      privacy: privacy,
      l10n: l10n,
    );
    expect(prompt, startsWith(l10n.personaIdentityPrompt));
    expect(prompt, contains('${l10n.personaSubjectHeading}\n{{PER_01}}'));
    expect(prompt, contains('${l10n.personaMemory}\n2026-04-02｜一起吃晚餐'));
    expect(prompt, contains('${l10n.personaTone}\n句子偏短'));
    expect(prompt, isNot(contains('王小明')));
    expect(prompt, isNot(contains('current_ai_persona')));
  });

  test('有分身的歷史回覆以指定人物或預設夥伴標示，不用 JSON', () {
    final persona = personaAttributedMessage(
      l10n: l10n,
      text: '今天好累',
      persona: true,
      personToken: '{{PER_01}}',
    );
    final fallback = personaAttributedMessage(
      l10n: l10n,
      text: '今天好累',
      persona: false,
    );
    expect(persona, '${l10n.personaSubjectHeading}\n{{PER_01}}\n\n今天好累');
    expect(fallback, '${l10n.personaDefaultName}\n\n今天好累');
    expect(persona, isNot(contains('ai_persona')));
  });
}
