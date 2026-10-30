import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/shared/accent_palette.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';

/// 人物與標籤共用的可選強調色盤。
final List<Color> accentColorPresets = List<Color>.unmodifiable(
  accentArgbPresets.map(Color.new),
);

const double kAccentBackgroundMixLight = 0.16;
const double kAccentBackgroundMixDark = 0.42;
const double kAccentBorderAlpha = 0.32;

/// 依表面明暗產生標籤／人物的背景與前景色。
///
/// 淺色維持淡底；深色提高混色比例，避免幾乎全黑的髒底與色盤亮色脫節。
(Color, Color) accentColorPair(Color accent, Color surface) {
  final bool isDark =
      ThemeData.estimateBrightnessForColor(surface) == Brightness.dark;
  final Color background = Color.lerp(
    surface,
    accent,
    isDark ? kAccentBackgroundMixDark : kAccentBackgroundMixLight,
  )!;
  return (background, accent);
}

/// 可選強調色在色盤上的顯示色（完整色值，非 chip 混色背景）。
Color accentSwatchColor(Color accent) => accent.withValues(alpha: 1.0);

/// 強調色實心色塊上的對比前景（勾選圖示等）。
Color accentOnSwatchColor(Color accent) =>
    ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
    ? Colors.white
    : const Color(0xDE000000);

Color accentBorderColor(Color accent, {double alpha = kAccentBorderAlpha}) =>
    accent.withValues(alpha: alpha);

BorderSide accentBorderSide(
  Color accent, {
  double width = 0.95,
  double alpha = kAccentBorderAlpha,
}) => BorderSide(
  color: accentBorderColor(accent, alpha: alpha),
  width: width,
);

int colorArgb32(Color color) {
  final double a = (color.a.isFinite ? color.a : 1.0).clamp(0.0, 1.0);
  final double r = (color.r.isFinite ? color.r : 0.0).clamp(0.0, 1.0);
  final double g = (color.g.isFinite ? color.g : 0.0).clamp(0.0, 1.0);
  final double b = (color.b.isFinite ? color.b : 0.0).clamp(0.0, 1.0);
  return (((a * 255.0).round() & 0xff) << 24) |
      (((r * 255.0).round() & 0xff) << 16) |
      (((g * 255.0).round() & 0xff) << 8) |
      ((b * 255.0).round() & 0xff);
}

bool accentMatchesPreset(Color color) => accentColorPresets.any(
  (Color preset) => colorArgb32(preset) == colorArgb32(color),
);

Color accentColorForStableKey(String key) {
  if (key.isEmpty) {
    return accentColorPresets.first;
  }
  final int hash = key.codeUnits.fold<int>(
    0,
    (int acc, int unit) => (acc * 31 + unit) & 0x7fffffff,
  );
  return accentColorPresets[hash % accentColorPresets.length];
}

bool _accentPairIsNeutral(
  ColorScheme scheme,
  Color background,
  Color foreground,
) =>
    foreground == scheme.onSurfaceVariant &&
    (background == scheme.surfaceContainerHighest ||
        background == scheme.surfaceContainerHigh);

BorderSide? accentChipBorderSide(
  AppColors colors,
  ColorScheme scheme,
  Color background,
  Color foreground, {
  double width = 0.95,
  double accentBorderAlpha = kAccentBorderAlpha,
}) {
  if (_accentPairIsNeutral(scheme, background, foreground)) {
    final Color? neutralBorder = colors.tagNeutralChipBorder;
    return neutralBorder == null
        ? null
        : BorderSide(color: neutralBorder, width: width);
  }
  return accentBorderSide(foreground, width: width, alpha: accentBorderAlpha);
}
