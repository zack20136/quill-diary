import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/presentation/tag/widgets/tag_accent_composer_dialog.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  for (final fail in [false, true]) {
    testWidgets('刪除${fail ? '拋出錯誤' : '回傳 false'}時保留編輯內容，成功才關閉視窗', (
      tester,
    ) async {
      var deleted = false;
      await tester.pumpWidget(
        widgetTestApp(
          center: false,
          child: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showTagAccentComposerDialog(
                context: context,
                initialDisplayLabel: '原標籤',
                onDelete: () async {
                  if (fail && !deleted) throw StateError('寫入失敗');
                  return deleted;
                },
              ),
              child: const Text('開啟測試編輯'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開啟測試編輯'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '未存修改');
      await tester.tap(find.byTooltip(testL10n.commonActionDelete));
      await tester.pumpAndSettle();
      expect(find.byType(TagAccentComposerDialog), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '未存修改',
      );
      deleted = true;
      await tester.tap(find.byTooltip(testL10n.commonActionDelete));
      await tester.pumpAndSettle();
      expect(find.byType(TagAccentComposerDialog), findsNothing);
    });
  }
}
