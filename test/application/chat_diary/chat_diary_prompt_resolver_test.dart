import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_prompt_resolver.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_settings.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';

void main() {
  test('繁中與英文取得各自完整預設且語言指示分開', () {
    final zhChat = resolveChatDiaryPrompt(
      ChatDiaryPromptPurpose.conversation,
      AppLanguage.zh,
      const ChatDiaryPromptSettings(),
    );
    final enChat = resolveChatDiaryPrompt(
      ChatDiaryPromptPurpose.conversation,
      AppLanguage.en,
      const ChatDiaryPromptSettings(),
    );
    final zhDiary = resolveChatDiaryPrompt(
      ChatDiaryPromptPurpose.generation,
      AppLanguage.zh,
      const ChatDiaryPromptSettings(),
    );
    final enDiary = resolveChatDiaryPrompt(
      ChatDiaryPromptPurpose.generation,
      AppLanguage.en,
      const ChatDiaryPromptSettings(),
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
  });
  test('自訂提示詞在切換語言後不加隱藏指示或被翻譯', () {
    const settings = ChatDiaryPromptSettings(
      conversationOverride: '自訂聊天',
      generationOverride: 'Custom diary',
    );
    for (final language in AppLanguage.values) {
      expect(
        resolveChatDiaryPrompt(
          ChatDiaryPromptPurpose.conversation,
          language,
          settings,
        ),
        '自訂聊天',
      );
      expect(
        resolveChatDiaryPrompt(
          ChatDiaryPromptPurpose.generation,
          language,
          settings,
        ),
        'Custom diary',
      );
    }
  });
  test('獨立還原只影響該用途', () {
    const settings = ChatDiaryPromptSettings(generationOverride: '自訂日記');
    expect(
      resolveChatDiaryPrompt(
        ChatDiaryPromptPurpose.conversation,
        AppLanguage.en,
        settings,
      ),
      contains('natural English'),
    );
    expect(
      resolveChatDiaryPrompt(
        ChatDiaryPromptPurpose.generation,
        AppLanguage.en,
        settings,
      ),
      '自訂日記',
    );
  });
}
