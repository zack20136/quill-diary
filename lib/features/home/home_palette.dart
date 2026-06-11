import 'package:flutter/material.dart';

/// 首頁概覽統計卡片的色票。
abstract final class HomePalette {
  static Color metricTileFill(ColorScheme cs) {
    final Color fillBase = Color.alphaBlend(
      cs.primary.withValues(alpha: 0.08),
      cs.surfaceContainerLow,
    );
    return Color.alphaBlend(
      cs.onSurface.withValues(alpha: 0.04),
      Color.alphaBlend(cs.surface, fillBase),
    );
  }

  static Color metricTileTitle(ColorScheme cs) =>
      cs.onSurface.withValues(alpha: 0.88);

  static Color metricTileDetail(ColorScheme cs) =>
      cs.onSurfaceVariant.withValues(alpha: 0.82);

  static Color metricTileValue(ColorScheme cs) => cs.onSurface;
}
