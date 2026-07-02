import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/app/theme.dart';
import 'package:quill_diary/features/editor/presentation/editor_hybrid_body.dart';
import 'package:quill_diary/features/editor/presentation/editor_markdown_preview.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditorHybridBody', () {
    testWidgets('insertCheckboxAtCursor works from empty plain text body', (
      WidgetTester tester,
    ) async {
      final TextEditingController bodyController = TextEditingController();
      final GlobalKey<EditorHybridBodyState> bodyKey =
          GlobalKey<EditorHybridBodyState>();

      await tester.pumpWidget(
        _wrap(
          EditorHybridBody(
            key: bodyKey,
            bodyController: bodyController,
            typography: EditorTypographyPreferences.defaults,
            onBodyChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      bodyKey.currentState!.insertCheckboxAtCursor();
      await tester.pumpAndSettle();

      expect(bodyController.text, contains('- [ ]'));
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('insertCheckboxAtCursor keeps following text lines', (
      WidgetTester tester,
    ) async {
      final TextEditingController bodyController = TextEditingController(
        text: '15651\n- [x] 111\n456456',
      );
      final GlobalKey<EditorHybridBodyState> bodyKey =
          GlobalKey<EditorHybridBodyState>();

      await tester.pumpWidget(
        _wrap(
          EditorHybridBody(
            key: bodyKey,
            bodyController: bodyController,
            typography: EditorTypographyPreferences.defaults,
            onBodyChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      bodyKey.currentState!.insertCheckboxAtCursor();
      await tester.pumpAndSettle();

      final String markdown = bodyController.text;
      expect(markdown, contains('456456'));
      expect(markdown, contains('15651'));
      expect(markdown, contains('- [ ]'));
      expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(2));
    });

    testWidgets('backspace on empty text line removes the line', (
      WidgetTester tester,
    ) async {
      final TextEditingController bodyController = TextEditingController(
        text: '第一行\n\n第三行\n- [ ] 待辦',
      );

      await tester.pumpWidget(
        _wrap(
          EditorHybridBody(
            bodyController: bodyController,
            typography: EditorTypographyPreferences.defaults,
            onBodyChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder emptyLineField = find.byType(TextField).at(1);
      await tester.tap(emptyLineField);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(bodyController.text, '第一行\n第三行\n- [ ] 待辦\n');
    });

    testWidgets('checkbox backspace on empty line removes checkbox', (
      WidgetTester tester,
    ) async {
      final TextEditingController bodyController = TextEditingController(
        text: '- [ ]\n',
      );

      await tester.pumpWidget(
        _wrap(
          EditorHybridBody(
            bodyController: bodyController,
            typography: EditorTypographyPreferences.defaults,
            onBodyChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder checkboxField = find.byType(TextField).first;
      await tester.tap(checkboxField);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(bodyController.text, isNot(contains('- [ ]')));
    });
  });

  group('EditorMarkdownPreview', () {
    testWidgets('toggling checkbox updates markdown', (
      WidgetTester tester,
    ) async {
      String? changedMarkdown;
      const String markdown = '前言\n- [ ] 待辦';

      await tester.pumpWidget(
        _wrap(
          EditorMarkdownPreview(
            markdown: markdown,
            typography: EditorTypographyPreferences.defaults,
            interactiveCheckboxes: true,
            onMarkdownChanged: (String value) => changedMarkdown = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(changedMarkdown, '前言\n- [x] 待辦');
    });
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(brightness: Brightness.light),
    locale: appZhLocale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 600,
        child: child,
      ),
    ),
  );
}
