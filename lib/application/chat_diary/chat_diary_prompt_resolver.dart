import 'package:quill_diary/domain/chat_diary/chat_diary_settings.dart';

import '../../infrastructure/preferences/personalization_preferences.dart';
import '../../l10n/app_localizations.dart';

enum ChatDiaryPromptPurpose { conversation, generation }

String resolveChatDiaryPrompt(
  ChatDiaryPromptPurpose purpose,
  AppLanguage language,
  ChatDiaryPromptSettings settings,
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
