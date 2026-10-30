import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/presentation/home/portable_transfer_dialogs.dart';

import '../../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('選擇篇目回傳原始識別值，全不選時停用確認且不修改原集合', (tester) async {
    final selected = {7};
    Set<int>? result;
    await tester.pumpWidget(
      widgetTestApp(
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await showPortableEntrySelectionDialog<int>(
                  context: context,
                  entries: const [
                    PortableEntryOption(
                      id: 7,
                      title: '第一篇',
                      subtitle: '2026-10-29',
                    ),
                    PortableEntryOption(
                      id: 42,
                      title: '',
                      subtitle: '2026-10-30 · 可能重複',
                    ),
                  ],
                  initiallySelected: selected,
                );
              },
              child: const Text('開啟'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    expect(find.text('2026-10-30 · 可能重複'), findsOneWidget);
    await tester.tap(find.text('取消全選'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '確定'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('全選'));
    await tester.pump();
    await tester.tap(find.text('第一篇'));
    await tester.pump();
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();
    expect(result, {42});
    expect(selected, {7});
  });

  testWidgets('取消篇目選擇回傳空結果，保留原本字串 ID 選取', (tester) async {
    final selected = {'entry-b'};
    Set<String>? result = {};
    await tester.pumpWidget(
      widgetTestApp(
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await showPortableEntrySelectionDialog<String>(
                  context: context,
                  entries: const [
                    PortableEntryOption(
                      id: 'entry-b',
                      title: '原篇目',
                      subtitle: '2026-10-30',
                    ),
                  ],
                  initiallySelected: selected,
                );
              },
              child: const Text('開啟'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消全選'));
    await tester.pump();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(selected, {'entry-b'});
  });
}
