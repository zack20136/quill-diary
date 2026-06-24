import 'package:flutter/material.dart';

/// 淺色主題品牌種子色（鼠尾草綠）。
const Color kBrandSeedColor = Color(0xFF4C7A67);

/// 手調深色色票：深藍灰底、柔和天藍強調色。
const ColorScheme kAppDarkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF8BAFE8),
  onPrimary: Color(0xFF0A1524),
  primaryContainer: Color(0xFF2A3F5C),
  onPrimaryContainer: Color(0xFFC5DCFA),
  secondary: Color(0xFFA8B8D4),
  onSecondary: Color(0xFF141C28),
  secondaryContainer: Color(0xFF2C3545),
  onSecondaryContainer: Color(0xFFD0DCF0),
  tertiary: Color(0xFFB8A8E0),
  onTertiary: Color(0xFF1F1630),
  tertiaryContainer: Color(0xFF3D3350),
  onTertiaryContainer: Color(0xFFE8D8F8),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF111318),
  onSurface: Color(0xFFC8CDD6),
  surfaceDim: Color(0xFF0B0D12),
  surfaceBright: Color(0xFF363942),
  surfaceContainerLowest: Color(0xFF0A0C10),
  surfaceContainerLow: Color(0xFF161A22),
  surfaceContainer: Color(0xFF1A1F28),
  surfaceContainerHigh: Color(0xFF242933),
  surfaceContainerHighest: Color(0xFF2E3440),
  onSurfaceVariant: Color(0xFF949CAA),
  outline: Color(0xFF6B7384),
  outlineVariant: Color(0xFF3A404D),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFFE3E6ED),
  onInverseSurface: Color(0xFF2E3138),
  inversePrimary: kBrandSeedColor,
  surfaceTint: Color(0xFF8BAFE8),
);

/// 依亮度解析最終 [ColorScheme]。
///
/// 淺色優先採用 [dynamicScheme]（系統動態色），否則以 [kBrandSeedColor] fromSeed。
/// 深色固定回傳 [kAppDarkColorScheme]；[dynamicScheme] 會被忽略。
ColorScheme resolveAppColorScheme({
  required Brightness brightness,
  ColorScheme? dynamicScheme,
}) {
  if (brightness == Brightness.light) {
    return dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: kBrandSeedColor,
          brightness: Brightness.light,
        );
  }
  return kAppDarkColorScheme;
}
