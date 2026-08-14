import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/app/app_color_scheme.dart';
import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/app/theme.dart';

void main() {
  const testCases = <({String name, Brightness brightness})>[
    (name: '淺色', brightness: Brightness.light),
    (name: '深色', brightness: Brightness.dark),
  ];

  for (final testCase in testCases) {
    test('buildAppTheme ${testCase.name} 會套用正確的主題設定', () {
      final ColorScheme expectedScheme = resolveAppColorScheme(
        brightness: testCase.brightness,
      );

      final ThemeData theme = buildAppTheme(brightness: testCase.brightness);
      final AppColors appColors = theme.extension<AppColors>()!;

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, testCase.brightness);
      expect(theme.colorScheme, expectedScheme);
      expect(theme.scaffoldBackgroundColor, appColors.scaffoldBackground);
      expect(theme.appBarTheme.backgroundColor, appColors.scaffoldBackground);
      expect(theme.cardTheme.color, expectedScheme.surfaceContainerLowest);
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(
        theme.inputDecorationTheme.fillColor,
        expectedScheme.surfaceContainerLowest,
      );
      expect(
        theme.inputDecorationTheme.focusedBorder,
        isA<OutlineInputBorder>(),
      );
      expect(theme.textTheme.bodyLarge?.color, appColors.foreground);
    });
  }

  test('淺深 AppColors token 應不同', () {
    final AppColors light = AppColors.from(kAppLightColorScheme);
    final AppColors dark = AppColors.from(kAppDarkColorScheme);

    expect(light.scaffoldBackground, isNot(dark.scaffoldBackground));
    expect(light.foreground, isNot(dark.foreground));
  });

  test('深色內容背景統一使用不透明的 surfaceContainerHigh', () {
    final AppColors colors = AppColors.from(kAppDarkColorScheme);

    expect(colors.sectionInset, kAppDarkColorScheme.surfaceContainerHigh);
    expect(colors.previewPanel, kAppDarkColorScheme.surfaceContainerHigh);
    expect(colors.sectionInset.a, 1);
    expect(colors.previewPanel.a, 1);
  });

  test('淺色內容背景維持原本層級', () {
    final AppColors colors = AppColors.from(kAppLightColorScheme);
    final Color expectedPreview = Color.alphaBlend(
      kAppLightColorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      kAppLightColorScheme.surface.withValues(alpha: 0.88),
    );

    expect(colors.sectionInset, kAppLightColorScheme.surfaceContainerLow);
    expect(colors.previewPanel, expectedPreview);
  });

  test('固定色票關鍵欄位', () {
    expect(kAppLightColorScheme.primary, const Color(0xFF3B6DB5));
    expect(kAppDarkColorScheme.primary, const Color(0xFF91AFE0));
    expect(kAppDarkColorScheme.error, const Color(0xFFE48782));
    expect(kAppLightColorScheme.inversePrimary, const Color(0xFFA8C8FF));
    expect(kAppDarkColorScheme.inversePrimary, kAppLightColorScheme.primary);
    expect(kAppLightColorScheme.brightness, Brightness.light);
    expect(kAppDarkColorScheme.brightness, Brightness.dark);
  });
}
