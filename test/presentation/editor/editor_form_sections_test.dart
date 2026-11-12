import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_form_sections.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';

import '../../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('檢視模式正文不顯示捲軸', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: List<String>.filled(80, '一行日記').join('\n'),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: EditorBodySection(
                previewMode: true,
                bodyController: controller,
                typography: EditorTypographyPreferences.defaults,
                onBodyChanged: () {},
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppScrollbar), findsNothing);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
