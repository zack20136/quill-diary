import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/ai/ai_prompts.dart';
import 'package:quill_diary/domain/ai/ai_stored_settings.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';

void main() {
  final zh = lookupAppLocalizations(AppLanguage.zh.materialLocale);
  final en = lookupAppLocalizations(AppLanguage.en.materialLocale);

  test('聊天提示詞依語言使用內建，自訂內容不隨語言改寫', () {
    const defaults = ChatDiaryPromptSettings();
    final zhChat = resolveChatDiaryPrompt(
      ChatDiaryPromptPurpose.conversation,
      AppLanguage.zh,
      defaults,
    );
    final enChat = resolveChatDiaryPrompt(
      ChatDiaryPromptPurpose.conversation,
      AppLanguage.en,
      defaults,
    );

    expect(zhChat, startsWith(zh.chatDiaryConversationRoleLine));
    expect(zhChat, contains(zh.chatDiaryConversationRulesPrompt));
    expect(enChat, startsWith(en.chatDiaryConversationRoleLine));
    expect(enChat, contains(en.chatDiaryConversationRulesPrompt));
    expect(enChat, isNot(contains(zh.chatDiaryConversationRulesPrompt)));
    expect(enChat, isNot(contains('【')));
    expect(
      resolveChatDiaryPrompt(
        ChatDiaryPromptPurpose.conversationRules,
        AppLanguage.zh,
        defaults,
      ),
      startsWith(zh.chatDiaryConversationRoleLine),
    );

    const custom = ChatDiaryPromptSettings(
      personalityOverride: '自訂聊天',
      guidanceOverride: '自訂接話方式',
    );
    for (final language in AppLanguage.values) {
      final l10n = lookupAppLocalizations(language.materialLocale);
      final conversation = resolveChatDiaryPrompt(
        ChatDiaryPromptPurpose.conversation,
        language,
        custom,
      );
      expect(conversation, startsWith(l10n.chatDiaryConversationRoleLine));
      expect(conversation, contains(l10n.chatDiaryConversationRulesPrompt));
      expect(conversation, contains('自訂接話方式'));
      expect(conversation, contains('自訂聊天'));
      expect(
        conversation,
        isNot(contains(l10n.chatDiaryConversationGuidancePrompt)),
      );
    }
    const generationOnly = ChatDiaryPromptSettings(generationOverride: '自訂日記');
    expect(
      resolveChatDiaryPrompt(
        ChatDiaryPromptPurpose.conversation,
        AppLanguage.en,
        generationOnly,
      ),
      contains(en.chatDiaryConversationGuidancePrompt),
    );
  });

  test('生成規則保留於內建與自訂引導之前，既有自訂文字不改寫', () {
    const legacy = '  請用 JSON 輸出，並保留我的原始寫法。\n自訂內容不自動刪改。  ';
    const custom = ChatDiaryPromptSettings(generationOverride: legacy);
    for (final language in AppLanguage.values) {
      final l10n = lookupAppLocalizations(language.materialLocale);
      final defaults = resolveChatDiaryPrompt(
        ChatDiaryPromptPurpose.generation,
        language,
        const ChatDiaryPromptSettings(),
      );
      expect(defaults, startsWith(l10n.chatDiaryGenerationRulesPrompt));
      expect(defaults, endsWith(l10n.chatDiaryGenerationGuidancePrompt));
      final generated = resolveChatDiaryPrompt(
        ChatDiaryPromptPurpose.generation,
        language,
        custom,
      );
      expect(generated, '${l10n.chatDiaryGenerationRulesPrompt}\n\n$legacy');
      expect(
        generated,
        isNot(contains(l10n.chatDiaryGenerationGuidancePrompt)),
      );
      expect(
        resolveChatDiaryPrompt(
          ChatDiaryPromptPurpose.generationRules,
          language,
          custom,
        ),
        l10n.chatDiaryGenerationRulesPrompt,
      );
      expect(
        resolveChatDiaryPrompt(
          ChatDiaryPromptPurpose.generationGuidance,
          language,
          custom,
        ),
        legacy,
      );
    }
  });

  test('整理提示詞依語言使用內建，自訂內容不隨語言改寫', () {
    const defaults = DiaryOrganizationPromptSettings();
    final zhChat = resolveDiaryOrganizationInstructions(
      generate: false,
      language: AppLanguage.zh,
      settings: defaults,
    );
    final enChat = resolveDiaryOrganizationInstructions(
      generate: false,
      language: AppLanguage.en,
      settings: defaults,
    );
    final zhDraft = resolveDiaryOrganizationInstructions(
      generate: true,
      language: AppLanguage.zh,
      settings: defaults,
    );
    final enDraft = resolveDiaryOrganizationInstructions(
      generate: true,
      language: AppLanguage.en,
      settings: defaults,
    );

    // 隱私代號規則是安全不變量，即使文案改寫也必須保留。
    expect(zhChat, contains('同一個 ⟦P…⟧ 代號代表同一位人物'));
    expect(zhDraft, contains('同一個 ⟦P…⟧ 代號代表同一位人物'));
    expect(enChat, contains('The same ⟦P…⟧ token means the same person'));
    expect(enDraft, contains('The same ⟦P…⟧ token means the same person'));

    expect(zhChat, contains(zh.organizationConversationPrompt));
    expect(enChat, contains(en.organizationConversationPrompt));
    expect(zhDraft, contains(zh.organizationGenerationPrompt));
    expect(enDraft, contains(en.organizationGenerationPrompt));
    expect(zhChat, isNot(contains(en.organizationConversationPrompt)));
    expect(enDraft, isNot(contains(zh.organizationGenerationPrompt)));

    const custom = DiaryOrganizationPromptSettings(
      conversationOverride: '自訂需求',
      generationOverride: 'Custom draft',
    );
    for (final language in AppLanguage.values) {
      final l10n = lookupAppLocalizations(language.materialLocale);
      expect(
        resolveDiaryOrganizationInstructions(
          generate: false,
          language: language,
          settings: custom,
        ),
        allOf(contains('自訂需求'), contains(l10n.organizationRulesPrompt)),
      );
      expect(
        resolveDiaryOrganizationInstructions(
          generate: true,
          language: language,
          settings: custom,
        ),
        allOf(contains('Custom draft'), contains(l10n.organizationRulesPrompt)),
      );
    }

    const generationOnly = DiaryOrganizationPromptSettings(
      generationOverride: '只改生成',
    );
    expect(
      resolveDiaryOrganizationPrompt(
        generate: false,
        language: AppLanguage.en,
        settings: generationOnly,
      ),
      en.organizationConversationPrompt,
    );
    expect(
      resolveDiaryOrganizationPrompt(
        generate: true,
        language: AppLanguage.zh,
        settings: generationOnly,
      ),
      '只改生成',
    );
  });
}
