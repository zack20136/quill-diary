import 'package:flutter/material.dart';

/// App 語意色彩 token，由 [ColorScheme] 在 [buildAppTheme] 時一次性預算。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.scaffoldBackground,
    required this.sectionCard,
    required this.sectionInset,
    required this.previewPanel,
    required this.metricTile,
    required this.metricTileTitle,
    required this.metricTileDetail,
    required this.metricTileValue,
    required this.foreground,
    required this.mutedForeground,
    required this.outlineMuted,
    required this.outlineVariant,
    required this.calendarGridLine,
    required this.accentDialogGradientStart,
    required this.accentDialogGradientEnd,
    required this.accentDialogBorder,
    required this.heroGradientStart,
    required this.heroGradientEnd,
    required this.healthOkFill,
    required this.healthWarningFill,
    required this.healthErrorFill,
    required this.healthOkForeground,
    required this.healthWarningForeground,
    required this.healthErrorForeground,
    required this.entrySelectedBorder,
    required this.calendarTodayMarker,
    required this.scrim,
    required this.overlayDim,
    required this.shadow,
    required this.inlineCodeBackground,
    required this.galleryBackground,
    required this.galleryForeground,
    required this.tagAccentBackgroundAlpha,
    required this.tagAccentForegroundUseLightenBlend,
    required this.tagAccentForegroundBlendTarget,
    required this.tagAccentForegroundOnDarkLerp,
    required this.tagAccentForegroundLightHighLerp,
    required this.tagAccentForegroundLightLowLerp,
    required this.tagNeutralChipBorder,
    required this.tagUnsavedAccent,
  });

  final Color scaffoldBackground;
  final Color sectionCard;
  final Color sectionInset;
  final Color previewPanel;
  final Color metricTile;
  final Color metricTileTitle;
  final Color metricTileDetail;
  final Color metricTileValue;
  final Color foreground;
  final Color mutedForeground;
  final Color outlineMuted;
  final Color outlineVariant;
  final Color calendarGridLine;
  final Color accentDialogGradientStart;
  final Color accentDialogGradientEnd;
  final Color accentDialogBorder;
  final Color heroGradientStart;
  final Color heroGradientEnd;
  final Color healthOkFill;
  final Color healthWarningFill;
  final Color healthErrorFill;
  final Color healthOkForeground;
  final Color healthWarningForeground;
  final Color healthErrorForeground;
  final Color entrySelectedBorder;
  final Color calendarTodayMarker;
  final Color scrim;
  final Color overlayDim;
  final Color shadow;
  final Color inlineCodeBackground;
  final Color galleryBackground;
  final Color galleryForeground;
  final double tagAccentBackgroundAlpha;
  final bool tagAccentForegroundUseLightenBlend;
  final Color tagAccentForegroundBlendTarget;
  final double tagAccentForegroundOnDarkLerp;
  final double tagAccentForegroundLightHighLerp;
  final double tagAccentForegroundLightLowLerp;
  final Color? tagNeutralChipBorder;
  final Color tagUnsavedAccent;

  factory AppColors.from(ColorScheme scheme) {
    final bool isLight = scheme.brightness == Brightness.light;

    final Color scaffoldBackground = isLight
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.095),
            Color.alphaBlend(
              scheme.surfaceContainerLow.withValues(alpha: 0.42),
              scheme.surface,
            ),
          )
        : Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.04),
            Color.alphaBlend(
              scheme.surfaceContainerLow.withValues(alpha: 0.55),
              scheme.surface,
            ),
          );

    final Color sectionCard = scheme.surface;
    final Color sectionInset = isLight
        ? scheme.surfaceContainerLow
        : Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.06),
            scheme.surfaceContainer,
          );
    final Color previewPanel = Color.alphaBlend(
      scheme.surfaceContainerHighest.withValues(alpha: 0.2),
      scheme.surface.withValues(alpha: 0.88),
    );
    final Color metricTile = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: isLight ? 0.03 : 0.04),
      sectionCard,
    );

    return AppColors(
      scaffoldBackground: scaffoldBackground,
      sectionCard: sectionCard,
      sectionInset: sectionInset,
      previewPanel: previewPanel,
      metricTile: metricTile,
      metricTileTitle: scheme.onSurface.withValues(alpha: 0.88),
      metricTileDetail: scheme.onSurfaceVariant.withValues(alpha: 0.82),
      metricTileValue: scheme.onSurface,
      foreground: scheme.onSurface,
      mutedForeground: scheme.onSurfaceVariant,
      outlineMuted: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.14),
        scheme.outlineVariant,
      ),
      outlineVariant: scheme.outlineVariant,
      calendarGridLine: scheme.outlineVariant.withValues(alpha: 0.22),
      accentDialogGradientStart:
          Color.lerp(scheme.primary, scheme.surface, 0.92)!,
      accentDialogGradientEnd: scheme.surface,
      accentDialogBorder: scheme.primary.withValues(alpha: 0.14),
      heroGradientStart: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.12),
        scheme.surface,
      ),
      heroGradientEnd: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.08),
        scheme.surfaceContainerLow,
      ),
      healthOkFill: isLight
          ? scheme.surfaceContainerHigh
          : Color.alphaBlend(
              scheme.primary.withValues(alpha: 0.06),
              scheme.surfaceContainer,
            ),
      healthWarningFill: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.12),
        isLight ? scheme.surfaceContainerHigh : scheme.surfaceContainer,
      ),
      healthErrorFill: Color.alphaBlend(
        scheme.error.withValues(alpha: 0.10),
        isLight ? scheme.surfaceContainerHigh : scheme.surfaceContainer,
      ),
      healthOkForeground: scheme.onSurface,
      healthWarningForeground: scheme.onSurface,
      healthErrorForeground: scheme.onErrorContainer,
      entrySelectedBorder: scheme.primary.withValues(alpha: 0.72),
      calendarTodayMarker: scheme.primary.withValues(alpha: 0.55),
      scrim: scheme.scrim.withValues(alpha: 0.45),
      overlayDim: scheme.scrim.withValues(alpha: 0.18),
      shadow: scheme.shadow.withValues(alpha: 0.40),
      inlineCodeBackground: scheme.onSurface.withValues(alpha: 0.06),
      galleryBackground: scheme.scrim,
      galleryForeground: scheme.surface,
      tagAccentBackgroundAlpha: isLight ? 0.12 : 0.24,
      tagAccentForegroundUseLightenBlend: !isLight,
      tagAccentForegroundBlendTarget:
          isLight ? const Color(0xFF121212) : const Color(0xFFFFFFFF),
      tagAccentForegroundOnDarkLerp: 0.26,
      tagAccentForegroundLightHighLerp: 0.44,
      tagAccentForegroundLightLowLerp: 0.20,
      tagNeutralChipBorder: isLight ? scheme.outlineVariant : null,
      tagUnsavedAccent: scheme.error,
    );
  }

  BorderSide outlineBorder({double opacity = 0.34}) =>
      BorderSide(color: outlineVariant.withValues(alpha: opacity));

  @override
  AppColors copyWith({
    Color? scaffoldBackground,
    Color? sectionCard,
    Color? sectionInset,
    Color? previewPanel,
    Color? metricTile,
    Color? metricTileTitle,
    Color? metricTileDetail,
    Color? metricTileValue,
    Color? foreground,
    Color? mutedForeground,
    Color? outlineMuted,
    Color? outlineVariant,
    Color? calendarGridLine,
    Color? accentDialogGradientStart,
    Color? accentDialogGradientEnd,
    Color? accentDialogBorder,
    Color? heroGradientStart,
    Color? heroGradientEnd,
    Color? healthOkFill,
    Color? healthWarningFill,
    Color? healthErrorFill,
    Color? healthOkForeground,
    Color? healthWarningForeground,
    Color? healthErrorForeground,
    Color? entrySelectedBorder,
    Color? calendarTodayMarker,
    Color? scrim,
    Color? overlayDim,
    Color? shadow,
    Color? inlineCodeBackground,
    Color? galleryBackground,
    Color? galleryForeground,
    double? tagAccentBackgroundAlpha,
    bool? tagAccentForegroundUseLightenBlend,
    Color? tagAccentForegroundBlendTarget,
    double? tagAccentForegroundOnDarkLerp,
    double? tagAccentForegroundLightHighLerp,
    double? tagAccentForegroundLightLowLerp,
    Color? tagNeutralChipBorder,
    Color? tagUnsavedAccent,
  }) {
    return AppColors(
      scaffoldBackground: scaffoldBackground ?? this.scaffoldBackground,
      sectionCard: sectionCard ?? this.sectionCard,
      sectionInset: sectionInset ?? this.sectionInset,
      previewPanel: previewPanel ?? this.previewPanel,
      metricTile: metricTile ?? this.metricTile,
      metricTileTitle: metricTileTitle ?? this.metricTileTitle,
      metricTileDetail: metricTileDetail ?? this.metricTileDetail,
      metricTileValue: metricTileValue ?? this.metricTileValue,
      foreground: foreground ?? this.foreground,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      outlineMuted: outlineMuted ?? this.outlineMuted,
      outlineVariant: outlineVariant ?? this.outlineVariant,
      calendarGridLine: calendarGridLine ?? this.calendarGridLine,
      accentDialogGradientStart:
          accentDialogGradientStart ?? this.accentDialogGradientStart,
      accentDialogGradientEnd:
          accentDialogGradientEnd ?? this.accentDialogGradientEnd,
      accentDialogBorder: accentDialogBorder ?? this.accentDialogBorder,
      heroGradientStart: heroGradientStart ?? this.heroGradientStart,
      heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
      healthOkFill: healthOkFill ?? this.healthOkFill,
      healthWarningFill: healthWarningFill ?? this.healthWarningFill,
      healthErrorFill: healthErrorFill ?? this.healthErrorFill,
      healthOkForeground: healthOkForeground ?? this.healthOkForeground,
      healthWarningForeground:
          healthWarningForeground ?? this.healthWarningForeground,
      healthErrorForeground: healthErrorForeground ?? this.healthErrorForeground,
      entrySelectedBorder: entrySelectedBorder ?? this.entrySelectedBorder,
      calendarTodayMarker: calendarTodayMarker ?? this.calendarTodayMarker,
      scrim: scrim ?? this.scrim,
      overlayDim: overlayDim ?? this.overlayDim,
      shadow: shadow ?? this.shadow,
      inlineCodeBackground: inlineCodeBackground ?? this.inlineCodeBackground,
      galleryBackground: galleryBackground ?? this.galleryBackground,
      galleryForeground: galleryForeground ?? this.galleryForeground,
      tagAccentBackgroundAlpha:
          tagAccentBackgroundAlpha ?? this.tagAccentBackgroundAlpha,
      tagAccentForegroundUseLightenBlend: tagAccentForegroundUseLightenBlend ??
          this.tagAccentForegroundUseLightenBlend,
      tagAccentForegroundBlendTarget: tagAccentForegroundBlendTarget ??
          this.tagAccentForegroundBlendTarget,
      tagAccentForegroundOnDarkLerp:
          tagAccentForegroundOnDarkLerp ?? this.tagAccentForegroundOnDarkLerp,
      tagAccentForegroundLightHighLerp: tagAccentForegroundLightHighLerp ??
          this.tagAccentForegroundLightHighLerp,
      tagAccentForegroundLightLowLerp: tagAccentForegroundLightLowLerp ??
          this.tagAccentForegroundLightLowLerp,
      tagNeutralChipBorder: tagNeutralChipBorder ?? this.tagNeutralChipBorder,
      tagUnsavedAccent: tagUnsavedAccent ?? this.tagUnsavedAccent,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    Color? lerpColor(Color a, Color b) => Color.lerp(a, b, t);
    return AppColors(
      scaffoldBackground:
          lerpColor(scaffoldBackground, other.scaffoldBackground)!,
      sectionCard: lerpColor(sectionCard, other.sectionCard)!,
      sectionInset: lerpColor(sectionInset, other.sectionInset)!,
      previewPanel: lerpColor(previewPanel, other.previewPanel)!,
      metricTile: lerpColor(metricTile, other.metricTile)!,
      metricTileTitle: lerpColor(metricTileTitle, other.metricTileTitle)!,
      metricTileDetail: lerpColor(metricTileDetail, other.metricTileDetail)!,
      metricTileValue: lerpColor(metricTileValue, other.metricTileValue)!,
      foreground: lerpColor(foreground, other.foreground)!,
      mutedForeground: lerpColor(mutedForeground, other.mutedForeground)!,
      outlineMuted: lerpColor(outlineMuted, other.outlineMuted)!,
      outlineVariant: lerpColor(outlineVariant, other.outlineVariant)!,
      calendarGridLine: lerpColor(calendarGridLine, other.calendarGridLine)!,
      accentDialogGradientStart: lerpColor(
        accentDialogGradientStart,
        other.accentDialogGradientStart,
      )!,
      accentDialogGradientEnd:
          lerpColor(accentDialogGradientEnd, other.accentDialogGradientEnd)!,
      accentDialogBorder: lerpColor(accentDialogBorder, other.accentDialogBorder)!,
      heroGradientStart: lerpColor(heroGradientStart, other.heroGradientStart)!,
      heroGradientEnd: lerpColor(heroGradientEnd, other.heroGradientEnd)!,
      healthOkFill: lerpColor(healthOkFill, other.healthOkFill)!,
      healthWarningFill: lerpColor(healthWarningFill, other.healthWarningFill)!,
      healthErrorFill: lerpColor(healthErrorFill, other.healthErrorFill)!,
      healthOkForeground:
          lerpColor(healthOkForeground, other.healthOkForeground)!,
      healthWarningForeground: lerpColor(
        healthWarningForeground,
        other.healthWarningForeground,
      )!,
      healthErrorForeground:
          lerpColor(healthErrorForeground, other.healthErrorForeground)!,
      entrySelectedBorder:
          lerpColor(entrySelectedBorder, other.entrySelectedBorder)!,
      calendarTodayMarker:
          lerpColor(calendarTodayMarker, other.calendarTodayMarker)!,
      scrim: lerpColor(scrim, other.scrim)!,
      overlayDim: lerpColor(overlayDim, other.overlayDim)!,
      shadow: lerpColor(shadow, other.shadow)!,
      inlineCodeBackground:
          lerpColor(inlineCodeBackground, other.inlineCodeBackground)!,
      galleryBackground: lerpColor(galleryBackground, other.galleryBackground)!,
      galleryForeground: lerpColor(galleryForeground, other.galleryForeground)!,
      tagAccentBackgroundAlpha: t < 0.5
          ? tagAccentBackgroundAlpha
          : other.tagAccentBackgroundAlpha,
      tagAccentForegroundUseLightenBlend: t < 0.5
          ? tagAccentForegroundUseLightenBlend
          : other.tagAccentForegroundUseLightenBlend,
      tagAccentForegroundBlendTarget: lerpColor(
        tagAccentForegroundBlendTarget,
        other.tagAccentForegroundBlendTarget,
      )!,
      tagAccentForegroundOnDarkLerp: t < 0.5
          ? tagAccentForegroundOnDarkLerp
          : other.tagAccentForegroundOnDarkLerp,
      tagAccentForegroundLightHighLerp: t < 0.5
          ? tagAccentForegroundLightHighLerp
          : other.tagAccentForegroundLightHighLerp,
      tagAccentForegroundLightLowLerp: t < 0.5
          ? tagAccentForegroundLightLowLerp
          : other.tagAccentForegroundLightLowLerp,
      tagNeutralChipBorder: t < 0.5
          ? tagNeutralChipBorder
          : other.tagNeutralChipBorder,
      tagUnsavedAccent: lerpColor(tagUnsavedAccent, other.tagUnsavedAccent)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  ColorScheme get appColorScheme => Theme.of(this).colorScheme;

  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
