import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/app/theme.dart';

void main() {
  const testCases = <({String name, Brightness brightness, Color seedColor})>[
    (name: 'light', brightness: Brightness.light, seedColor: Color(0xFF4C7A67)),
    (name: 'dark', brightness: Brightness.dark, seedColor: Color(0xFF2D4E6A)),
  ];

  for (final testCase in testCases) {
    test('buildAppTheme ${testCase.name} 保留關鍵視覺契約', () {
      final ColorScheme scheme = ColorScheme.fromSeed(
        seedColor: testCase.seedColor,
        brightness: testCase.brightness,
      );

      final ThemeData theme = buildAppTheme(
        dynamicScheme: scheme,
        brightness: testCase.brightness,
      );

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, testCase.brightness);
      expect(theme.colorScheme, scheme);
      expect(theme.appBarTheme.backgroundColor, theme.scaffoldBackgroundColor);
      expect(theme.cardTheme.color, scheme.surfaceContainerLowest);
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(
        theme.inputDecorationTheme.fillColor,
        scheme.surfaceContainerLowest,
      );
      expect(
        theme.inputDecorationTheme.focusedBorder,
        isA<OutlineInputBorder>(),
      );
      expect(theme.textTheme.bodyLarge?.color, isNotNull);
    });
  }
}
