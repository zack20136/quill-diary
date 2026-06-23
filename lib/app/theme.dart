import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import '../shared/presentation/app_scrollbar.dart';
import '../shared/presentation/app_typography.dart';
import '../shared/presentation/page_style.dart';

ThemeData buildAppTheme({
  ColorScheme? dynamicScheme,
  Brightness brightness = Brightness.light,
}) {
  final ColorScheme scheme =
      dynamicScheme ??
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF4C7A67),
        brightness: brightness,
      );

  final TextTheme base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
  ).textTheme;
  final TextTheme textTheme = AppTypography.textTheme(
    base,
    brightness: brightness,
    scheme: scheme,
  );
  final Color foreground = brightness == Brightness.light
      ? AppTypography.ink
      : scheme.onSurface;

  final ThemeData flexTheme = brightness == Brightness.dark
      ? FlexThemeData.dark(
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
          textTheme: textTheme,
          fontFamily: AppTypography.interFamily,
        )
      : FlexThemeData.light(
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
          textTheme: textTheme,
          fontFamily: AppTypography.interFamily,
        );

  final Color pageBackground = PageStyle.scaffoldWash(scheme);

  return flexTheme.copyWith(
    scaffoldBackgroundColor: pageBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: pageBackground,
      foregroundColor: foreground,
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
      hintStyle: textTheme.bodyLarge?.copyWith(
        color: AppTypography.muted(scheme),
        fontStyle: FontStyle.italic,
      ),
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
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      ),
    ),
    scrollbarTheme: kAppScrollbarTheme,
  );
}
