/// 個人化設定頁管理的全部使用者偏好。
class PersonalizationPreferences {
  const PersonalizationPreferences({
    required this.imageCompressPreset,
    required this.typography,
    required this.themeMode,
    required this.sessionTimeoutMinutes,
    required this.locale,
  });

  static const PersonalizationPreferences defaults = PersonalizationPreferences(
    imageCompressPreset: ImageCompressPreset.standard,
    typography: EditorTypographyPreferences.defaults,
    themeMode: AppThemeModePreference.system,
    sessionTimeoutMinutes: SessionBackgroundTimeoutMinutes.three,
    locale: AppLanguage.zh,
  );

  final ImageCompressPreset imageCompressPreset;
  final EditorTypographyPreferences typography;
  final AppThemeModePreference themeMode;
  final SessionBackgroundTimeoutMinutes sessionTimeoutMinutes;
  final AppLanguage locale;

  PersonalizationPreferences copyWith({
    ImageCompressPreset? imageCompressPreset,
    EditorTypographyPreferences? typography,
    AppThemeModePreference? themeMode,
    SessionBackgroundTimeoutMinutes? sessionTimeoutMinutes,
    AppLanguage? locale,
  }) {
    return PersonalizationPreferences(
      imageCompressPreset: imageCompressPreset ?? this.imageCompressPreset,
      typography: typography ?? this.typography,
      themeMode: themeMode ?? this.themeMode,
      sessionTimeoutMinutes:
          sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      locale: locale ?? this.locale,
    );
  }

  Duration get sessionTimeout => sessionTimeoutMinutes.duration;
}

/// 主題顏色偏好。
enum AppThemeModePreference {
  system,
  light,
  dark;

  String get storageValue => name;

  static AppThemeModePreference fromStorage(String? raw) {
    return switch (raw?.trim()) {
      'light' => AppThemeModePreference.light,
      'dark' => AppThemeModePreference.dark,
      'system' || null || '' => AppThemeModePreference.system,
      _ => AppThemeModePreference.system,
    };
  }
}

/// 應用語系偏好。
enum AppLanguage {
  zh,
  en;

  String get storageValue => switch (this) {
    AppLanguage.zh => 'zh',
    AppLanguage.en => 'en',
  };

  static AppLanguage fromStorage(String? raw) {
    return switch (raw?.trim()) {
      'en' => AppLanguage.en,
      'zh' || null || '' => AppLanguage.zh,
      _ => AppLanguage.zh,
    };
  }
}

/// 背景逾時後自動鎖定的分鐘選項。
enum SessionBackgroundTimeoutMinutes {
  one(1),
  three(3),
  five(5),
  ten(10);

  const SessionBackgroundTimeoutMinutes(this.minutes);

  static const List<SessionBackgroundTimeoutMinutes> choices =
      SessionBackgroundTimeoutMinutes.values;

  final int minutes;

  String get storageValue => minutes.toString();

  Duration get duration => Duration(minutes: minutes);

  static SessionBackgroundTimeoutMinutes fromStorage(String? raw) {
    final int? parsed = int.tryParse(raw?.trim() ?? '');
    return switch (parsed) {
      1 => SessionBackgroundTimeoutMinutes.one,
      5 => SessionBackgroundTimeoutMinutes.five,
      10 => SessionBackgroundTimeoutMinutes.ten,
      30 => SessionBackgroundTimeoutMinutes.ten,
      3 || null => SessionBackgroundTimeoutMinutes.three,
      _ => SessionBackgroundTimeoutMinutes.three,
    };
  }
}

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

  /// 首頁列表標題原始為 `titleMedium`。
  static const double defaultListTitleFontSize = 16;
  static const double defaultListTitleLineHeight = 1.5;

  /// 首頁列表摘要原始為 `bodyMedium` + `height: 1.4`。
  static const double defaultListPreviewFontSize = 14;
  static const double defaultListPreviewLineHeight = 1.4;

  /// 精簡列表摘要原始為 `bodySmall` + `height: 1.35`。
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

/// 編輯器選圖時的圖片壓縮預設。
enum ImageCompressPreset {
  original,
  standard,
  high;

  String get storageValue => name;

  int? get quality => switch (this) {
    ImageCompressPreset.original => null,
    ImageCompressPreset.standard => 70,
    ImageCompressPreset.high => 85,
  };

  int? get minWidth => switch (this) {
    ImageCompressPreset.original => null,
    ImageCompressPreset.standard => 1280,
    ImageCompressPreset.high => 1920,
  };

  int? get minHeight => switch (this) {
    ImageCompressPreset.original => null,
    ImageCompressPreset.standard => 1280,
    ImageCompressPreset.high => 1920,
  };

  static ImageCompressPreset fromStorage(String? raw) {
    return switch (raw?.trim()) {
      'original' => ImageCompressPreset.original,
      'high' => ImageCompressPreset.high,
      'standard' || null || '' => ImageCompressPreset.standard,
      _ => ImageCompressPreset.standard,
    };
  }
}
