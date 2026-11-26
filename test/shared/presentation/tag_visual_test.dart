import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/tag_visual.dart';

import '../../helpers/app_test_theme.dart';

void main() {
  test('用正規化名稱查標籤自訂色，查無設定時使用中性色', () {
    final theme = appTestTheme();
    final palette = theme.extension<AppColors>()!;
    const accent = Color(0xFF62A87C);
    final accents = {'trip': colorArgb32(accent)};

    final matched = resolveTagColors(
      ' Trip ',
      theme.colorScheme,
      accents,
      palette,
    );
    final missing = resolveTagColors(
      '其他標籤',
      theme.colorScheme,
      accents,
      palette,
    );

    expect(matched.accent, accent);
    expect(missing.accent, isNull);
  });
}
