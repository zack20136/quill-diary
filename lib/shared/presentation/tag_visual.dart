import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../domain/shared/value_objects.dart';
import 'accent_visual.dart';

(Color, Color) tagNeutralAccentPair(ColorScheme scheme) =>
    (scheme.surfaceContainerHighest, scheme.onSurfaceVariant);

(Color, Color) tagCharCountPair(ColorScheme scheme) =>
    tagNeutralAccentPair(scheme);

(Color, Color) tagUnsavedPair(AppColors colors) =>
    accentColorPair(colors.tagUnsavedAccent, colors.sectionInset);

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
  return accentColorPair(Color(argb), colors.sectionInset);
}

bool _tagPairIsNeutral(
  ColorScheme scheme,
  Color background,
  Color foreground,
) =>
    foreground == scheme.onSurfaceVariant &&
    (background == scheme.surfaceContainerHighest ||
        background == scheme.surfaceContainerHigh);

BorderSide? tagBorderSide(
  AppColors colors,
  ColorScheme scheme,
  Color background,
  Color foreground, {
  double width = 0.95,
  double accentBorderAlpha = kAccentBorderAlpha,
}) {
  if (_tagPairIsNeutral(scheme, background, foreground)) {
    final Color? neutralBorder = colors.tagNeutralChipBorder;
    return neutralBorder == null
        ? null
        : BorderSide(color: neutralBorder, width: width);
  }
  return accentBorderSide(
    foreground,
    width: width,
    alpha: accentBorderAlpha,
  );
}
