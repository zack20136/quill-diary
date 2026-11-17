import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/ai_composer_snapshot.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';

import '../../helpers/ai/ai_test_helpers.dart';

void main() {
  test('上線版第一版聊天可讀，缺少歷史 Thinking 對照不推測補建', () {
    final chat = ChatDiarySession.fromJson({
      'schema_version': 1,
      'id': 'chat_01ARZ3NDEKTSV4RRFFQ69G5FAV',
      'vault_id': 'vault',
      'config': {'provider': 'openai', 'default_model': 'gpt-5'},
      'hide_people': true,
      'created_at': '2026-11-03T09:00:00.000',
      'date': '2026-11-03',
      'messages': [
        {
          'id': 'u',
          'is_user': true,
          'text': '小明來了',
          'outbound_text': '{{PER_01}}來了',
          'private_token_ids': ['{{PER_01}}'],
        },
      ],
      'images': [],
      'replacements': {'{{PER_01}}': '小明'},
      'token_keys': {'person:person-1': '{{PER_01}}'},
      'selected_children': {'__root__': 'u'},
    });
    expect(chat.activeMessages.single.text, '小明來了');
    expect(chat.messages.single.personRanges, isEmpty);
    expect(chat.connectionConfig.model, 'gpt-5');
    expect(chat.connectionConfig.hasCompleteRequestSnapshot, isFalse);
    expect(chat.connectionConfig.thinkingOverrides, isEmpty);
    expect(
      ChatDiarySession.fromJson(
        jsonDecode(jsonEncode(chat.toJson())) as Map<String, dynamic>,
      ).originalTextByToken,
      chat.originalTextByToken,
    );
  });

  test('必要隱私參照損壞時拒讀，但字面代號與缺少可選清單仍可讀', () {
    final chat = testChatDiarySession()..composerText = '字面 {{PRI_01}}';
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'u',
        isUser: true,
        text: '字面 {{PRI_01}}',
        outboundText: '字面 {{PRI_01}}',
      ),
    );
    Map<String, dynamic> data() =>
        jsonDecode(jsonEncode(chat.toJson())) as Map<String, dynamic>;
    final optional = data();
    (optional['messages'] as List).single.remove('private_token_ids');
    expect(
      ChatDiarySession.fromJson(optional).messages.single.privateTokenIds,
      isEmpty,
    );
    final badMessage = data();
    (badMessage['messages'] as List).single['private_token_ids'] = ['{{PRI_01}}'];
    expect(() => ChatDiarySession.fromJson(badMessage), throwsFormatException);
    final badKey = data()..['token_keys'] = {'private:字面': '{{PRI_01}}'};
    expect(() => ChatDiarySession.fromJson(badKey), throwsFormatException);
  });

  for (final area in [
    'private_ranges',
    'automatic_ranges',
    'person_ranges',
    'composer_ranges',
    'edit_backup',
  ]) {
    test('$area 的保存區間超界時拒讀，不裁切', () {
      final chat = testChatDiarySession()..composerText = '文字';
      chat.appendMessage(
        ChatDiaryMessage(id: 'u', isUser: true, text: '文字', outboundText: '文字'),
      );
      final data =
          jsonDecode(jsonEncode(chat.toJson())) as Map<String, dynamic>;
      final range = {'start': 0, 'end': 99};
      if (area == 'composer_ranges') {
        data[area] = [range];
      } else if (area == 'edit_backup') {
        data[area] = {
          'text': '文字',
          'ranges': [range],
        };
      } else {
        (data['messages'] as List).single[area] = [
          {...range, if (area == 'person_ranges') 'person_id': 'person'},
        ];
      }
      expect(() => ChatDiarySession.fromJson(data), throwsFormatException);
    });
  }

  test('缺少人物區間時使用空清單，不從姓名與外送代號推測重建', () {
    final chat = testChatDiarySession()
      ..originalTextByToken['{{PER_01}}'] = '小明'
      ..tokenBySourceKey['person:person-1'] = '{{PER_01}}';
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: '小明來了',
        outboundText: '{{PER_01}}來了',
      ),
    );
    final restored = ChatDiarySession.fromJson(
      jsonDecode(jsonEncode(chat.toJson())) as Map<String, dynamic>,
    );
    expect(restored.messages.single.personRanges, isEmpty);
    expect(restored.messages.single.outboundText, '{{PER_01}}來了');
  });

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
    for (final version in <Object?>[null, 0, 2, 3, '1']) {
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

  test('不接受路徑作為聊天識別', () {
    expect(
      () => ChatDiarySession.draftKeyFor('../private'),
      throwsFormatException,
    );
  });
}
