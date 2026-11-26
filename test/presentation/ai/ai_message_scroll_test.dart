import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/presentation/ai/ai_message_scroll.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('短列表按 Page Up 後保留閱讀位置，回到最新訊息後繼續跟隨', (tester) async {
    final focus = FocusNode();
    final reply = StreamController<List<String>>();
    addTearDown(focus.dispose);
    addTearDown(() => unawaited(reply.close()));

    await tester.pumpWidget(
      widgetTestApp(
        child: SizedBox(
          width: 280,
          height: 220,
          child: AiMessageScroll(
            builder: (controller) => SingleChildScrollView(
              controller: controller,
              child: Focus(
                focusNode: focus,
                child: StreamBuilder<List<String>>(
                  stream: reply.stream,
                  builder: (context, snapshot) => Column(
                    children: [
                      const SizedBox(height: 268, child: Text('已有訊息')),
                      for (final chunk in snapshot.data ?? const <String>[])
                        SizedBox(height: 160, child: Text(chunk)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final position = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!
        .position;
    final shortExtent = position.maxScrollExtent;
    expect(shortExtent - position.minScrollExtent, inExclusiveRange(0, 80));
    expect(position.pixels, shortExtent);

    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();
    final readingOffset = position.pixels;
    expect(readingOffset, position.minScrollExtent);

    final latest = find.byTooltip(testL10n.chatDiaryJumpLatest);
    expect(latest, findsOneWidget);
    reply.add(['第一段串流回覆']);
    await tester.pumpAndSettle();
    expect(position.maxScrollExtent, greaterThan(shortExtent));
    expect(position.pixels, readingOffset);

    await tester.tap(latest);
    await tester.pumpAndSettle();
    expect(latest, findsNothing);
    expect(position.extentAfter, 0);

    final previousExtent = position.maxScrollExtent;
    reply.add(['第一段串流回覆', '第二段串流回覆']);
    await tester.pumpAndSettle();
    expect(position.maxScrollExtent, greaterThan(previousExtent));
    expect(position.extentAfter, 0);
  });
}
