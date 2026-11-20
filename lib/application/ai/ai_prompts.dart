import 'package:quill_diary/application/ai/ai_prompt_localizations.dart';
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
  final l10n = localizationsFor(language);
  final conversationRules =
      '${l10n.chatDiaryConversationRoleLine}\n\n'
      '${l10n.chatDiaryConversationRules}';
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
    ChatDiaryPromptPurpose.generationRules => l10n.chatDiaryGenerationRules,
    ChatDiaryPromptPurpose.generationGuidance => generationGuidance,
    ChatDiaryPromptPurpose.generation =>
      '${l10n.chatDiaryGenerationRules}\n\n$generationGuidance',
  };
}

String resolveDiaryOrganizationPrompt({
  required bool generate,
  required AppLanguage language,
  required DiaryOrganizationPromptSettings settings,
}) {
  final l10n = localizationsFor(language);
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
  final l10n = localizationsFor(language);
  final stageRules = generate
      ? l10n.organizationDraftRulesPrompt
      : l10n.organizationDiscussionRulesPrompt;
  final prompt = resolveDiaryOrganizationPrompt(
    generate: generate,
    language: language,
    settings: settings,
  );
  return '${l10n.organizationRules}\n\n$stageRules\n\n$prompt';
}
