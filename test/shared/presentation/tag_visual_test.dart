import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/shared/presentation/tag_visual.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';

import '../../helpers/app_test_theme.dart';

void main() {
  for (final Brightness brightness in Brightness.values) {
    test('${brightness == Brightness.light ? '淺色' : '深色'}模式標籤選色與顯示共用相同配色', () {
      final ThemeData theme = appTestTheme(brightness: brightness);
      final ColorScheme scheme = theme.colorScheme;
      final AppColors colors = theme.extension<AppColors>()!;
      final Color accent = kAccentColorPresets.first;
      final (Color, Color) previewPair = accentColorPair(
        accent,
        colors.sectionInset,
      );
      final (Color, Color) displayedPair = tagResolvedAccentPair(
        '測試標籤',
        scheme,
        <String, int>{'測試標籤': colorArgb32(accent)},
        colors,
      );

      expect(displayedPair, previewPair);

      final BorderSide? border = tagBorderSide(
        colors,
        scheme,
        displayedPair.$1,
        displayedPair.$2,
      );
      expect(border, isNotNull);
      expect(
        border!.color,
        displayedPair.$2.withValues(alpha: kAccentBorderAlpha),
      );
    });
  }

  test('沒有目錄色的標籤維持中性色', () {
    final ThemeData theme = appTestTheme();
    final AppColors colors = theme.extension<AppColors>()!;

    expect(
      tagResolvedAccentPair('未設定', theme.colorScheme, const {}, colors),
      tagNeutralAccentPair(theme.colorScheme),
    );
  });
}
