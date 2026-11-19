import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_form_sections.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';

import '../../helpers/presentation/editor/editor_test_scope.dart';

void main() {
  Future<void> pumpPreview(WidgetTester tester, String body) async {
    final controller = TextEditingController(text: body);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      editorTestApp(
        viewport: const Size(360, 220),
        child: EditorBodySection(
          previewMode: true,
          bodyController: controller,
          typography: EditorTypographyPreferences.defaults,
          onBodyChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('檢視模式正文不顯示捲軸', (tester) async {
    await pumpPreview(tester, List.filled(18, '一行日記').join('\n'));
    expect(find.byType(AppScrollbar), findsNothing);
  });

  testWidgets('長篇日記可以全選並複製尚未捲到的正文', (tester) async {
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

    final context = tester.element(find.text(lines.first));
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
