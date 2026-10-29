import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_privacy_processor.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/people/person.dart';

import '../../helpers/ai/ai_test_helpers.dart';

void main() {
  Person person() => Person(
    id: 'person-1',
    name: '王小明',
    aliases: ['小明'],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('人物姓名與別名共用穩定代號並可還原', () {
    final chat = testChatDiarySession();
    final privacy = ChatDiaryPrivacyProcessor(chat, [person()]);
    final first = privacy.protect('王小明來了');
    final second = privacy.protect('和小明聊天');
    expect(first, '⟦P01⟧來了');
    expect(second, isNot(contains('小明')));
    expect(chat.originalTextByToken, hasLength(1));
    expect(privacy.restore(first), '王小明來了');
    expect(privacy.protect(first), first);
  });
  test('人物與私密片段共用短序號，重新載入後沿用同一對照', () {
    final chat = testChatDiarySession();
    final privacy = ChatDiaryPrivacyProcessor(chat, [person()]);
    expect(privacy.protect('王小明'), '⟦P01⟧');
    expect(privacy.protect('秘密', [const ChatDiaryPrivateRange(0, 2)]), '⟦S02⟧');
    final restored = ChatDiarySession.fromJson(chat.toJson());
    final next = ChatDiaryPrivacyProcessor(restored, [person()]);
    final preview = ChatDiaryPrivacyProcessor(restored, [person()]);
    expect(next.protect('小明'), '⟦P01⟧');
    expect(next.protect('另一段', [const ChatDiaryPrivateRange(0, 3)]), '⟦S03⟧');
    expect(
      preview.protect('新片段', [const ChatDiaryPrivateRange(0, 3)]),
      '⟦S04⟧',
    );
  });

  test('短序號超過 FF 自動延長，對照表有缺號時仍由最大值繼續', () {
    final chat = testChatDiarySession();
    final privacy = ChatDiaryPrivacyProcessor(chat, []);
    var last = '';
    for (var i = 1; i <= 255; i++) {
      final text = '私密片段$i';
      last = privacy.protect(text, [ChatDiaryPrivateRange(0, text.length)]);
    }
    expect(last, '⟦SFF⟧');
    chat.originalTextByToken.remove('⟦S02⟧');
    chat.tokenBySourceKey.remove('private:私密片段2');
    final next = ChatDiaryPrivacyProcessor(chat, []);
    expect(next.protect('延長', [const ChatDiaryPrivateRange(0, 2)]), '⟦S100⟧');
    expect(next.protect('繼續', [const ChatDiaryPrivateRange(0, 2)]), '⟦S101⟧');
  });

  test('關閉人物隱藏仍保護手動選取的片段', () {
    final chat = testChatDiarySession(hidePersonNames: false);
    final privacy = ChatDiaryPrivacyProcessor(chat, [person()]);
    final result = privacy.protect('王小明住在秘密地址', [
      const ChatDiaryPrivateRange(5, 9),
    ]);
    expect(result, contains('王小明'));
    expect(result, isNot(contains('秘密地址')));
    expect(privacy.restore(result), '王小明住在秘密地址');
  });
  test('反白只替換標記區間，未標記的相同原文保持原樣', () {
    final chat = testChatDiarySession();
    final privacy = ChatDiaryPrivacyProcessor(chat, []);
    final result = privacy.protect('秘密 秘密 0912345678', [
      const ChatDiaryPrivateRange(0, 2),
    ]);
    expect(result, '⟦S01⟧ 秘密 0912345678');
    expect(privacy.protect('再次提到秘密'), '再次提到秘密');
    expect(
      privacy.protect('再次提到秘密', [const ChatDiaryPrivateRange(4, 6)]),
      '再次提到⟦S01⟧',
    );
    expect(privacy.protectPrompt('提示裡的秘密'), '提示裡的⟦S01⟧');
    expect(privacy.protect(result), result);
  });
  test('完整私密句優先於其中的人物比對', () {
    final chat = testChatDiarySession();
    final privacy = ChatDiaryPrivacyProcessor(chat, [person()]);
    final text = '王小明的祕密';
    final result = privacy.protect(text, [
      ChatDiaryPrivateRange(0, text.length),
    ]);
    expect(chat.originalTextByToken, hasLength(1));
    expect(privacy.restore(result), text);
  });
  test('生成未引用的私密片段加到補記而已引用者不重複', () {
    final chat = testChatDiarySession();
    final privacy = ChatDiaryPrivacyProcessor(chat, []);
    final a = privacy.protect('第一段私密', [const ChatDiaryPrivateRange(0, 5)]);
    privacy.protect('第二段私密', [const ChatDiaryPrivateRange(0, 5)]);
    final result = privacy.restoreDiary('# 回憶\n\n$a', '私密補記');
    expect(result.title, '回憶');
    expect(result.markdownBody, '第一段私密\n\n## 私密補記\n\n第二段私密');
  });
  test('其他分支的代號不還原或補入目前日記', () {
    final chat = testChatDiarySession();
    final old = ChatDiaryPrivacyProcessor(chat, []);
    final token = old.protect('另一條路徑的秘密', [const ChatDiaryPrivateRange(0, 8)]);
    final current = ChatDiaryPrivacyProcessor(chat, [], messages: []);
    expect(current.restore(token), token);
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: '公開文字',
        outboundText: '公開文字',
      ),
    );
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'assistant',
        isUser: false,
        parentId: 'user',
        text: token,
        outboundText: token,
      ),
    );
    expect(ChatDiaryPrivacyProcessor(chat, []).restore(token), token);
    expect(current.restoreDiary('# 標題\n\n公開記錄', '私密補記').markdownBody, '公開記錄');
  });
  test('一般符號不被解讀成私密語法', () {
    final privacy = ChatDiaryPrivacyProcessor(testChatDiarySession(), []);
    expect(privacy.protect('|內容| {{一般文字}} ⟦PAA⟧'), '|內容| {{一般文字}} ⟦PAA⟧');
  });
  test('插入刪除與取代保持私密區間', () {
    var ranges = [const ChatDiaryPrivateRange(2, 4)];
    ranges = updatePrivateRanges('前言秘密結尾', '新前言秘密結尾', ranges);
    expect(ranges.single.start, 3);
    expect(ranges.single.end, 5);
    ranges = updatePrivateRanges('新前言秘密結尾', '新前言新秘密結尾', ranges);
    expect(ranges.single.start, 3);
    expect(ranges.single.end, 6);
    ranges = updatePrivateRanges('新前言新秘密結尾', '新前言結尾', ranges);
    expect(ranges, isEmpty);
  });
  test('部分取消隱藏會拆成兩段且重疊標記會合併', () {
    final ranges = mergePrivateRanges([
      const ChatDiaryPrivateRange(0, 4),
      const ChatDiaryPrivateRange(2, 8),
    ], 10);
    final parts = removePrivateRange(ranges, 3, 5);
    expect(parts.map((r) => (r.start, r.end)), [(0, 3), (5, 8)]);
  });
  test('整段貼上取代不會解除原本的保護', () {
    final ranges = updatePrivateRanges('公開秘密文字', '重新貼上的內容', [
      const ChatDiaryPrivateRange(2, 4),
    ]);
    expect(ranges.single.start, 0);
    expect(ranges.single.end, 7);
  });
}
