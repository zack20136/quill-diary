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

/// accent 為 null 代表中性樣式，否則保留實際選色供邊框及標記使用。
typedef AccentColors = ({Color background, Color foreground, Color? accent});

/// 依表面明暗產生標籤／人物的背景與前景色。
///
/// 淺色維持淡底；深色提高混色比例，避免幾乎全黑的髒底與色盤亮色脫節。
AccentColors accentColorsFor(Color accent, Color surface) {
  final bool isDark =
      ThemeData.estimateBrightnessForColor(surface) == Brightness.dark;
  final Color background = Color.alphaBlend(
    Color.lerp(
      surface,
      accent,
      isDark ? kAccentBackgroundMixDark : kAccentBackgroundMixLight,
    )!,
    surface,
  );
  return (
    background: background,
    foreground: accentForegroundColor(accent, background),
    accent: accent,
  );
}

/// 可選強調色在色盤上的顯示色（完整色值，非 chip 混色背景）。
Color accentSwatchColor(Color accent) => accent.withValues(alpha: 1.0);

/// 強調色實心色塊上的對比前景（勾選圖示等）。
Color accentOnSwatchColor(Color accent) =>
    _contrastingInk(accentSwatchColor(accent));

/// 保留色相，調整字色深淺直到符合一般文字的對比。
Color accentForegroundColor(Color accent, Color background) {
  const minimumContrast = 4.5;
  final base = accent.withValues(alpha: 1);
  if (_contrastRatio(base, background) >= minimumContrast) {
    return base;
  }

  final target = _contrastingInk(background);
  var low = 0.0;
  var high = 1.0;
  for (var i = 0; i < 8; i++) {
    final mix = (low + high) / 2;
    final sample = Color.lerp(base, target, mix)!;
    if (_contrastRatio(sample, background) >= minimumContrast) {
      high = mix;
    } else {
      low = mix;
    }
  }
  return Color.lerp(base, target, high)!;
}

Color _contrastingInk(Color background) =>
    _contrastRatio(Colors.white, background) >=
        _contrastRatio(Colors.black, background)
    ? Colors.white
    : Colors.black;

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = Color.alphaBlend(
    foreground,
    background,
  ).computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  return foregroundLuminance >= backgroundLuminance
      ? (foregroundLuminance + 0.05) / (backgroundLuminance + 0.05)
      : (backgroundLuminance + 0.05) / (foregroundLuminance + 0.05);
}

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

BorderSide? accentChipBorderSide(
  AppColors colors,
  AccentColors accentColors, {
  double width = 0.95,
  double accentBorderAlpha = kAccentBorderAlpha,
}) {
  final accent = accentColors.accent;
  if (accent == null) {
    final Color? neutralBorder = colors.neutralChipBorder;
    return neutralBorder == null
        ? null
        : BorderSide(color: neutralBorder, width: width);
  }
  return BorderSide(
    color: accent.withValues(alpha: accentBorderAlpha),
    width: width,
  );
}
