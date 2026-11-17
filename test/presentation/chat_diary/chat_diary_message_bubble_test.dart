import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_message_bubble.dart';
import 'package:quill_diary/shared/presentation/widgets/private_text.dart';

import '../../helpers/ai/ai_test_helpers.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('AI 串流、完成聊天重載及版本切換皆高亮實際還原內容，複製保留原文', (tester) async {
    var chat = testChatDiarySession()
      ..originalTextByToken.addAll({'{{PER_01}}': 'QA小明', '{{PRI_01}}': '秘密'});
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: 'QA小明的秘密',
        outboundText: '{{PER_01}}的{{PRI_01}}',
      ),
    );
    final reply = ChatDiaryMessage(
      id: 'reply',
      parentId: 'user',
      isUser: false,
      text: '收到{{PER',
      outboundText: '收到{{PER',
      status: ChatDiaryMessageStatus.pending,
    );
    chat.appendMessage(reply);
    Future<void> pump() async {
      final message = chat.activeMessages.last;
      await tester.pumpWidget(
        widgetTestApp(
          overrides: [],
          child: SingleChildScrollView(
            child: ChatDiaryMessageBubble(
              chatSession: chat,
              message: message,
              versions: chat.messageVersions[(message.parentId, false)]!,
              isBusy: message.status == ChatDiaryMessageStatus.pending,
              imageBuilder: (_) => const SizedBox(),
              onSelectVersion: (_) {},
              onEditMessage: (_) {},
              onRegenerateReply: (_) {},
            ),
          ),
        ),
      );
    }

    List<String> highlights() => tester
        .widgetList<PrivateText>(find.byType(PrivateText))
        .expand(
          (text) => text.ranges.map(
            (range) => text.text.substring(range.start, range.end),
          ),
        )
        .toList();
    await pump();
    expect(highlights(), isEmpty);
    reply
      ..outboundText = '收到**{{PER_01}}**的{{PRI'
      ..text = '收到**QA小明**的{{PRI';
    await pump();
    expect(highlights(), ['QA小明']);
    reply
      ..outboundText = '收到**{{PER_01}}**的`{{PRI_01}}`'
      ..text = '收到**QA小明**的`秘密`'
      ..status = ChatDiaryMessageStatus.complete;
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'alternative',
        parentId: 'user',
        isUser: false,
        text: 'QA小明，另一版**秘密**',
        outboundText: 'QA小明，另一版**{{PRI_01}}**',
      ),
    );
    chat.finished = true;
    chat = ChatDiarySession.fromJson(chat.toJson());
    await pump();
    expect(highlights(), ['秘密']);
    chat.selectMessage('reply');
    await pump();
    expect(highlights(), ['QA小明', '秘密']);
    expect(find.byTooltip('重新回覆'), findsNothing);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(find.byIcon(Icons.content_copy_outlined));
    await tester.pump();
    expect(copied, '收到**QA小明**的`秘密`');
    expect(chat.activeMessages.last.outboundText, '收到**{{PER_01}}**的`{{PRI_01}}`');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('使用者訊息只高亮已保存的自動區間，不在呈現時重新辨識', (tester) async {
    Future<void> pump(List<PrivateTextRange> automaticRanges) async {
      final chat = testChatDiarySession();
      final message = ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: '電話 0912345678',
        outboundText: '電話 0912345678',
        automaticRanges: automaticRanges,
      );
      chat.appendMessage(message);
      await tester.pumpWidget(
        widgetTestApp(
          overrides: [],
          child: ChatDiaryMessageBubble(
            chatSession: chat,
            message: message,
            versions: [message],
            isBusy: false,
            imageBuilder: (_) => const SizedBox(),
            onSelectVersion: (_) {},
            onEditMessage: (_) {},
            onRegenerateReply: null,
          ),
        ),
      );
    }

    List<String> highlights() => tester
        .widgetList<PrivateText>(find.byType(PrivateText))
        .expand(
          (text) => text.ranges.map(
            (range) => text.text.substring(range.start, range.end),
          ),
        )
        .toList();

    await pump(const []);
    expect(highlights(), isEmpty);
    await pump(const [PrivateTextRange(3, 13)]);
    expect(highlights(), ['0912345678']);
  });
}
