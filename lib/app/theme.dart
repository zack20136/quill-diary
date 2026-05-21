import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

ThemeData buildAppTheme({ColorScheme? dynamicScheme, Brightness brightness = Brightness.light}) {
  final ColorScheme scheme = dynamicScheme ??
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF4C7A67),
        brightness: brightness,
      );

  return FlexThemeData.light(
    colorScheme: scheme,
    useMaterial3: true,
    appBarElevation: 0,
    subThemesData: const FlexSubThemesData(
      interactionEffects: true,
      defaultRadius: 18,
      blendOnLevel: 12,
      blendOnColors: false,
      cardRadius: 20,
      inputDecoratorRadius: 16,
      elevatedButtonRadius: 16,
      filledButtonRadius: 16,
      outlinedButtonRadius: 16,
    ),
    textTheme: ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    ).textTheme,
    fontFamily: null,
  ).copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
  );
}
