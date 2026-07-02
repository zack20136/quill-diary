import 'package:flutter/material.dart';

/// 編輯器標題與內文的排版偏好（字體大小、行距、段落間距）。
class EditorTypographyPreferences {
  const EditorTypographyPreferences({
    required this.titleFontSize,
    required this.titleLineHeight,
    required this.bodyFontSize,
    required this.bodyLineHeight,
    required this.bodyParagraphSpacing,
  });

  static const double defaultTitleFontSize = 22;
  static const double defaultTitleLineHeight = 1.25;
  static const double defaultBodyFontSize = 16;
  static const double defaultBodyLineHeight = 1.75;
  static const double defaultBodyParagraphSpacing = 8;

  /// 首頁列表標題原始為 [TextTheme.titleMedium]。
  static const double defaultListTitleFontSize = 16;
  static const double defaultListTitleLineHeight = 1.5;

  /// 首頁列表摘要原始為 [TextTheme.bodyMedium] + `height: 1.4`。
  static const double defaultListPreviewFontSize = 14;
  static const double defaultListPreviewLineHeight = 1.4;

  /// 精簡列表摘要原始為 [TextTheme.bodySmall] + `height: 1.35`。
  static const double defaultListCompactPreviewLineHeight = 1.45;

  static const double minTitleFontSize = 18;
  static const double maxTitleFontSize = 28;
  static const double minTitleLineHeight = 1.0;
  static const double maxTitleLineHeight = 2.0;

  static const double minBodyFontSize = 14;
  static const double maxBodyFontSize = 22;
  static const double minBodyLineHeight = 1.2;
  static const double maxBodyLineHeight = 2.4;
  static const double minBodyParagraphSpacing = 0;
  static const double maxBodyParagraphSpacing = 32;

  static const EditorTypographyPreferences defaults =
      EditorTypographyPreferences(
        titleFontSize: defaultTitleFontSize,
        titleLineHeight: defaultTitleLineHeight,
        bodyFontSize: defaultBodyFontSize,
        bodyLineHeight: defaultBodyLineHeight,
        bodyParagraphSpacing: defaultBodyParagraphSpacing,
      );

  bool get isAtDefaults => this == defaults;

  final double titleFontSize;
  final double titleLineHeight;
  final double bodyFontSize;
  final double bodyLineHeight;
  final double bodyParagraphSpacing;

  EditorTypographyPreferences clamped() {
    return EditorTypographyPreferences(
      titleFontSize: _clamp(titleFontSize, minTitleFontSize, maxTitleFontSize),
      titleLineHeight: _clamp(
        titleLineHeight,
        minTitleLineHeight,
        maxTitleLineHeight,
      ),
      bodyFontSize: _clamp(bodyFontSize, minBodyFontSize, maxBodyFontSize),
      bodyLineHeight: _clamp(
        bodyLineHeight,
        minBodyLineHeight,
        maxBodyLineHeight,
      ),
      bodyParagraphSpacing: _clamp(
        bodyParagraphSpacing,
        minBodyParagraphSpacing,
        maxBodyParagraphSpacing,
      ),
    );
  }

  EditorTypographyPreferences copyWith({
    double? titleFontSize,
    double? titleLineHeight,
    double? bodyFontSize,
    double? bodyLineHeight,
    double? bodyParagraphSpacing,
  }) {
    return EditorTypographyPreferences(
      titleFontSize: titleFontSize ?? this.titleFontSize,
      titleLineHeight: titleLineHeight ?? this.titleLineHeight,
      bodyFontSize: bodyFontSize ?? this.bodyFontSize,
      bodyLineHeight: bodyLineHeight ?? this.bodyLineHeight,
      bodyParagraphSpacing: bodyParagraphSpacing ?? this.bodyParagraphSpacing,
    ).clamped();
  }

  static EditorTypographyPreferences fromStorage({
    String? titleFontSize,
    String? titleLineHeight,
    String? bodyFontSize,
    String? bodyLineHeight,
    String? bodyParagraphSpacing,
  }) {
    return EditorTypographyPreferences(
      titleFontSize: _parseDouble(titleFontSize, defaultTitleFontSize),
      titleLineHeight: _parseDouble(titleLineHeight, defaultTitleLineHeight),
      bodyFontSize: _parseDouble(bodyFontSize, defaultBodyFontSize),
      bodyLineHeight: _parseDouble(bodyLineHeight, defaultBodyLineHeight),
      bodyParagraphSpacing: _parseDouble(
        bodyParagraphSpacing,
        defaultBodyParagraphSpacing,
      ),
    ).clamped();
  }

  static double _parseDouble(String? raw, double fallback) {
    if (raw == null || raw.trim().isEmpty) {
      return fallback;
    }
    return double.tryParse(raw.trim()) ?? fallback;
  }

  static double _clamp(double value, double min, double max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

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
        base.fontSize ?? defaultListTitleFontSize,
        titleFontSize,
        defaultTitleFontSize,
      ),
      height: _scale(
        base.height ?? defaultListTitleLineHeight,
        titleLineHeight,
        defaultTitleLineHeight,
      ),
      fontWeight: FontWeight.w700,
    );
  }

  /// 首頁列表摘要：以原本 `bodyMedium` + `height: 1.4` 為基準。
  TextStyle listPreviewTextStyle(TextTheme textTheme, {Color? color}) {
    final TextStyle base = textTheme.bodyMedium ?? const TextStyle();
    return base.copyWith(
      fontSize: _scale(
        base.fontSize ?? defaultListPreviewFontSize,
        bodyFontSize,
        defaultBodyFontSize,
      ),
      height: _scale(
        defaultListPreviewLineHeight,
        bodyLineHeight,
        defaultBodyLineHeight,
      ),
      color: color,
    );
  }

  /// 精簡列表摘要：以原本 `bodySmall` + `height: 1.45` 為基準。
  TextStyle listCompactPreviewTextStyle(TextTheme textTheme, {Color? color}) {
    final TextStyle base = textTheme.bodySmall ?? const TextStyle();
    return base.copyWith(
      fontSize: _scale(base.fontSize ?? 12, bodyFontSize, defaultBodyFontSize),
      height: _scale(
        defaultListCompactPreviewLineHeight,
        bodyLineHeight,
        defaultBodyLineHeight,
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

  @override
  bool operator ==(Object other) {
    return other is EditorTypographyPreferences &&
        other.titleFontSize == titleFontSize &&
        other.titleLineHeight == titleLineHeight &&
        other.bodyFontSize == bodyFontSize &&
        other.bodyLineHeight == bodyLineHeight &&
        other.bodyParagraphSpacing == bodyParagraphSpacing;
  }

  @override
  int get hashCode => Object.hash(
    titleFontSize,
    titleLineHeight,
    bodyFontSize,
    bodyLineHeight,
    bodyParagraphSpacing,
  );
}
