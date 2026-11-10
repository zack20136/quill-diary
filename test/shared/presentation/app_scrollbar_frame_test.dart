import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';

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
    final thumbFinder = find.byKey(const ValueKey<String>('app-scrollbar-thumb'));
    Rect thumb() => tester.getRect(thumbFinder);

    final double topGap = thumb().top - box.top;
    await tester.drag(thumbFinder, const Offset(0, 400));
    await tester.pump();
    expect(scroll.offset, closeTo(scroll.position.maxScrollExtent, 1));
    final double bottomGap = box.bottom - thumb().bottom;

    expect(topGap, AppScrollbarMetrics.frameMainAxisInset);
    expect(bottomGap, closeTo(topGap, 0.1));
  });
}
