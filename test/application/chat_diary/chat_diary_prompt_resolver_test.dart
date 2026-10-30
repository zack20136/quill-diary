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
    expect(zhChat, contains('除非使用者明確要求其他回覆語言'));
    expect(
      enChat,
      contains('Unless the user explicitly requests another response language'),
    );
    expect(zhDiary, contains('除非使用者明確指定這篇日記'));
    expect(
      enDiary,
      contains(
        'Unless the user explicitly requests another language for this diary',
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
