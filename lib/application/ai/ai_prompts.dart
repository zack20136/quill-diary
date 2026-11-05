import 'package:quill_diary/domain/ai/ai_stored_settings.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';

enum ChatDiaryPromptPurpose { conversation, generation }

String resolveChatDiaryPrompt(
  ChatDiaryPromptPurpose purpose,
  AppLanguage language,
  AiPromptOverrides settings,
) {
  final l10n = lookupAppLocalizations(language.materialLocale);
  return switch (purpose) {
    ChatDiaryPromptPurpose.conversation =>
      settings.conversationOverride ??
          l10n.chatDiaryConversationDefaultSystemPrompt,
    ChatDiaryPromptPurpose.generation =>
      settings.generationOverride ??
          l10n.chatDiaryGenerationDefaultSystemPrompt,
  };
}

String resolveDiaryOrganizationPrompt({
  required bool generate,
  required AppLanguage language,
  required AiPromptOverrides settings,
}) {
  final l10n = lookupAppLocalizations(language.materialLocale);
  if (generate) {
    return settings.generationOverride ?? l10n.organizationGenerationPrompt;
  }
  return settings.conversationOverride ?? l10n.organizationConversationPrompt;
}
