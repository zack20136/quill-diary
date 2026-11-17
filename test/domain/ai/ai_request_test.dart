import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/ai_request.dart';
import 'package:quill_diary/domain/ai/privacy_text_processor.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_privacy_processor.dart';

import '../../helpers/ai/ai_test_helpers.dart';

void main() {
  final connection = testChatDiarySession().connectionConfig;

  test('外送代號與本機相同，串流切開括號仍保留指代', () async {
    final originals = {'{{PER_0A}}': '小明', '{{PRI_01}}': '手動片段'};
    final request = await prepareAiRequest(
      connection: connection,
      instructions: '規則',
      messages: const [
        AiInputMessage(
          isUser: true,
          text: '{{PER_0A}} {{PRI_01}} a+b@example.org',
        ),
      ],
      originals: originals,
    );
    const person = '{{PER_0A}}';
    const manual = '{{PRI_01}}';
    const automatic = '{{PRI_02}}';
    expect(request.messages.single.text, '$person $manual $automatic');
    final reply = '$person $automatic';
    expect(
      await request
          .decode(
            Stream.fromIterable([
              for (var i = 0; i < reply.length; i += 3)
                reply.substring(
                  i,
                  i + 3 > reply.length ? reply.length : i + 3,
                ),
            ]),
          )
          .join(),
      '$person $automatic',
    );
  });

  test('手動與自動命中同一電話時，只有真正手動圈選的原文取得補記資格', () {
    final originals = <String, String>{};
    final result = PrivacyTextProcessor(originals)
        .protect('電話0912345678', manualRanges: const [PrivateTextRange(2, 6)]);
    expect(result.text, isNot(contains('0912345678')));
    expect(result.manualTokens.map((token) => originals[token]), ['0912']);
    expect(result.automaticTokens.map((token) => originals[token]), ['345678']);
  });

  test('自動隱藏只還原模型引用，手動隱藏仍保留私密補記', () async {
    final chat = testChatDiarySession();
    final privacy = ChatDiaryPrivacyProcessor(chat, []);
    final hidden = privacy.protect('電話0912345678');
    final manual = privacy.protect('手動秘密', const [PrivateTextRange(0, 4)]);
    final request = await prepareAiRequest(
      connection: connection,
      instructions: '',
      messages: [AiInputMessage(isUser: true, text: '$hidden $manual')],
      originals: chat.originalTextByToken,
    );
    privacy.registerRestoreTokensFromRequest(request.automaticTokenIds);
    final reply = await request
        .decode(Stream.value('# 標題\n\n電話 {{PRI_01}}'))
        .join();
    expect(
      privacy.restoreDiary(reply, '補記').markdownBody,
      '電話 0912345678\n\n## 補記\n\n手動秘密',
    );
    expect(
      privacy.restoreDiary('# 標題\n\n公開', '補記').markdownBody,
      isNot(contains('0912345678')),
    );
  });

  test('字面代號不會誤認為人物而還原原文', () async {
    final request = await prepareAiRequest(
      connection: connection,
      instructions: '',
      messages: const [
        AiInputMessage(isUser: true, text: '產品 {{人物_01}} 與 {{PER_01}}'),
      ],
      originals: {'{{PER_01}}': '小明'},
    );
    expect(request.messages.single.text, '產品 {{PRI_01}} 與 {{PER_01}}');
    expect(
      await request.decode(Stream.value('產品 {{PRI_01}}')).join(),
      '產品 {{人物_01}}',
    );
  });

  test('使用者原文中的字面代號不會被還原成人物', () async {
    final request = await prepareAiRequest(
      connection: connection,
      instructions: '',
      messages: const [AiInputMessage(isUser: true, text: '他寫了 {{PER_01}}')],
      originals: {'{{PER_02}}': '小明'},
    );
    final sent = request.messages.single.text;
    expect(sent, '他寫了 {{PRI_01}}');
    final restored = await request.decode(Stream.value(sent)).join();
    expect(restored, '他寫了 {{PER_01}}');
    expect(
      restorePrivacyText(restored, {'{{PER_02}}': '小明'}).text,
      isNot(contains('小明')),
    );
  });

  test('代號被逐字切開時仍完整保留，未閉合的大括號在結束時輸出', () async {
    const token = '{{PER_01}}';
    final request = await prepareAiRequest(
      connection: connection,
      instructions: '',
      messages: const [AiInputMessage(isUser: true, text: token)],
      originals: {token: '小明'},
    );
    expect(
      await request.decode(Stream.fromIterable(token.split(''))).toList(),
      [token],
    );
    expect(await request.decode(Stream.value('結尾 {{')).join(), '結尾 {{');
  });

  test('JSON 的單個大括號不會等代號結束才輸出', () async {
    final request = await prepareAiRequest(
      connection: connection,
      instructions: '',
      messages: const [AiInputMessage(isUser: true, text: '公開 {{PER_01}}')],
      originals: {'{{PER_01}}': '小明'},
    );
    expect(
      await request
          .decode(
            Stream.fromIterable([
              '{"a":',
              '{',
              '"b":1}',
              '{{',
              'nope}} {{PER_01}}',
            ]),
          )
          .toList(),
      ['{"a":', '{"b":1}', '{{nope}} {{PER_01}}'],
    );
  });

  test('未知代號不觸發還原，也不在共用傳輸層拒收整則回覆', () async {
    final originals = {'{{PER_01}}': '其他人物'};
    final request = await prepareAiRequest(
      connection: connection,
      instructions: '',
      messages: const [AiInputMessage(isUser: true, text: '公開內容')],
      originals: originals,
    );
    final output = await request.decode(Stream.value('說明 {{PER_01}}')).join();
    expect(output, isNot(contains('其他人物')));
    expect(restorePrivacyText(output, originals).text, output);
  });

  test('直接輸入其他分支的本機代號不會取得該分支原文的還原資格', () async {
    final chat = testChatDiarySession()
      ..originalTextByToken.addAll({
        '{{PER_01}}': '別人的姓名',
        '{{PRI_01}}': '另一分支的秘密',
      })
      ..tokenBySourceKey['person:other'] = '{{PER_01}}';
    final privacy = ChatDiaryPrivacyProcessor(chat, [], messages: []);
    final request = await prepareAiRequest(
      connection: connection,
      instructions: '',
      messages: [
        AiInputMessage(
          isUser: true,
          text: privacy.protect('{{PER_01}} {{PRI_01}}'),
        ),
      ],
      originals: chat.originalTextByToken,
    );
    privacy.registerRestoreTokensFromRequest(request.automaticTokenIds);
    final reply = await request
        .decode(Stream.value('{{PER_01}} {{PRI_01}}'))
        .join();
    expect(privacy.restore(reply), '{{PER_01}} {{PRI_01}}');
  });

  test('長材料可在背景掃描，不改寫原始輸入', () async {
    final text = '${'合成文字 ' * 4000}0912345678';
    final input = AiInputMessage(isUser: true, text: text);
    final request = await prepareAiRequest(
      background: true,
      connection: connection,
      instructions: '',
      messages: [input],
      originals: {},
    );
    expect(request.messages.single.text, isNot(contains('0912345678')));
    expect(input.text, text);
  });

  test('已取消的 email 在第二次掃描仍保持明文', () async {
    const email = 'a+b@example.org';
    final request = await prepareAiRequest(
      connection: connection,
      instructions: '',
      messages: const [AiInputMessage(isUser: true, text: '信箱 $email')],
      originals: {},
      revealedSecrets: {email},
    );
    expect(request.messages.single.text, contains(email));
  });
}
