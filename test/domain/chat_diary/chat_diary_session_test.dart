import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_settings.dart';

import '../../helpers/ai/ai_test_helpers.dart';

void main() {
  test('開場白與空白輸入不算草稿，未送出文字、圖片與其他分支的訊息會保留', () {
    final chat = testChatDiarySession()
      ..openingMessage = '今天有什麼想留下來的？'
      ..composerText = '  \n ';
    expect(chat.hasDraftContent, isFalse);
    chat.composerText = '尚未送出的文字';
    expect(chat.hasDraftContent, isTrue);
    chat.composerText = '';
    chat.pendingImageIds.add('image');
    expect(chat.hasDraftContent, isTrue);
    chat.pendingImageIds.clear();
    chat.editBackup = ChatDiaryComposerSnapshot(
      text: '編輯前的輸入',
      ranges: [],
      imageIds: [],
    );
    expect(chat.hasDraftContent, isTrue);
    chat.editBackup = null;
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'sent',
        isUser: true,
        text: '已送出',
        outboundText: '已送出',
      ),
    );
    chat.appendMessage(
      ChatDiaryMessage(id: 'empty', isUser: true, text: '', outboundText: ''),
    );
    expect(chat.activeMessages.single.text, isEmpty);
    expect(chat.hasDraftContent, isTrue);
  });

  test('版本切換恢復各自後續路徑，序列化保留所有分支與選取', () {
    final chat = testChatDiarySession();
    ChatDiaryMessage node(String id, bool user, String? parent) =>
        ChatDiaryMessage(
          id: id,
          isUser: user,
          text: id,
          outboundText: id,
          parentId: parent,
        );
    chat.appendMessage(node('a', true, null));
    chat.appendMessage(node('b', false, 'a'));
    chat.appendMessage(node('c', true, 'b'));
    chat.appendMessage(node('d', false, 'c'));
    chat.appendMessage(node('e', false, 'a'));
    chat.appendMessage(node('f', true, 'e'));
    chat.selectMessage('b');
    expect(chat.activeMessages.map((m) => m.id), ['a', 'b', 'c', 'd']);
    chat.selectMessage('e');
    expect(chat.activeMessages.map((m) => m.id), ['a', 'e', 'f']);
    expect(chat.toJson()['schema_version'], 1);
    final restored = ChatDiarySession.fromJson(
      jsonDecode(jsonEncode(chat.toJson())),
    );
    expect(restored.messages, hasLength(6));
    expect(
      restored.messageVersions[(
        restored.messages[1].parentId,
        restored.messages[1].isUser,
      )],
      hasLength(2),
    );
    restored.selectMessage('b');
    expect(restored.activeMessages.last.id, 'd');
  });

  test('聊天格式拒絕舊開發版本、未知版本與非整數版本', () {
    final data = testChatDiarySession().toJson();
    for (final version in <Object?>[null, 0, 2, '1']) {
      data['schema_version'] = version;
      expect(() => ChatDiarySession.fromJson(data), throwsFormatException);
    }
  });

  test('損壞的父訊息與選取關係不能靜默混入目前路徑', () {
    final chat = testChatDiarySession();
    chat.appendMessage(
      ChatDiaryMessage(id: 'a', isUser: true, text: '', outboundText: ''),
    );
    final data = jsonDecode(jsonEncode(chat.toJson())) as Map<String, dynamic>;
    (data['messages'] as List).first['parent_id'] = 'missing';
    expect(() => ChatDiarySession.fromJson(data), throwsFormatException);
    (data['messages'] as List).first['parent_id'] = null;
    data['selected_children'] = {'__root__': 'missing'};
    expect(() => ChatDiarySession.fromJson(data), throwsFormatException);
  });

  test('自訂非標題格式保留完整內文', () {
    const body = '\n  這是沒有標題的日記。\n';
    final result = ChatDiaryDraft.fromMarkdown(body);
    expect(result.title, isNull);
    expect(result.markdownBody, body);
  });

  test('不接受路徑作為聊天識別', () {
    expect(
      () => ChatDiarySession.draftKeyFor('../private'),
      throwsFormatException,
    );
  });

  test('自訂提示詞覆寫可還原，未設定的維持預設', () {
    final diary = ChatDiarySettings(
      prompts: const ChatDiaryPromptSettings(conversationOverride: '保持原文'),
    );
    final restored = ChatDiarySettings.fromJson(diary.toJson());
    expect(restored.prompts.conversationOverride, '保持原文');
    expect(restored.prompts.generationOverride, isNull);
    expect(restored.hidePersonNames, isTrue);
  });
}
