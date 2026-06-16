import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/app/theme.dart';
import 'package:quill_diary/shared/presentation/app_typography.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';

void main() {
  test('buildAppTheme light 會使用預設頁面底色與輸入樣式', () {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4C7A67),
      brightness: Brightness.light,
    );

    final ThemeData theme = buildAppTheme(dynamicScheme: scheme);

    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, PageStyle.scaffoldWash(scheme));
    expect(theme.appBarTheme.backgroundColor, PageStyle.scaffoldWash(scheme));
    expect(theme.appBarTheme.foregroundColor, AppTypography.ink);
    expect(theme.cardTheme.color, scheme.surfaceContainerLowest);
    expect(theme.inputDecorationTheme.filled, isTrue);
    expect(theme.inputDecorationTheme.fillColor, scheme.surfaceContainerLowest);
    expect(theme.inputDecorationTheme.focusedBorder, isA<OutlineInputBorder>());
    expect(theme.textTheme.bodyLarge?.fontFamily, AppTypography.interFamily);
    expect(theme.textTheme.bodyLarge?.color, AppTypography.ink);
  });

  test('buildAppTheme dark 會跟隨色盤與 surface 變化', () {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2D4E6A),
      brightness: Brightness.dark,
    );

    final ThemeData theme = buildAppTheme(
      dynamicScheme: scheme,
      brightness: Brightness.dark,
    );

    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, PageStyle.scaffoldWash(scheme));
    expect(theme.appBarTheme.backgroundColor, PageStyle.scaffoldWash(scheme));
    expect(theme.appBarTheme.foregroundColor, scheme.onSurface);
    expect(theme.cardTheme.color, scheme.surfaceContainerLowest);
    expect(theme.inputDecorationTheme.fillColor, scheme.surfaceContainerLowest);
    expect(theme.textTheme.bodyLarge?.color, scheme.onSurface);
  });
}
