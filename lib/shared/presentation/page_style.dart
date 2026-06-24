import 'package:flutter/material.dart';

/// 卡片、面板、縮圖與版面裝飾共用的視覺 token。
abstract final class PageStyle {
  PageStyle._();

  static const double radiusPanel = 18;
  static const double radiusCard = 20;
  static const double radiusEntry = 22;
  static const double radiusThumbSmall = 12;
  static const double radiusThumb = 14;

  /// 全站頁面底色（介於 [ColorScheme.surface] 與 [ColorScheme.surfaceContainerLow] 之間）。
  static Color scaffoldWash(ColorScheme cs) {
    final bool isLight = cs.brightness == Brightness.light;
    if (!isLight) {
      return Color.alphaBlend(
        cs.primary.withValues(alpha: 0.04),
        Color.alphaBlend(
          cs.surfaceContainerLow.withValues(alpha: 0.55),
          cs.surface,
        ),
      );
    }
    final Color base = Color.alphaBlend(
      cs.surfaceContainerLow.withValues(alpha: 0.42),
      cs.surface,
    );
    return Color.alphaBlend(cs.primary.withValues(alpha: 0.095), base);
  }

  static List<Color> homeHeaderTabGradient(ColorScheme cs) => <Color>[
    Color.alphaBlend(
      cs.primary.withValues(alpha: 0.07),
      cs.surfaceContainerLow,
    ),
    scaffoldWash(cs),
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
