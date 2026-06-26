import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../domain/shared/value_objects.dart';

/// 色盤快速選色（20 色，涵蓋全色相；柔和飽和、貼近 App 冷灰藍調）。
const List<Color> kDefaultTagAccentPresets = <Color>[
  Color(0xFFBF6760), // 紅
  Color(0xFFC47A88), // 玫紅
  Color(0xFFCC8A98), // 粉
  Color(0xFFCC8C74), // 珊瑚
  Color(0xFFCC9A5E), // 橘
  Color(0xFFC4A256), // 琥珀
  Color(0xFFB0A262), // 金黃
  Color(0xFF8EAA6A), // 黃綠
  Color(0xFF62A87C), // 綠
  Color(0xFF54A890), // 翠綠
  Color(0xFF4EA196), // 青綠
  Color(0xFF559AAC), // 青
  Color(0xFF5C94B8), // 天藍
  Color(0xFF5480B0), // 藍
  Color(0xFF6874B0), // 靛
  Color(0xFF786CB0), // 紫
  Color(0xFF8C66AC), // 深紫
  Color(0xFFA666A0), // 洋紅
  Color(0xFF968876), // 褐
  Color(0xFF748494), // 灰藍
];

/// 預設標籤目錄專用強調色；索引須與 [localizedDefaultTagLabels] 一致。
/// 針對 chip 淺色 12% / 深色 24% alpha blend 調校，不必落在 [kDefaultTagAccentPresets]。
const List<Color> kDefaultTagCatalogAccents = <Color>[
  // 0 defaultTagDaily — 日常
  Color(0xFF8A7E70),
  // 1 defaultTagMood — 心情
  Color(0xFF9C6888),
  // 2 defaultTagTakeaways — 心得
  Color(0xFF3A8A80),
  // 3 defaultTagNotes — 筆記
  Color(0xFF4C6E98),
  // 4 defaultTagReflection — 反思
  Color(0xFF605C9C),
  // 5 defaultTagIdeas — 靈感
  Color(0xFFB08844),
  // 6 defaultTagPlans — 計畫
  Color(0xFF4470A8),
  // 7 defaultTagGoals — 目標
  Color(0xFFAE6048),
  // 8 defaultTagWork — 工作
  Color(0xFF5A6878),
  // 9 defaultTagLearning — 學習
  Color(0xFF388A5E),
  // 10 defaultTagRelationships — 人際
  Color(0xFFA06878),
  // 11 defaultTagFamily — 家庭
  Color(0xFFB07850),
  // 12 defaultTagHealth — 健康
  Color(0xFF449872),
  // 13 defaultTagGratitude — 感謝
  Color(0xFF988848),
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

List<int> defaultTagCatalogAccentArgbs() =>
    kDefaultTagCatalogAccents.map(colorArgb32).toList(growable: false);
