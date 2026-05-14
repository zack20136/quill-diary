import 'package:flutter/material.dart';

/// Shared visual tokens for [HomePage], [EditorPage], [SettingsPage].
/// Aligned with app theme: Flex `defaultRadius` 18 and `card` 20 ([buildAppTheme]).
abstract final class PageStyle {
  PageStyle._();

  /// Panels, banners, thumbnail shells.
  static const double radiusPanel = 18;

  /// Primary cards / section shells / search field.
  static const double radiusCard = 20;

  /// Diary row shell (non-tinted list cards).
  static const double radiusEntry = 22;

  /// Diary row preview thumbnails (home).
  static const double radiusThumbSmall = 12;

  /// Editor attachment chips / preview thumbnails.
  static const double radiusThumb = 14;
  static Color scaffoldWash(ColorScheme cs) => Color.alphaBlend(
        cs.surfaceContainerLow.withValues(alpha: 0.42),
        Color.alphaBlend(cs.primary.withValues(alpha: 0.055), cs.surface),
      );

  /// Home header tab strip gradient.
  static List<Color> homeHeaderTabGradient(ColorScheme cs) => <Color>[
        Color.alphaBlend(cs.primary.withValues(alpha: 0.07), cs.surfaceContainerLow),
        Color.alphaBlend(cs.surfaceContainerLow.withValues(alpha: 0.96), cs.surface),
      ];

  /// Inputs and soft dividers: primary tint over outline.
  static Color primaryMutedOutline(ColorScheme cs) =>
      Color.alphaBlend(cs.primary.withValues(alpha: 0.14), cs.outlineVariant);

  static BorderSide outlineSide(ColorScheme cs, {double opacity = 0.34}) =>
      BorderSide(color: cs.outlineVariant.withValues(alpha: opacity));

  /// Editor preview body panel.
  static Color previewPanelFill(ColorScheme cs) => Color.alphaBlend(
        cs.surfaceContainerHighest.withValues(alpha: 0.2),
        cs.surface.withValues(alpha: 0.88),
      );
}
