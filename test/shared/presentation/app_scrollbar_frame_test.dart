import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

import '../../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('外框模式的捲軸上下留白相同，捲到底貼齊下緣', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final text = TextEditingController(
      text: List.generate(80, (index) => '第 $index 行').join('\n'),
    );
    addTearDown(text.dispose);

    await tester.pumpWidget(
      widgetTestApp(
        child: SizedBox(
          width: 300,
          height: 280,
          child: AppScrollbar(
            controller: scroll,
            track: AppScrollbarTrack.frame,
            child: TextField(
              controller: text,
              scrollController: scroll,
              expands: true,
              minLines: null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Rect box = tester.getRect(find.byType(AppScrollbar));
    final thumbFinder = find.byKey(
      const ValueKey<String>('app-scrollbar-thumb'),
    );
    Rect thumb() => tester.getRect(thumbFinder);

    final double topGap = thumb().top - box.top;
    await tester.drag(thumbFinder, const Offset(0, 400));
    await tester.pump();
    expect(scroll.offset, closeTo(scroll.position.maxScrollExtent, 1));
    final double bottomGap = box.bottom - thumb().bottom;

    expect(bottomGap, closeTo(topGap, 0.1));
  });

  testWidgets('dialog 外框文字欄的滑塊貼齊框頂與框底', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final text = TextEditingController(
      text: List.generate(80, (index) => '第 $index 行').join('\n'),
    );
    addTearDown(text.dispose);

    await tester.pumpWidget(
      widgetTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppDialog<void>(
              context: context,
              builder: (_) => AppDialogShell(
                title: '規則',
                content: SizedBox(
                  width: 320,
                  height: 280,
                  child: AppScrollbar(
                    controller: scroll,
                    track: AppScrollbarTrack.frame,
                    reserveGutter: true,
                    child: TextField(
                      controller: text,
                      scrollController: scroll,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();

    final Rect box = tester.getRect(find.byType(AppScrollbar));
    final thumbFinder = find.byKey(
      const ValueKey<String>('app-scrollbar-thumb'),
    );
    Rect thumb() => tester.getRect(thumbFinder);

    expect(thumb().top, closeTo(box.top, 1));
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    expect(thumb().bottom, closeTo(box.bottom, 1));
  });
}
