import 'package:flutter/material.dart';

/// 全 App 字體堆疊與預設墨色（Inter + Noto Sans TC）。
abstract final class AppTypography {
  AppTypography._();

  static const String interFamily = 'Inter';
  static const String notoSansTcFamily = 'NotoSansTC';

  /// 淺色模式預設正文 / 標題色。
  static const Color ink = Color(0xFF000000);

  /// hint、占位、次要說明。
  static Color muted(ColorScheme cs) => cs.onSurfaceVariant;

  /// 套用 Inter + Noto Sans TC 堆疊與預設色。
  static TextTheme textTheme(
    TextTheme base, {
    required Brightness brightness,
    required ColorScheme scheme,
  }) {
    final Color defaultColor =
        brightness == Brightness.light ? ink : scheme.onSurface;
    final TextTheme themed = base.apply(
      bodyColor: defaultColor,
      displayColor: defaultColor,
      fontFamily: interFamily,
      fontFamilyFallback: const <String>[notoSansTcFamily],
    );
    return _mapStyles(themed, defaultColor);
  }

  static TextStyle mono(TextStyle base) {
    return base.copyWith(fontFamily: 'monospace', letterSpacing: 0);
  }

  static TextStyle _stack(TextStyle? style, Color color) {
    return (style ?? const TextStyle()).copyWith(
      color: color,
      fontFamily: interFamily,
      fontFamilyFallback: const <String>[notoSansTcFamily],
      letterSpacing: 0,
    );
  }

  static TextTheme _mapStyles(TextTheme theme, Color color) {
    return theme.copyWith(
      displayLarge: _stack(theme.displayLarge, color),
      displayMedium: _stack(theme.displayMedium, color),
      displaySmall: _stack(theme.displaySmall, color),
      headlineLarge: _stack(theme.headlineLarge, color),
      headlineMedium: _stack(theme.headlineMedium, color),
      headlineSmall: _stack(theme.headlineSmall, color),
      titleLarge: _stack(theme.titleLarge, color),
      titleMedium: _stack(theme.titleMedium, color),
      titleSmall: _stack(theme.titleSmall, color),
      bodyLarge: _stack(theme.bodyLarge, color),
      bodyMedium: _stack(theme.bodyMedium, color),
      bodySmall: _stack(theme.bodySmall, color),
      labelLarge: _stack(theme.labelLarge, color),
      labelMedium: _stack(theme.labelMedium, color),
      labelSmall: _stack(theme.labelSmall, color),
    );
  }
}
