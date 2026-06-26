import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../domain/shared/value_objects.dart';

const List<Color> kDefaultTagAccentPresets = <Color>[
  Color(0xFF4C6EF5),
  Color(0xFF7950F2),
  Color(0xFFA855F7),
  Color(0xFFD6336C),
  Color(0xFFFF6B6B),
  Color(0xFFF783AC),
  Color(0xFFFF922B),
  Color(0xFFFCC419),
  Color(0xFF51CF66),
  Color(0xFF20C997),
  Color(0xFF15AABF),
  Color(0xFF339AF0),
  Color(0xFF74C0FC),
  Color(0xFFADB5BD),
];

const double kTagChipBorderAlpha = 0.32;

Color _tagTintedBackground(
  Color accent,
  ColorScheme scheme,
  AppColors colors,
) {
  return Color.alphaBlend(
    accent.withValues(alpha: colors.tagAccentBackgroundAlpha),
    scheme.surfaceContainerHigh,
  );
}

Color _tagAccentForeground(Color accent, AppColors colors) {
  if (colors.tagAccentForegroundUseLightenBlend) {
    return Color.lerp(
      accent,
      colors.tagAccentForegroundBlendTarget,
      colors.tagAccentForegroundOnDarkLerp,
    )!;
  }
  final double lerp = accent.computeLuminance() > 0.58
      ? colors.tagAccentForegroundLightHighLerp
      : colors.tagAccentForegroundLightLowLerp;
  return Color.lerp(accent, colors.tagAccentForegroundBlendTarget, lerp)!;
}

(Color, Color) tagNeutralAccentPair(ColorScheme scheme) => (
  scheme.surfaceContainerHighest,
  scheme.onSurfaceVariant,
);

(Color, Color) tagCharCountPair(ColorScheme scheme) =>
    tagNeutralAccentPair(scheme);

(Color, Color) tagUnsavedPair(ColorScheme scheme, AppColors colors) {
  final Color red = colors.tagUnsavedAccent;
  return (_tagTintedBackground(red, scheme, colors), red);
}

(Color, Color) chipFillFromAccentColor(
  Color accent,
  ColorScheme scheme,
  AppColors colors,
) {
  final Color bg = _tagTintedBackground(accent, scheme, colors);
  return (bg, _tagAccentForeground(accent, colors));
}

(Color, Color) tagResolvedAccentPair(
  String label,
  ColorScheme scheme,
  Map<String, int> customArgbByNormalized,
  AppColors colors,
) {
  final int? argb = customArgbByNormalized[normalizeText(label)];
  if (argb == null) {
    return tagNeutralAccentPair(scheme);
  }
  return chipFillFromAccentColor(Color(argb), scheme, colors);
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

bool tagAccentMatchesPreset(Color color) => kDefaultTagAccentPresets.any(
  (Color preset) => colorArgb32(preset) == colorArgb32(color),
);

bool _tagPairIsNeutralMeta(
  ColorScheme scheme,
  Color background,
  Color foreground,
) =>
    foreground == scheme.onSurfaceVariant &&
    (background == scheme.surfaceContainerHighest ||
        background == scheme.surfaceContainerHigh);

Color? tagChipBorderColor(
  AppColors colors,
  ColorScheme scheme,
  Color background,
  Color foreground, {
  double accentBorderAlpha = kTagChipBorderAlpha,
}) {
  if (_tagPairIsNeutralMeta(scheme, background, foreground)) {
    return colors.tagNeutralChipBorder;
  }
  return foreground.withValues(alpha: accentBorderAlpha);
}

BorderSide? tagChipBorderSide(
  AppColors colors,
  ColorScheme scheme,
  Color background,
  Color foreground, {
  double width = 0.95,
  double accentBorderAlpha = kTagChipBorderAlpha,
}) {
  final Color? borderColor = tagChipBorderColor(
    colors,
    scheme,
    background,
    foreground,
    accentBorderAlpha: accentBorderAlpha,
  );
  if (borderColor == null) {
    return null;
  }
  return BorderSide(color: borderColor, width: width);
}

List<int> defaultTagAccentArgbs() =>
    kDefaultTagAccentPresets.map(colorArgb32).toList(growable: false);
