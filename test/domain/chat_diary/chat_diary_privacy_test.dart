import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
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

  test('取消的 email 保持明文，草稿會記住這段區間', () {
    const email = 'a+b@example.org';
    const text = '信箱 $email';
    final start = text.indexOf(email);
    final revealed = [PrivateTextRange(start, start + email.length)];
    final chat = testChatDiarySession();
    final privacy = ChatDiaryPrivacyProcessor(chat, const []);
    expect(
      privacy.protect(text, const [], true, null, const [], revealed),
      text,
    );
    expect(privacy.revealedSecrets, {email});
    chat.composerText = text;
    chat.composerRevealed = revealed;
    final saved = ChatDiarySession.fromJson(chat.toJson());
    expect(
      saved.composerRevealed.map((range) => (range.start, range.end)),
      [(start, start + email.length)],
    );
  });

  test('人物姓名與別名共用穩定代號並可還原', () {
    final chat = testChatDiarySession();
    final privacy = ChatDiaryPrivacyProcessor(chat, [person()]);
    final first = privacy.protect('王小明來了');
    expect(
      privacy.lastRequestPersonRanges.map(
        (range) => (range.start, range.end, range.personId),
      ),
      [(0, 3, 'person-1')],
    );
    final second = privacy.protect('和小明聊天');
    expect(
      privacy.lastRequestPersonRanges.map(
        (range) => (range.start, range.end, range.personId),
      ),
      [(1, 3, 'person-1')],
    );
    expect(first, '{{PER_01}}來了');
    expect(second, isNot(contains('小明')));
    expect(chat.originalTextByToken, hasLength(1));
    expect(privacy.restore(first), '王小明來了');
    expect(privacy.protect(first), first);
  });
  test('同名歧義保存為自動區間，重載重建外送時不猜測人物也不遺失遮蔽', () {
    final people = [
      person(),
      Person(
        id: 'person-2',
        name: '另一人',
        aliases: ['小明'],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ];
    final chat = testChatDiarySession();
    final privacy = ChatDiaryPrivacyProcessor(chat, people);
    final protected = privacy.protect('看到小明');
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: '看到小明',
        outboundText: protected,
        personRanges: privacy.lastRequestPersonRanges,
        automaticRanges: privacy.lastRequestAutomaticRanges,
      ),
    );
    final saved = ChatDiarySession.fromJson(chat.toJson());
    final message = saved.messages.single;
    final next = ChatDiaryPrivacyProcessor(saved, people);
    final rebuilt = next.protect(
      message.text,
      message.privateRanges,
      true,
      message.personRanges,
      message.automaticRanges,
    );
    expect(rebuilt, '看到{{PRI_01}}');
    expect(message.personRanges, isEmpty);
    expect(next.restoreDiary('# 紀錄\n\n公開文字', '補記').markdownBody, '公開文字');
  });
  test('已指定的人物區間不再重掃名冊', () {
    final chat = testChatDiarySession();
    final privacy = ChatDiaryPrivacyProcessor(chat, [person()]);
    expect(privacy.protect('小明後來才加', const [], true, const []), '小明後來才加');
    expect(
      privacy.protect('看到小明', const [], true, const [
        PersonTextRange(2, 4, 'person-1'),
      ]),
      '看到{{PER_01}}',
    );
  });
  test('人物與私密片段各自短序號，重新載入後沿用同一對照', () {
    final chat = testChatDiarySession();
    final privacy = ChatDiaryPrivacyProcessor(chat, [person()]);
    expect(privacy.protect('王小明'), '{{PER_01}}');
    expect(privacy.protect('秘密', [const PrivateTextRange(0, 2)]), '{{PRI_01}}');
    final restored = ChatDiarySession.fromJson(chat.toJson());
    final next = ChatDiaryPrivacyProcessor(restored, [person()]);
    final preview = ChatDiaryPrivacyProcessor(restored, [person()]);
    expect(next.protect('小明'), '{{PER_01}}');
    expect(next.protect('另一段', [const PrivateTextRange(0, 3)]), '{{PRI_02}}');
    expect(preview.protect('新片段', [const PrivateTextRange(0, 3)]), '{{PRI_03}}');
  });

  test('關閉人物隱藏仍保護手動選取的片段', () {
    final chat = testChatDiarySession(hidePersonNames: false);
    final privacy = ChatDiaryPrivacyProcessor(chat, [person()]);
    final result = privacy.protect('王小明住在秘密地址', [const PrivateTextRange(5, 9)]);
    expect(result, contains('王小明'));
    expect(result, isNot(contains('秘密地址')));
    expect(privacy.restore(result), '王小明住在秘密地址');
  });
  test('手動圈選只影響標記區間，格式明確的個資另外自動隱藏', () {
    final chat = testChatDiarySession();
    final privacy = ChatDiaryPrivacyProcessor(chat, []);
    final result = privacy.protect('秘密 秘密 0912345678', [
      const PrivateTextRange(0, 2),
    ]);
    expect(result, '{{PRI_01}} 秘密 {{PRI_02}}');
    expect(privacy.protect('再次提到秘密'), '再次提到秘密');
    expect(
      privacy.protect('再次提到秘密', [const PrivateTextRange(4, 6)]),
      '再次提到{{PRI_01}}',
    );
    expect(privacy.protectPrompt('提示裡的秘密'), '提示裡的{{PRI_01}}');
    expect(privacy.protect(result), result);
  });
  test('完整私密句優先於其中的人物比對', () {
    final chat = testChatDiarySession();
    final privacy = ChatDiaryPrivacyProcessor(chat, [person()]);
    final text = '王小明的祕密';
    final result = privacy.protect(text, [PrivateTextRange(0, text.length)]);
    expect(chat.originalTextByToken, hasLength(1));
    expect(privacy.restore(result), text);
  });
  test('生成未引用的私密片段加到補記而已引用者不重複', () {
    final chat = testChatDiarySession();
    final privacy = ChatDiaryPrivacyProcessor(chat, []);
    final a = privacy.protect('第一段私密', [const PrivateTextRange(0, 5)]);
    privacy.protect('第二段私密', [const PrivateTextRange(0, 5)]);
    final result = privacy.restoreDiary('# 回憶\n\n$a', '私密補記');
    expect(result.title, '回憶');
    expect(result.markdownBody, '第一段私密\n\n## 私密補記\n\n第二段私密');
  });
  test('處理公開文字不會把其他分支的人物與自動隱藏對照帶入還原範圍', () {
    final chat = testChatDiarySession();
    final previous = ChatDiaryPrivacyProcessor(chat, [person()]);
    final protected = previous.protect('王小明 0912345678');
    final current = ChatDiaryPrivacyProcessor(chat, [person()], messages: []);
    current.protect('公開文字');
    expect(current.restore(protected), protected);
  });
  test('其他分支的代號不還原或補入目前日記', () {
    final chat = testChatDiarySession();
    final old = ChatDiaryPrivacyProcessor(chat, []);
    final token = old.protect('另一條路徑的秘密', [const PrivateTextRange(0, 8)]);
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
    expect(privacy.protect('|內容| {{一般文字}} {{PER_AA}}'), '|內容| {{一般文字}} {{PER_AA}}');
  });
}
