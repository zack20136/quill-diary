import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/presentation/settings/widgets/personalization_sections.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  Widget testApp(Brightness brightness) {
    return widgetTestApp(
      brightness: brightness,
      center: false,
      child: SingleChildScrollView(
        child: PersonalizationTypographySectionBody(
          typography: EditorTypographyPreferences.defaults,
          controller: PersonalizationPreferencesController(),
          onTypographyChanged: (_) {},
        ),
      ),
    );
  }

  Color previewColor(WidgetTester tester) {
    final DecoratedBox preview = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('personalization-typography-preview')),
    );
    return (preview.decoration as BoxDecoration).color!;
  }

  testWidgets('深色文字預覽沿用日記正文背景色', (WidgetTester tester) async {
    await tester.pumpWidget(testApp(Brightness.dark));

    final ThemeData theme = appTestTheme(brightness: Brightness.dark);
    final AppColors colors = theme.extension<AppColors>()!;
    expect(previewColor(tester), colors.previewPanel);
    expect(previewColor(tester), theme.colorScheme.surfaceContainerHigh);
  });

  testWidgets('淺色文字預覽維持原本背景色', (WidgetTester tester) async {
    await tester.pumpWidget(testApp(Brightness.light));

    final AppColors colors = appTestTheme().extension<AppColors>()!;
    expect(previewColor(tester), colors.previewPanel);
  });
}
