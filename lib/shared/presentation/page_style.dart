import 'package:flutter/material.dart';

/// Shared visual tokens for cards, panels, thumbnails, and layout chrome.
abstract final class PageStyle {
  PageStyle._();

  static const double radiusPanel = 18;
  static const double radiusCard = 20;
  static const double radiusEntry = 22;
  static const double radiusThumbSmall = 12;
  static const double radiusThumb = 14;

  static Color scaffoldWash(ColorScheme cs) => Color.alphaBlend(
        cs.surfaceContainerLow.withValues(alpha: 0.60),
        Color.alphaBlend(cs.primary.withValues(alpha: 0.085), cs.surface),
      );

  static List<Color> homeHeaderTabGradient(ColorScheme cs) => <Color>[
        Color.alphaBlend(cs.primary.withValues(alpha: 0.07), cs.surfaceContainerLow),
        Color.alphaBlend(cs.surfaceContainerLow.withValues(alpha: 0.96), cs.surface),
      ];

  static Color primaryMutedOutline(ColorScheme cs) =>
      Color.alphaBlend(cs.primary.withValues(alpha: 0.14), cs.outlineVariant);

  static BorderSide outlineSide(ColorScheme cs, {double opacity = 0.34}) =>
      BorderSide(color: cs.outlineVariant.withValues(alpha: opacity));

  static Color previewPanelFill(ColorScheme cs) => Color.alphaBlend(
        cs.surfaceContainerHighest.withValues(alpha: 0.2),
        cs.surface.withValues(alpha: 0.88),
      );
}
