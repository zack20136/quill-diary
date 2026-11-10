import 'package:quill_diary/domain/ai/ai_stored_settings.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';

enum ChatDiaryPromptPurpose {
  conversation,
  rules,
  personality,
  guidance,
  generation,
}

String resolveChatDiaryPrompt(
  ChatDiaryPromptPurpose purpose,
  AppLanguage language,
  ChatDiaryPromptSettings settings,
) {
  final l10n = lookupAppLocalizations(language.materialLocale);
  final rules =
      '${l10n.chatDiaryConversationRoleLine}\n\n'
      '${l10n.chatDiaryConversationRulesPrompt}';
  return switch (purpose) {
    ChatDiaryPromptPurpose.conversation =>
      '$rules\n\n'
          '${settings.guidanceOverride ?? l10n.chatDiaryConversationGuidancePrompt}\n\n'
          '${settings.personalityOverride ?? l10n.chatDiaryDefaultPersonalityPrompt}',
    ChatDiaryPromptPurpose.rules => rules,
    ChatDiaryPromptPurpose.personality =>
      settings.personalityOverride ?? l10n.chatDiaryDefaultPersonalityPrompt,
    ChatDiaryPromptPurpose.guidance =>
      settings.guidanceOverride ?? l10n.chatDiaryConversationGuidancePrompt,
    ChatDiaryPromptPurpose.generation =>
      settings.generationOverride ??
          l10n.chatDiaryGenerationDefaultSystemPrompt,
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
