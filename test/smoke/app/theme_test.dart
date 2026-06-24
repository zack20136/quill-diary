import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/app/app_color_scheme.dart';
import 'package:quill_diary/app/theme.dart';

void main() {
  const testCases = <({String name, Brightness brightness})>[
    (name: 'light', brightness: Brightness.light),
    (name: 'dark', brightness: Brightness.dark),
  ];

  for (final testCase in testCases) {
    test('buildAppTheme ${testCase.name} 會套用正確的主題設定', () {
      final ColorScheme expectedScheme = resolveAppColorScheme(
        brightness: testCase.brightness,
      );

      final ThemeData theme = buildAppTheme(
        brightness: testCase.brightness,
      );

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, testCase.brightness);
      expect(theme.colorScheme, expectedScheme);
      expect(theme.appBarTheme.backgroundColor, theme.scaffoldBackgroundColor);
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
      expect(theme.textTheme.bodyLarge?.color, isNotNull);
    });
  }
}
