import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';

import '../../helpers/app_test_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.dark ? '暗色' : '亮色';

    test('$mode 主題的共用文字與底色搭配達到一般文字對比', () {
      final theme = appTestTheme(brightness: brightness);
      final scheme = theme.colorScheme;
      final colors = theme.extension<AppColors>()!;
      final calendar = colors.calendar;
      final pairs = <String, ({Color background, Color foreground})>{
        '主要操作': (background: scheme.primary, foreground: scheme.onPrimary),
        '次要操作': (
          background: scheme.secondaryContainer,
          foreground: scheme.onSecondaryContainer,
        ),
        '破壞性操作': (background: scheme.error, foreground: scheme.onError),
        '正文': (background: colors.sectionCard, foreground: scheme.onSurface),
        '搜尋提示': (
          background: colors.sectionCard,
          foreground: scheme.onSurfaceVariant,
        ),
        '選取分頁': colors.selectedControl,
        '選取列': (
          background: colors.selectedRowFill,
          foreground: scheme.onSurface,
        ),
        '日曆今天': calendar.todayBadge,
        '日曆一般日期': (
          background: calendar.day,
          foreground: calendar.dateForeground,
        ),
        '日曆跨月日期': (
          background: calendar.day,
          foreground: calendar.outsideForeground,
        ),
        '日曆有日記的週日': (
          background: calendar.entryDay,
          foreground: calendar.sundayForeground,
        ),
        '日曆有日記的週六': (
          background: calendar.entryDay,
          foreground: calendar.saturdayForeground,
        ),
        '日曆選取有日記的日期': (
          background: calendar.selectedEntryDay,
          foreground: calendar.selectedForeground,
        ),
        '資訊': colors.infoFeedback,
        '成功': colors.successFeedback,
        '安全狀態正常': (
          background: scheme.surfaceContainerHigh,
          foreground: colors.successFeedback.foreground,
        ),
        '注意': colors.warningFeedback,
        '錯誤': colors.errorFeedback,
      };
      for (final MapEntry(key: label, value: pair) in pairs.entries) {
        final values = [
          pair.background.computeLuminance(),
          Color.alphaBlend(pair.foreground, pair.background).computeLuminance(),
        ]..sort();
        expect(
          (values.last + 0.05) / (values.first + 0.05),
          greaterThanOrEqualTo(4.5),
          reason: label,
        );
      }
    });
  }
}
