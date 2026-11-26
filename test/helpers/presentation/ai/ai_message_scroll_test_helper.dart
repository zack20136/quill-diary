import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/presentation/ai/ai_message_scroll.dart';

import '../../shared/test_l10n.dart';

Future<void> expectPageUpKeepsReadingPosition(
  WidgetTester tester,
  StreamController<String> reply,
) async {
  expect(reply.hasListener, isTrue);
  reply.add(List.generate(40, (index) => '回覆第 $index 段。').join('\n\n'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();

  final list = find.descendant(
    of: find.byType(AiMessageScroll),
    matching: find.byType(ListView),
  );
  final position = tester.widget<ListView>(list).controller!.position;
  expect(position.extentAfter, closeTo(0, 1));
  final latestOffset = position.pixels;

  final message = find
      .descendant(of: list, matching: find.byType(SelectableRegion))
      .last;
  final messageFocus = find
      .descendant(
        of: message,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Focus && widget.focusNode?.canRequestFocus == true,
        ),
      )
      .first;
  final focusNode = tester.widget<Focus>(messageFocus).focusNode!;
  focusNode.requestFocus();
  await tester.pump();
  expect(focusNode.hasPrimaryFocus, isTrue);
  await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pump();
  final readingOffset = position.pixels;
  expect(readingOffset, lessThan(latestOffset));

  final oldExtent = position.maxScrollExtent;
  reply.add('\n\n${List.filled(8, '串流繼續補上新的一段。').join('\n\n')}');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();

  expect(position.maxScrollExtent, greaterThan(oldExtent));
  expect(position.pixels, closeTo(readingOffset, 1));
  expect(find.byTooltip(testL10n.chatDiaryJumpLatest), findsOneWidget);
}
