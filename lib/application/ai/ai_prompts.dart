import 'package:quill_diary/domain/ai/ai_stored_settings.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';

enum ChatDiaryPromptPurpose {
  conversation,
  conversationRules,
  personality,
  conversationGuidance,
  generationRules,
  generationGuidance,
  generation,
}

String resolveChatDiaryPrompt(
  ChatDiaryPromptPurpose purpose,
  AppLanguage language,
  ChatDiaryPromptSettings settings,
) {
  final l10n = lookupAppLocalizations(language.materialLocale);
  final conversationRules =
      '${l10n.chatDiaryConversationRoleLine}\n\n'
      '${l10n.chatDiaryConversationRulesPrompt}';
  final generationGuidance =
      settings.generationOverride ?? l10n.chatDiaryGenerationGuidancePrompt;
  return switch (purpose) {
    ChatDiaryPromptPurpose.conversation =>
      '$conversationRules\n\n'
          '${settings.guidanceOverride ?? l10n.chatDiaryConversationGuidancePrompt}\n\n'
          '${settings.personalityOverride ?? l10n.chatDiaryDefaultPersonalityPrompt}',
    ChatDiaryPromptPurpose.conversationRules => conversationRules,
    ChatDiaryPromptPurpose.personality =>
      settings.personalityOverride ?? l10n.chatDiaryDefaultPersonalityPrompt,
    ChatDiaryPromptPurpose.conversationGuidance =>
      settings.guidanceOverride ?? l10n.chatDiaryConversationGuidancePrompt,
    ChatDiaryPromptPurpose.generationRules =>
      l10n.chatDiaryGenerationRulesPrompt,
    ChatDiaryPromptPurpose.generationGuidance => generationGuidance,
    ChatDiaryPromptPurpose.generation =>
      '${l10n.chatDiaryGenerationRulesPrompt}\n\n$generationGuidance',
  };
}

String resolveDiaryOrganizationPrompt({
  required bool generate,
  required AppLanguage language,
  required DiaryOrganizationPromptSettings settings,
}) {
  final l10n = lookupAppLocalizations(language.materialLocale);
  if (generate) {
    return settings.generationOverride ?? l10n.organizationGenerationPrompt;
  }
  return settings.conversationOverride ?? l10n.organizationConversationPrompt;
}

String resolveDiaryOrganizationInstructions({
  required bool generate,
  required AppLanguage language,
  required DiaryOrganizationPromptSettings settings,
}) {
  final l10n = lookupAppLocalizations(language.materialLocale);
  final stage = generate
      ? l10n.organizationGenerationLabel
      : l10n.organizationConversationLabel;
  final prompt = resolveDiaryOrganizationPrompt(
    generate: generate,
    language: language,
    settings: settings,
  );
  return '${l10n.organizationRulesPrompt}\n\n$stage\n\n$prompt';
}
