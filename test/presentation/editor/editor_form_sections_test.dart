import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_form_sections.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_person_suggestion_panel.dart';
import 'package:quill_diary/shared/presentation/person_visual.dart';

import '../../helpers/app_test_theme.dart';

void main() {
  Widget testApp({
    required Brightness brightness,
    required TextEditingController bodyController,
    Widget? footer,
  }) {
    return MaterialApp(
      theme: appTestTheme(brightness: brightness),
      locale: appZhLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Column(
          children: <Widget>[
            Expanded(
              child: EditorBodySection(
                previewMode: false,
                bodyController: bodyController,
                typography: EditorTypographyPreferences.defaults,
                onBodyChanged: () {},
              ),
            ),
            ?footer,
          ],
        ),
      ),
    );
  }

  BoxDecoration bodyDecoration(WidgetTester tester) {
    return tester
            .widget<DecoratedBox>(
              find.byKey(
                const ValueKey<String>('editor-body-section-background'),
              ),
            )
            .decoration
        as BoxDecoration;
  }

  testWidgets('深色模式正文輸入區沿用人物選擇列背景色', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(text: '正文');
    addTearDown(controller.dispose);
    final DateTime now = DateTime(2026);
    final Person person = Person(
      id: 'person-1',
      name: '小明',
      accentArgb: 0xFF5480B0,
      createdAt: now,
      updatedAt: now,
    );
    await tester.pumpWidget(
      testApp(
        brightness: Brightness.dark,
        bodyController: controller,
        footer: EditorPersonSuggestionPanel(
          suggestions: <EditorPersonSuggestion>[
            EditorPersonSuggestion(person: person),
          ],
          highlightIndex: 0,
          catalogEmpty: false,
          onSelected: (_) {},
          onCreatePerson: () {},
        ),
      ),
    );

    final ThemeData theme = appTestTheme(brightness: Brightness.dark);
    final AppColors colors = theme.extension<AppColors>()!;
    final Color bodyColor = bodyDecoration(tester).color!;
    final Color suggestionColor = tester
        .widget<Material>(
          find.byKey(
            const ValueKey<String>('editor-person-suggestion-background'),
          ),
        )
        .color!;
    final (Color chipBackground, Color chipForeground) = personLabelColorPair(
      person,
      colors.sectionInset,
    );
    final FilterChip chip = tester.widget<FilterChip>(find.byType(FilterChip));

    expect(bodyColor, colors.previewPanel);
    expect(suggestionColor, bodyColor);
    expect(chip.backgroundColor, chipBackground);
    expect(chip.selectedColor, chipBackground);
    expect((chip.label as Text).style?.color, chipForeground);
  });

  testWidgets('淺色模式正文輸入區維持原本背景色', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(text: '正文');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      testApp(brightness: Brightness.light, bodyController: controller),
    );

    final ThemeData theme = appTestTheme();
    expect(
      bodyDecoration(tester).color,
      theme.extension<AppColors>()!.previewPanel,
    );
  });
}
