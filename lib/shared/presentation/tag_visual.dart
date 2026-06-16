import 'package:flutter/material.dart';

import '../../domain/shared/value_objects.dart';

const List<Color> kEditorTagAccentPresets = <Color>[
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

(Color, Color) tagNeutralAccentPair(ColorScheme scheme) {
  return (
    Color.alphaBlend(
      scheme.outline.withValues(alpha: 0.12),
      scheme.surfaceContainerHighest,
    ),
    scheme.onSurfaceVariant,
  );
}

(Color, Color) chipFillFromAccentColor(Color accent, ColorScheme scheme) {
  final Color bg = Color.alphaBlend(
    accent.withValues(alpha: 0.32),
    scheme.surfaceContainerHigh,
  );
  final double lum = bg.computeLuminance();
  final Color fg = lum > 0.54
      ? Color.alphaBlend(
          Colors.black.withValues(alpha: 0.78),
          accent,
        ).withValues(alpha: 1)
      : Color.alphaBlend(
          Colors.white.withValues(alpha: 0.95),
          accent,
        ).withValues(alpha: 1);
  return (bg, fg);
}

(Color, Color) tagResolvedAccentPair(
  String label,
  ColorScheme scheme,
  Map<String, int> customArgbByNormalized,
) {
  final String nk = normalizeText(label);
  if (nk.isEmpty) {
    return tagNeutralAccentPair(scheme);
  }
  final int? argb = customArgbByNormalized[nk];
  if (argb == null) {
    return tagNeutralAccentPair(scheme);
  }
  return chipFillFromAccentColor(Color(argb), scheme);
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
