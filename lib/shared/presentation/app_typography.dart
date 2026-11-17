import 'package:material_ui/material_ui.dart';

/// 全 App 文字樣式與預設墨色；字型沿用各平台系統字，不另外打包。
abstract final class AppTypography {
  AppTypography._();

  static TextTheme textTheme(TextTheme base, {required Color defaultColor}) {
    final TextTheme themed = base.apply(
      bodyColor: defaultColor,
      displayColor: defaultColor,
    );
    return _mapStyles(themed, defaultColor);
  }

  static TextStyle mono(TextStyle base) {
    return base.copyWith(fontFamily: 'monospace', letterSpacing: 0);
  }

  static TextStyle _withDefaultColor(TextStyle? style, Color color) {
    return (style ?? const TextStyle()).copyWith(
      color: color,
      letterSpacing: 0,
    );
  }

  static TextTheme _mapStyles(TextTheme theme, Color color) {
    return theme.copyWith(
      displayLarge: _withDefaultColor(theme.displayLarge, color),
      displayMedium: _withDefaultColor(theme.displayMedium, color),
      displaySmall: _withDefaultColor(theme.displaySmall, color),
      headlineLarge: _withDefaultColor(theme.headlineLarge, color),
      headlineMedium: _withDefaultColor(theme.headlineMedium, color),
      headlineSmall: _withDefaultColor(theme.headlineSmall, color),
      titleLarge: _withDefaultColor(theme.titleLarge, color),
      titleMedium: _withDefaultColor(theme.titleMedium, color),
      titleSmall: _withDefaultColor(theme.titleSmall, color),
      bodyLarge: _withDefaultColor(theme.bodyLarge, color),
      bodyMedium: _withDefaultColor(theme.bodyMedium, color),
      bodySmall: _withDefaultColor(theme.bodySmall, color),
      labelLarge: _withDefaultColor(theme.labelLarge, color),
      labelMedium: _withDefaultColor(theme.labelMedium, color),
      labelSmall: _withDefaultColor(theme.labelSmall, color),
    );
  }
}
