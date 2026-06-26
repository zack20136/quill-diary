import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import 'app_color_scheme.dart';
import 'app_colors.dart';
import '../shared/presentation/app_scrollbar.dart';
import '../shared/presentation/app_typography.dart';
import '../shared/presentation/page_style.dart';

const FlexSubThemesData _kFlexSubThemesLight = FlexSubThemesData(
  interactionEffects: true,
  defaultRadius: 18,
  blendOnLevel: 12,
  blendOnColors: false,
  cardRadius: 20,
  inputDecoratorRadius: 16,
  elevatedButtonRadius: 16,
  filledButtonRadius: 16,
  outlinedButtonRadius: 16,
);

const FlexSubThemesData _kFlexSubThemesDark = FlexSubThemesData(
  interactionEffects: true,
  defaultRadius: 18,
  blendOnLevel: 0,
  blendOnColors: false,
  cardRadius: 20,
  inputDecoratorRadius: 16,
  elevatedButtonRadius: 16,
  filledButtonRadius: 16,
  outlinedButtonRadius: 16,
);

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final ColorScheme scheme = resolveAppColorScheme(brightness: brightness);
  final AppColors appColors = AppColors.from(scheme);

  final TextTheme base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
  ).textTheme;
  final TextTheme textTheme = AppTypography.textTheme(
    base,
    defaultColor: appColors.foreground,
  );

  final ThemeData flexTheme = brightness == Brightness.dark
      ? FlexThemeData.dark(
          colorScheme: scheme,
          useMaterial3: true,
          appBarElevation: 0,
          darkIsTrueBlack: false,
          surfaceMode: FlexSurfaceMode.highSurfaceLowScaffold,
          subThemesData: _kFlexSubThemesDark,
          textTheme: textTheme,
          fontFamily: AppTypography.interFamily,
        )
      : FlexThemeData.light(
          colorScheme: scheme,
          useMaterial3: true,
          appBarElevation: 0,
          subThemesData: _kFlexSubThemesLight,
          textTheme: textTheme,
          fontFamily: AppTypography.interFamily,
        );

  return flexTheme.copyWith(
    colorScheme: scheme,
    extensions: <ThemeExtension<dynamic>>[appColors],
    scaffoldBackgroundColor: appColors.scaffoldBackground,
    iconTheme: IconThemeData(color: appColors.foreground),
    primaryIconTheme: IconThemeData(color: appColors.foreground),
    appBarTheme: AppBarTheme(
      backgroundColor: appColors.scaffoldBackground,
      foregroundColor: appColors.foreground,
      iconTheme: IconThemeData(color: appColors.foreground),
      actionsIconTheme: IconThemeData(color: appColors.foreground),
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(surfaceTintColor: Colors.transparent),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      hintStyle: textTheme.bodyLarge?.copyWith(
        color: appColors.mutedForeground,
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
    scrollbarTheme: kPrimaryScrollbarTheme,
  );
}
