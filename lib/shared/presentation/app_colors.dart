import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/app_color_scheme.dart';

typedef AppCalendarColors = ({
  Color gridLine,
  Color weekday,
  Color day,
  Color entryDay,
  Color selectedDay,
  Color selectedEntryDay,
  Color selectedBorder,
  Color dateForeground,
  Color outsideForeground,
  Color selectedForeground,
  Color sundayForeground,
  Color saturdayForeground,
  AppColorPair todayBadge,
  Color todayBorder,
  Color todayShadow,
  Color entryCard,
});

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.scaffoldBackground,
    required this.sectionCard,
    required this.sectionInset,
    required this.previewPanel,
    required this.dialogSurface,
    required this.menuSurface,
    required this.accentPreviewSurface,
    required this.metricTile,
    required this.metricTileTitle,
    required this.metricTileDetail,
    required this.outlineMuted,
    required this._sectionOutline,
    required this.selectedControl,
    required this.selectedRowFill,
    required this.selectedRowBorder,
    required this.infoFeedback,
    required this.successFeedback,
    required this.warningFeedback,
    required this.errorFeedback,
    required this.calendar,
    required this.diffAdded,
    required this.diffRemoved,
    required this.privateTextHighlight,
    required this.scrim,
    required this.overlayDim,
    required this.shadow,
    required this.inlineCodeBackground,
    required this.galleryBackground,
    required this.galleryForeground,
    required this.neutralChipBorder,
  });

  final Color scaffoldBackground;
  final Color sectionCard;
  final Color sectionInset;
  final Color previewPanel;
  final Color dialogSurface;
  final Color menuSurface;
  final Color accentPreviewSurface;
  final Color metricTile;
  final Color metricTileTitle;
  final Color metricTileDetail;
  final Color outlineMuted;
  final Color _sectionOutline;
  final AppColorPair selectedControl;
  final Color selectedRowFill;
  final Color selectedRowBorder;
  final AppColorPair infoFeedback;
  final AppColorPair successFeedback;
  final AppColorPair warningFeedback;
  final AppColorPair errorFeedback;
  final AppCalendarColors calendar;
  final Color diffAdded;
  final Color diffRemoved;
  final Color privateTextHighlight;
  final Color scrim;
  final Color overlayDim;
  final Color shadow;
  final Color inlineCodeBackground;
  final Color galleryBackground;
  final Color galleryForeground;
  final Color? neutralChipBorder;

  factory AppColors.from(ColorScheme scheme) {
    final bool isLight = scheme.brightness == Brightness.light;
    Color tint(Color color, double alpha, Color surface) =>
        Color.alphaBlend(color.withValues(alpha: alpha), surface);

    final Color scaffoldBackground = isLight
        ? tint(
            scheme.primary,
            0.095,
            tint(scheme.surfaceContainerLow, 0.42, scheme.surface),
          )
        : scheme.surface;
    final Color sectionCard = isLight
        ? scheme.surface
        : scheme.surfaceContainerLow;
    final Color sectionInset = isLight
        ? scheme.surfaceContainerLow
        : scheme.surfaceContainerHigh;
    final Color previewPanel = isLight
        ? tint(
            scheme.surfaceContainerHighest,
            0.2,
            scheme.surface.withValues(alpha: 0.88),
          )
        : scheme.surfaceContainerHigh;
    final AppColorPair selectedControl = (
      background: scheme.primaryContainer,
      foreground: scheme.onPrimaryContainer,
    );
    final Color entryDay = isLight
        ? tint(scheme.primary, 0.08, scheme.surface)
        : sectionCard;
    final Color selectedDay = isLight
        ? tint(scheme.primaryContainer, 0.48, scheme.surface)
        : tint(scheme.primary, 0.16, scheme.surface);
    return AppColors(
      scaffoldBackground: scaffoldBackground,
      sectionCard: sectionCard,
      sectionInset: sectionInset,
      previewPanel: previewPanel,
      dialogSurface: scheme.surfaceContainerHigh,
      menuSurface: isLight
          ? scheme.surfaceContainerLow
          : scheme.surfaceContainer,
      accentPreviewSurface: tint(scheme.primary, 0.04, scheme.surface),
      metricTile: tint(scheme.onSurface, isLight ? 0.03 : 0.04, sectionCard),
      metricTileTitle: scheme.onSurface.withValues(alpha: 0.88),
      metricTileDetail: scheme.onSurfaceVariant.withValues(alpha: 0.82),
      outlineMuted: tint(scheme.primary, 0.14, scheme.outlineVariant),
      sectionOutline: scheme.outlineVariant,
      selectedControl: selectedControl,
      selectedRowFill: tint(scheme.primary, isLight ? 0.08 : 0.14, sectionCard),
      selectedRowBorder: scheme.primary.withValues(alpha: 0.55),
      infoFeedback: selectedControl,
      successFeedback: isLight ? kAppLightSuccessColors : kAppDarkSuccessColors,
      warningFeedback: (
        background: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
      ),
      errorFeedback: (
        background: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
      ),
      calendar: (
        gridLine: scheme.outlineVariant.withValues(alpha: 0.22),
        weekday: isLight
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.45)
            : sectionCard,
        day: scheme.surface,
        entryDay: entryDay,
        selectedDay: selectedDay,
        selectedEntryDay: isLight
            ? tint(scheme.primaryContainer, 0.48, entryDay)
            : selectedDay,
        selectedBorder: scheme.primary.withValues(alpha: isLight ? 0.55 : 0.36),
        dateForeground: scheme.onSurface.withValues(alpha: 0.86),
        outsideForeground: scheme.onSurfaceVariant.withValues(
          alpha: isLight ? 0.82 : 0.70,
        ),
        selectedForeground: scheme.onPrimaryContainer,
        sundayForeground: scheme.error,
        saturdayForeground: isLight
            ? tint(scheme.scrim, 0.12, scheme.primary)
            : scheme.primary,
        todayBadge: isLight
            ? (background: scheme.primary, foreground: scheme.onPrimary)
            : selectedControl,
        todayBorder: scheme.primary.withValues(alpha: isLight ? 0 : 0.48),
        todayShadow: scheme.primary.withValues(alpha: isLight ? 0.28 : 0),
        entryCard: isLight ? sectionInset : scheme.surfaceContainer,
      ),
      diffAdded: isLight ? kAppLightDiffAdded : kAppDarkDiffAdded,
      diffRemoved: isLight ? kAppLightDiffRemoved : kAppDarkDiffRemoved,
      privateTextHighlight: scheme.tertiary.withValues(alpha: 0.32),
      scrim: scheme.scrim.withValues(alpha: isLight ? 0.45 : 0.28),
      overlayDim: scheme.scrim.withValues(alpha: 0.18),
      shadow: scheme.shadow.withValues(alpha: 0.40),
      inlineCodeBackground: scheme.onSurface.withValues(alpha: 0.06),
      galleryBackground: scheme.scrim,
      galleryForeground: Colors.white,
      neutralChipBorder: isLight ? scheme.outlineVariant : null,
    );
  }

  BorderSide outlineBorder({double opacity = 0.34}) =>
      BorderSide(color: _sectionOutline.withValues(alpha: opacity));

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color color(Color a, Color b) => Color.lerp(a, b, t)!;
    AppColorPair pair(AppColorPair a, AppColorPair b) => (
      background: color(a.background, b.background),
      foreground: color(a.foreground, b.foreground),
    );
    return AppColors(
      scaffoldBackground: color(scaffoldBackground, other.scaffoldBackground),
      sectionCard: color(sectionCard, other.sectionCard),
      sectionInset: color(sectionInset, other.sectionInset),
      previewPanel: color(previewPanel, other.previewPanel),
      dialogSurface: color(dialogSurface, other.dialogSurface),
      menuSurface: color(menuSurface, other.menuSurface),
      accentPreviewSurface: color(
        accentPreviewSurface,
        other.accentPreviewSurface,
      ),
      metricTile: color(metricTile, other.metricTile),
      metricTileTitle: color(metricTileTitle, other.metricTileTitle),
      metricTileDetail: color(metricTileDetail, other.metricTileDetail),
      outlineMuted: color(outlineMuted, other.outlineMuted),
      sectionOutline: color(_sectionOutline, other._sectionOutline),
      selectedControl: pair(selectedControl, other.selectedControl),
      selectedRowFill: color(selectedRowFill, other.selectedRowFill),
      selectedRowBorder: color(selectedRowBorder, other.selectedRowBorder),
      infoFeedback: pair(infoFeedback, other.infoFeedback),
      successFeedback: pair(successFeedback, other.successFeedback),
      warningFeedback: pair(warningFeedback, other.warningFeedback),
      errorFeedback: pair(errorFeedback, other.errorFeedback),
      calendar: (
        gridLine: color(calendar.gridLine, other.calendar.gridLine),
        weekday: color(calendar.weekday, other.calendar.weekday),
        day: color(calendar.day, other.calendar.day),
        entryDay: color(calendar.entryDay, other.calendar.entryDay),
        selectedDay: color(calendar.selectedDay, other.calendar.selectedDay),
        selectedEntryDay: color(
          calendar.selectedEntryDay,
          other.calendar.selectedEntryDay,
        ),
        selectedBorder: color(
          calendar.selectedBorder,
          other.calendar.selectedBorder,
        ),
        dateForeground: color(
          calendar.dateForeground,
          other.calendar.dateForeground,
        ),
        outsideForeground: color(
          calendar.outsideForeground,
          other.calendar.outsideForeground,
        ),
        selectedForeground: color(
          calendar.selectedForeground,
          other.calendar.selectedForeground,
        ),
        sundayForeground: color(
          calendar.sundayForeground,
          other.calendar.sundayForeground,
        ),
        saturdayForeground: color(
          calendar.saturdayForeground,
          other.calendar.saturdayForeground,
        ),
        todayBadge: pair(calendar.todayBadge, other.calendar.todayBadge),
        todayBorder: color(calendar.todayBorder, other.calendar.todayBorder),
        todayShadow: color(calendar.todayShadow, other.calendar.todayShadow),
        entryCard: color(calendar.entryCard, other.calendar.entryCard),
      ),
      diffAdded: color(diffAdded, other.diffAdded),
      diffRemoved: color(diffRemoved, other.diffRemoved),
      privateTextHighlight: color(
        privateTextHighlight,
        other.privateTextHighlight,
      ),
      scrim: color(scrim, other.scrim),
      overlayDim: color(overlayDim, other.overlayDim),
      shadow: color(shadow, other.shadow),
      inlineCodeBackground: color(
        inlineCodeBackground,
        other.inlineCodeBackground,
      ),
      galleryBackground: color(galleryBackground, other.galleryBackground),
      galleryForeground: color(galleryForeground, other.galleryForeground),
      neutralChipBorder: t < 0.5 ? neutralChipBorder : other.neutralChipBorder,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
