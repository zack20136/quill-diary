import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/presentation/tag/widgets/tag_accent_composer_dialog.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';
import 'package:quill_diary/shared/presentation/widgets/accent_chip.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  Widget host({required Brightness brightness, required Widget child}) =>
      widgetTestApp(
        brightness: brightness,
        center: false,
        overrides: const [],
        child: child,
      );

  for (final fail in [false, true]) {
    testWidgets('刪除${fail ? '拋出錯誤' : '回傳 false'}時保留編輯內容，成功才關閉視窗', (tester) async {
      var deleted = false;
      await tester.pumpWidget(
        host(
          brightness: Brightness.light,
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

  testWidgets('暗色模式下色盤與預覽使用相同 Accent，而非混色背景', (WidgetTester tester) async {
    const Color accent = Color(0xFF62A87C);
    await tester.pumpWidget(
      host(
        brightness: Brightness.dark,
        child: TagAccentComposerDialog(
          titleText: testL10n.tagEditTitle,
          initialDisplayLabel: '心得',
          initialAccentArgb: colorArgb32(accent),
          initialAccentIsCustom: true,
        ),
      ),
    );

    final AnimatedContainer presetSwatch = tester.widget<AnimatedContainer>(
      find.byKey(const Key('tag-color-preset-swatch-8')),
    );
    expect(
      (presetSwatch.decoration as BoxDecoration).color,
      accentSwatchColor(accentColorPresets[8]),
    );

    final Container customSwatch = tester.widget<Container>(
      find.byKey(const Key('tag-custom-color-swatch')),
    );
    expect(
      (customSwatch.decoration as BoxDecoration).color,
      accentSwatchColor(accent),
    );

    final AccentChip preview = tester.widget<AccentChip>(
      find.byType(AccentChip),
    );
    expect(preview.foreground, accent);
    expect(preview.background, isNot(accentSwatchColor(accent)));
  });
}
