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
