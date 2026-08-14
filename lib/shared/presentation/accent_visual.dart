import 'package:flutter/material.dart';

/// 人物與標籤共用的可選強調色盤。
const List<Color> kAccentColorPresets = <Color>[
  Color(0xFFBF6760),
  Color(0xFFC47A88),
  Color(0xFFCC8A98),
  Color(0xFFCC8C74),
  Color(0xFFCC9A5E),
  Color(0xFFC4A256),
  Color(0xFFB0A262),
  Color(0xFF8EAA6A),
  Color(0xFF62A87C),
  Color(0xFF54A890),
  Color(0xFF4EA196),
  Color(0xFF559AAC),
  Color(0xFF5C94B8),
  Color(0xFF5480B0),
  Color(0xFF6874B0),
  Color(0xFF786CB0),
  Color(0xFF8C66AC),
  Color(0xFFA666A0),
  Color(0xFF968876),
  Color(0xFF748494),
];

const double kAccentBackgroundAlpha = 0.18;
const double kAccentBorderAlpha = 0.32;

(Color, Color) accentColorPair(Color accent, Color surface) => (
  Color.alphaBlend(
    accent.withValues(alpha: kAccentBackgroundAlpha),
    surface,
  ),
  accent,
);

Color accentBorderColor(
  Color accent, {
  double alpha = kAccentBorderAlpha,
}) => accent.withValues(alpha: alpha);

BorderSide accentBorderSide(
  Color accent, {
  double width = 0.95,
  double alpha = kAccentBorderAlpha,
}) => BorderSide(color: accentBorderColor(accent, alpha: alpha), width: width);

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

bool accentMatchesPreset(Color color) => kAccentColorPresets.any(
  (Color preset) => colorArgb32(preset) == colorArgb32(color),
);

Color accentColorForStableKey(String key) {
  if (key.isEmpty) {
    return kAccentColorPresets.first;
  }
  final int hash = key.codeUnits.fold<int>(
    0,
    (int acc, int unit) => (acc * 31 + unit) & 0x7fffffff,
  );
  return kAccentColorPresets[hash % kAccentColorPresets.length];
}
