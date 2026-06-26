import 'package:flutter/material.dart';

/// 品牌種子色（天藍）。
const Color kBrandSeedColor = Color(0xFF4A7FE8);

/// 手調淺色色票：淺藍底、天藍強調色。
const ColorScheme kAppLightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF3B6DB5),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFD6E6FF),
  onPrimaryContainer: Color(0xFF001B3D),
  secondary: Color(0xFF4F5F7A),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFDCE3F2),
  onSecondaryContainer: Color(0xFF0A1628),
  tertiary: Color(0xFF5A7FA8),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFD8E8F8),
  onTertiaryContainer: Color(0xFF0A1E33),
  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF410002),
  surface: Color(0xFFF8FAFF),
  onSurface: Color(0xFF191C22),
  surfaceDim: Color(0xFFD8DEEA),
  surfaceBright: Color(0xFFF8FAFF),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF1F4FA),
  surfaceContainer: Color(0xFFEBEEF6),
  surfaceContainerHigh: Color(0xFFE5E9F0),
  surfaceContainerHighest: Color(0xFFDFE3EC),
  onSurfaceVariant: Color(0xFF424752),
  outline: Color(0xFF727886),
  outlineVariant: Color(0xFFC2C8D6),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFF2E3138),
  onInverseSurface: Color(0xFFF0F2F7),
  inversePrimary: Color(0xFFA8C8FF),
  surfaceTint: Color(0xFF3B6DB5),
);

/// 手調深色色票：深藍灰底、柔和天藍強調色（與淺色互為 inverse 配對）。
const ColorScheme kAppDarkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFA8C8FF),
  onPrimary: Color(0xFF002F66),
  primaryContainer: Color(0xFF1E3A66),
  onPrimaryContainer: Color(0xFFD6E6FF),
  secondary: Color(0xFFB8C8E0),
  onSecondary: Color(0xFF1A2838),
  secondaryContainer: Color(0xFF1E2A3D),
  onSecondaryContainer: Color(0xFFDCE3F2),
  tertiary: Color(0xFF9CB4D8),
  onTertiary: Color(0xFF1A2838),
  tertiaryContainer: Color(0xFF243248),
  onTertiaryContainer: Color(0xFFD6E6FF),
  error: Color(0xFFFF9A94),
  onError: Color(0xFF2D1518),
  errorContainer: Color(0xFF1A2433),
  onErrorContainer: Color(0xFFFFB4AB),
  surface: Color(0xFF0D1219),
  onSurface: Color(0xFFE2E6EF),
  surfaceDim: Color(0xFF080C12),
  surfaceBright: Color(0xFF323A48),
  surfaceContainerLowest: Color(0xFF060910),
  surfaceContainerLow: Color(0xFF101825),
  surfaceContainer: Color(0xFF141C2A),
  surfaceContainerHigh: Color(0xFF1A2434),
  surfaceContainerHighest: Color(0xFF212C3E),
  onSurfaceVariant: Color(0xFFB8BEC9),
  outline: Color(0xFF7A8496),
  outlineVariant: Color(0xFF3A4252),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFFE2E6EF),
  onInverseSurface: Color(0xFF2A2F38),
  inversePrimary: Color(0xFF3B6DB5),
  surfaceTint: Color(0xFFA8C8FF),
);

/// 依亮度回傳固定手調 [ColorScheme]。
ColorScheme resolveAppColorScheme({required Brightness brightness}) {
  return brightness == Brightness.light
      ? kAppLightColorScheme
      : kAppDarkColorScheme;
}
