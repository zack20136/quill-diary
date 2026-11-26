import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/people/person_mention_controller.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_form_sections.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';

import '../../helpers/presentation/editor/editor_test_scope.dart';

void main() {
  final thumb = find.byKey(const ValueKey<String>('app-scrollbar-thumb'));
  final frame = find.byKey(const ValueKey('editor-body-section-background'));

  Future<void> pumpPreview(WidgetTester tester, String body) async {
    final controller = TextEditingController(text: body);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      editorTestApp(
        viewport: const Size(360, 220),
        child: EditorBodySection(
          previewMode: true,
          rightGutterWidth: 12,
          bodyController: controller,
          typography: EditorTypographyPreferences.defaults,
          onBodyChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('檢視模式的正文能放下時不顯示滑塊', (tester) async {
    await pumpPreview(tester, '一行日記');
    expect(thumb, findsNothing);
  });

  testWidgets('待辦和純文字的長文滑塊都可在框外拖到底，短文時隱藏', (tester) async {
    final controller = TextEditingController(
      text: List.generate(40, (index) => '- [ ] 待辦 $index').join('\n'),
    );
    final mentions = PersonMentionController();
    addTearDown(controller.dispose);
    addTearDown(mentions.dispose);
    await tester.pumpWidget(
      editorTestApp(
        viewport: const Size(360, 340),
        child: EditorBodySection(
          previewMode: false,
          rightGutterWidth: 12,
          bodyController: controller,
          typography: EditorTypographyPreferences.defaults,
          onBodyChanged: () {},
          mentionController: mentions,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final frameRect = tester.getRect(frame);
    final scrollbar = tester.getRect(find.byType(AppScrollbar));
    expect(
      tester.getCenter(thumb).dx,
      closeTo((frameRect.right + scrollbar.right) / 2, 0.1),
    );
    final topGap = tester.getTopLeft(thumb).dy - frameRect.top;
    final position = tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .scrollController!
        .position;
    await tester.drag(thumb, const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(position.maxScrollExtent, 1));
    expect(
      frameRect.bottom - tester.getBottomRight(thumb).dy,
      closeTo(topGap, 0.1),
    );

    controller.text = '改成純文字';
    await tester.pumpAndSettle();
    expect(thumb, findsNothing);

    controller.text = List.generate(40, (index) => '日記正文 $index').join('\n');
    await tester.pumpAndSettle();
    expect(tester.getRect(frame), frameRect);
    expect(
      tester.getCenter(thumb).dx,
      closeTo((frameRect.right + scrollbar.right) / 2, 0.1),
    );
    final plainTextPosition = tester
        .widget<TextField>(find.byType(TextField))
        .scrollController!
        .position;
    await tester.drag(thumb, const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(
      plainTextPosition.pixels,
      closeTo(plainTextPosition.maxScrollExtent, 1),
    );

    controller.text = '縮短正文';
    await tester.pumpAndSettle();
    expect(thumb, findsNothing);
  });

  testWidgets('檢視長文可拖曳框外滑塊，並全選複製包含畫面外的正文', (tester) async {
    final lines = List.generate(18, (index) => '第 $index 段正文');
    String? copied;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await pumpPreview(tester, lines.join('\n'));

    final frameRect = tester.getRect(frame);
    final scrollbar = tester.getRect(find.byType(AppScrollbar));
    expect(
      tester.getCenter(thumb).dx,
      closeTo((frameRect.right + scrollbar.right) / 2, 0.1),
    );
    final position = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!
        .position;
    await tester.drag(thumb, const Offset(0, 230));
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(position.maxScrollExtent, 1));

    final context = tester.element(find.text(lines.last));
    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .selectAll();
    await tester.pump();
    Actions.invoke(context, CopySelectionTextIntent.copy);
    await tester.pump();

    expect(copied, contains(lines.first));
    expect(copied, contains(lines.last));
  });
}
