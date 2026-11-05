import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';

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
    chat.editBackup = AiComposerSnapshot(
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

  test('舊聊天還原時，姓名的前綴若接在後面仍對回整段姓名', () {
    final chat = testChatDiarySession()
      ..originalTextByToken['⟦P01⟧'] = '明明'
      ..tokenBySourceKey['person:person-1'] = '⟦P01⟧';
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: '明明明',
        outboundText: '⟦P01⟧明',
      ),
    );
    final restored = ChatDiarySession.fromJson(
      jsonDecode(jsonEncode(chat.toJson())),
    );
    expect(
      restored.messages.single.personRanges!.map(
        (range) => (range.start, range.end, range.personId),
      ),
      [(0, 2, 'person-1')],
    );
  });

  test('舊聊天還原緊貼私密片段的人物別名', () {
    final chat = testChatDiarySession()
      ..originalTextByToken.addAll({'⟦P01⟧': '王小明', '⟦S01⟧': '秘密'})
      ..tokenBySourceKey.addAll({
        'person:person-1': '⟦P01⟧',
        'private:秘密': '⟦S01⟧',
      });
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: '小明秘密來了',
        outboundText: '⟦P01⟧⟦S01⟧來了',
        privateRanges: const [PrivateTextRange(2, 4)],
      ),
    );
    final restored = ChatDiarySession.fromJson(
      jsonDecode(jsonEncode(chat.toJson())),
    );
    expect(
      restored.messages.single.personRanges!.map(
        (range) => (range.start, range.end, range.personId),
      ),
      [(0, 2, 'person-1')],
    );
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

  test('沒有的父訊息、錯誤、連線與生成欄位不寫入', () {
    final chat = testChatDiarySession();
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: '你好',
        outboundText: '你好',
      ),
    );
    final json = chat.toJson();
    for (final key in [
      'generation_connection',
      'generated_entry_id',
      'generated_from_message_id',
      'generated_draft_signature',
      'editing_message_id',
      'edit_backup',
    ]) {
      expect(json.containsKey(key), isFalse, reason: key);
    }
    final message = (json['messages'] as List).single as Map;
    expect(message.containsKey('parent_id'), isFalse);
    expect(message.containsKey('error_code'), isFalse);
    expect(message.containsKey('connection'), isFalse);
    chat.editBackup = AiComposerSnapshot(
      text: '編輯前',
      ranges: const [],
      imageIds: const [],
    );
    expect(
      (chat.toJson()['edit_backup'] as Map).containsKey('image_ids'),
      isFalse,
    );
    chat.editBackup = AiComposerSnapshot(
      text: '編輯前',
      ranges: const [],
      imageIds: const ['att'],
    );
    expect((chat.toJson()['edit_backup'] as Map)['image_ids'], ['att']);
    final restored = ChatDiarySession.fromJson(
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
    );
    expect(restored.messages.single.parentId, isNull);
    expect(restored.messages.single.errorCode, isNull);
    expect(restored.generationConnectionSnapshot, isNull);
    expect(restored.editBackup, isNull);
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
}
