import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/ai/ai_prompts.dart';
import 'package:quill_diary/domain/ai/ai_stored_settings.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';

void main() {
  test('聊天提示詞依語言使用完整預設，自訂內容不隨語言改寫', () {
    final zhChat = resolveChatDiaryPrompt(
      ChatDiaryPromptPurpose.conversation,
      AppLanguage.zh,
      const AiPromptOverrides(),
    );
    final enChat = resolveChatDiaryPrompt(
      ChatDiaryPromptPurpose.conversation,
      AppLanguage.en,
      const AiPromptOverrides(),
    );
    final zhDiary = resolveChatDiaryPrompt(
      ChatDiaryPromptPurpose.generation,
      AppLanguage.zh,
      const AiPromptOverrides(),
    );
    final enDiary = resolveChatDiaryPrompt(
      ChatDiaryPromptPurpose.generation,
      AppLanguage.en,
      const AiPromptOverrides(),
    );
    expect(zhChat, contains('預設使用繁體中文、台灣常用詞與自然標點'));
    expect(
      enChat,
      contains('By default use natural English and ordinary punctuation'),
    );
    expect(zhDiary, contains('預設使用繁體中文與台灣自然語法'));
    expect(
      enDiary,
      contains(
        'By default use natural English. Switch only when the user explicitly specifies the language for this entry.',
      ),
    );
    expect(enChat, isNot(contains('【')));
    expect(enDiary, isNot(contains('【')));

    const custom = AiPromptOverrides(
      conversationOverride: '自訂聊天',
      generationOverride: 'Custom diary',
    );
    for (final language in AppLanguage.values) {
      expect(
        resolveChatDiaryPrompt(
          ChatDiaryPromptPurpose.conversation,
          language,
          custom,
        ),
        '自訂聊天',
      );
      expect(
        resolveChatDiaryPrompt(
          ChatDiaryPromptPurpose.generation,
          language,
          custom,
        ),
        'Custom diary',
      );
    }
    const generationOnly = AiPromptOverrides(generationOverride: '自訂日記');
    expect(
      resolveChatDiaryPrompt(
        ChatDiaryPromptPurpose.conversation,
        AppLanguage.en,
        generationOnly,
      ),
      contains('natural English'),
    );
    expect(
      resolveChatDiaryPrompt(
        ChatDiaryPromptPurpose.generation,
        AppLanguage.en,
        generationOnly,
      ),
      '自訂日記',
    );
  });

  test('整理提示詞依語言使用內建，自訂內容不隨語言改寫', () {
    final zhChat = resolveDiaryOrganizationPrompt(
      generate: false,
      language: AppLanguage.zh,
      settings: const AiPromptOverrides(),
    );
    final enChat = resolveDiaryOrganizationPrompt(
      generate: false,
      language: AppLanguage.en,
      settings: const AiPromptOverrides(),
    );
    final zhDraft = resolveDiaryOrganizationPrompt(
      generate: true,
      language: AppLanguage.zh,
      settings: const AiPromptOverrides(),
    );
    final enDraft = resolveDiaryOrganizationPrompt(
      generate: true,
      language: AppLanguage.en,
      settings: const AiPromptOverrides(),
    );
    expect(zhChat, contains('日記整理夥伴'));
    expect(zhChat, contains('同一個 ⟦P…⟧ 代號代表同一位人物'));
    expect(enChat, contains("Quill Diary's diary organization companion"));
    expect(enChat, contains('The same ⟦P…⟧ token means the same person'));
    expect(zhDraft, contains('只輸出一個有效的 JSON 物件'));
    expect(zhDraft, contains('同一個 ⟦P…⟧ 代號代表同一位人物'));
    expect(enDraft, contains('Output only one valid JSON object'));
    expect(enDraft, contains('The same ⟦P…⟧ token means the same person'));
    expect(zhChat, isNot(contains('diary organization companion')));
    expect(enDraft, isNot(contains('只輸出')));

    const custom = AiPromptOverrides(
      conversationOverride: '自訂需求',
      generationOverride: 'Custom draft',
    );
    for (final language in AppLanguage.values) {
      expect(
        resolveDiaryOrganizationPrompt(
          generate: false,
          language: language,
          settings: custom,
        ),
        '自訂需求',
      );
      expect(
        resolveDiaryOrganizationPrompt(
          generate: true,
          language: language,
          settings: custom,
        ),
        'Custom draft',
      );
    }
    const generationOnly = AiPromptOverrides(generationOverride: '只改生成');
    expect(
      resolveDiaryOrganizationPrompt(
        generate: false,
        language: AppLanguage.en,
        settings: generationOnly,
      ),
      contains("Quill Diary's diary organization companion"),
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
