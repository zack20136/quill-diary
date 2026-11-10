import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/persona/persona_prompts.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';

void main() {
  final l10n = lookupAppLocalizations(AppLanguage.zh.materialLocale);

  test('分身固定指令以身分句開頭，並使用目前生效的對話引導', () {
    final defaults = personaFixedInstructions(l10n: l10n);
    expect(defaults, startsWith(l10n.personaIdentityPrompt));
    expect(defaults, contains(l10n.chatDiaryConversationRulesPrompt));
    expect(defaults, endsWith(l10n.chatDiaryConversationGuidancePrompt));
    expect(defaults, isNot(contains(l10n.chatDiaryConversationRoleLine)));

    final overridden = personaFixedInstructions(l10n: l10n, guidance: '本次共通引導');
    expect(overridden, endsWith('本次共通引導'));
    expect(
      overridden,
      isNot(contains(l10n.chatDiaryConversationGuidancePrompt)),
    );
  });
}
