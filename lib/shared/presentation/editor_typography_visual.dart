import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';

extension EditorTypographyVisual on EditorTypographyPreferences {
  TextStyle titleTextStyle(
    TextTheme textTheme, {
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) {
    return (textTheme.titleLarge ?? const TextStyle()).copyWith(
      fontSize: titleFontSize,
      height: titleLineHeight,
      fontWeight: fontWeight,
      color: color,
    );
  }

  TextStyle bodyTextStyle(
    TextTheme textTheme, {
    Color? color,
    FontStyle? fontStyle,
  }) {
    return (textTheme.bodyLarge ?? const TextStyle()).copyWith(
      fontSize: bodyFontSize,
      height: bodyLineHeight,
      color: color,
      fontStyle: fontStyle,
    );
  }

  /// 首頁列表標題：以原本 `titleMedium` 為基準，依編輯器標題偏好等比縮放。
  TextStyle listTitleTextStyle(TextTheme textTheme) {
    final TextStyle base = textTheme.titleMedium ?? const TextStyle();
    return base.copyWith(
      fontSize: _scale(
        base.fontSize ?? EditorTypographyPreferences.defaultListTitleFontSize,
        titleFontSize,
        EditorTypographyPreferences.defaultTitleFontSize,
      ),
      height: _scale(
        base.height ?? EditorTypographyPreferences.defaultListTitleLineHeight,
        titleLineHeight,
        EditorTypographyPreferences.defaultTitleLineHeight,
      ),
      fontWeight: FontWeight.w700,
    );
  }

  /// 首頁列表摘要：以原本 `bodyMedium` + `height: 1.4` 為基準。
  TextStyle listPreviewTextStyle(TextTheme textTheme, {Color? color}) {
    final TextStyle base = textTheme.bodyMedium ?? const TextStyle();
    return base.copyWith(
      fontSize: _scale(
        base.fontSize ?? EditorTypographyPreferences.defaultListPreviewFontSize,
        bodyFontSize,
        EditorTypographyPreferences.defaultBodyFontSize,
      ),
      height: _scale(
        EditorTypographyPreferences.defaultListPreviewLineHeight,
        bodyLineHeight,
        EditorTypographyPreferences.defaultBodyLineHeight,
      ),
      color: color,
    );
  }

  /// 精簡列表摘要：以原本 `bodySmall` + `height: 1.45` 為基準。
  TextStyle listCompactPreviewTextStyle(TextTheme textTheme, {Color? color}) {
    final TextStyle base = textTheme.bodySmall ?? const TextStyle();
    return base.copyWith(
      fontSize: _scale(
        base.fontSize ?? 12,
        bodyFontSize,
        EditorTypographyPreferences.defaultBodyFontSize,
      ),
      height: _scale(
        EditorTypographyPreferences.defaultListCompactPreviewLineHeight,
        bodyLineHeight,
        EditorTypographyPreferences.defaultBodyLineHeight,
      ),
      color: color,
    );
  }

  static double _scale(
    double base,
    double preference,
    double preferenceDefault,
  ) {
    return base * (preference / preferenceDefault);
  }
}
