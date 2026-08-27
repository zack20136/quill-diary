import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/editor/editor_body_blocks.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_checkbox_block_row.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_hybrid_body.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_markdown_preview.dart';

import '../../helpers/presentation/editor/editor_test_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditorHybridBody', () {
    testWidgets('從空白純文字內容插入第一個任務項目', (WidgetTester tester) async {
      final ({
        TextEditingController bodyController,
        GlobalKey<EditorHybridBodyState> bodyKey,
      })
      harness = await pumpEditorHybridBody(tester);

      harness.bodyKey.currentState!.insertCheckboxAtCursor();
      await tester.pumpAndSettle();

      expect(harness.bodyController.text, contains('- [ ]'));
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('插入任務項目後會保留後續文字行', (WidgetTester tester) async {
      final ({
        TextEditingController bodyController,
        GlobalKey<EditorHybridBodyState> bodyKey,
      })
      harness = await pumpEditorHybridBody(
        tester,
        bodyText: '15651\n- [x] 111\n456456',
      );

      harness.bodyKey.currentState!.insertCheckboxAtCursor();
      await tester.pumpAndSettle();

      final String markdown = harness.bodyController.text;
      expect(markdown, contains('456456'));
      expect(markdown, contains('15651'));
      expect(markdown, contains('- [ ]'));
      expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(2));
    });

    testWidgets('在空白文字行按 backspace 會刪除該行', (WidgetTester tester) async {
      final ({
        TextEditingController bodyController,
        GlobalKey<EditorHybridBodyState> bodyKey,
      })
      harness = await pumpEditorHybridBody(
        tester,
        bodyText: '第一行\n\n第三行\n- [ ] 任務三',
      );

      final Finder emptyLineField = find.byType(TextField).at(1);
      await tester.tap(emptyLineField);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(harness.bodyController.text, '第一行\n第三行\n- [ ] 任務三\n');
    });

    testWidgets('刪除最後一個任務項目後會回到純文字編輯器', (WidgetTester tester) async {
      final ({
        TextEditingController bodyController,
        GlobalKey<EditorHybridBodyState> bodyKey,
      })
      harness = await pumpEditorHybridBody(tester, bodyText: '- [ ]\n');

      expect(find.byType(ReorderableListView), findsOneWidget);

      final Finder taskItemField = find.byType(TextField).first;
      await tester.tap(taskItemField);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(find.byType(ReorderableListView), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(harness.bodyController.text, isNot(contains('- [ ]')));
    });

    testWidgets('核取方塊視覺 24px 並與第一行文字頂對齊', (WidgetTester tester) async {
      final TextEditingController textController = TextEditingController(
        text: '第一行\n第二行\n第三行',
      );
      addTearDown(textController.dispose);

      await tester.pumpWidget(
        editorTestApp(
          child: EditorCheckboxBlockRow(
            block: const EditorCheckboxLine(
              id: 'c1',
              text: '第一行\n第二行\n第三行',
              checked: false,
            ),
            typography: EditorTypographyPreferences.defaults,
            bodyStyle: const TextStyle(fontSize: 16, height: 1.4),
            editable: true,
            textController: textController,
            onCheckedChanged: (_) {},
            onTextChanged: (_) {},
          ),
        ),
      );

      final Size checkboxSize = tester.getSize(find.byType(Checkbox));
      expect(checkboxSize.width, lessThanOrEqualTo(24));
      expect(checkboxSize.height, lessThanOrEqualTo(24));

      final double checkboxTop = tester.getTopLeft(find.byType(Checkbox)).dy;
      final double textTop = tester.getTopLeft(find.byType(TextField)).dy;
      // 允許 top: 2 的光學微調，但不應落到多行文字中央。
      expect((checkboxTop - textTop).abs(), lessThan(8));
    });
  });

  group('EditorMarkdownPreview', () {
    testWidgets('點擊任務項目會更新 markdown', (WidgetTester tester) async {
      String? changedMarkdown;
      const String markdown = '前言\n- [ ] 任務三';

      await tester.pumpWidget(
        editorTestApp(
          child: EditorMarkdownPreview(
            markdown: markdown,
            typography: EditorTypographyPreferences.defaults,
            interactiveCheckboxes: true,
            onMarkdownChanged: (String value) => changedMarkdown = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      // 不 settle，確認勾選動畫期間元件仍保留同一顆 Checkbox。
      await tester.pump();
      expect(find.byType(Checkbox), findsOneWidget);
      await tester.pumpAndSettle();

      expect(changedMarkdown, '前言\n- [x] 任務三');
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox)).value,
        isTrue,
      );
    });
  });
}
