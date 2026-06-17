import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'editor_typography_preferences.dart';
import 'user_preferences.dart';

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

  ThemeMode get materialThemeMode => themeMode.materialThemeMode;

  Locale get materialLocale => locale.materialLocale;

  Duration get sessionTimeout => sessionTimeoutMinutes.duration;
}

/// 主題顏色偏好。
enum AppThemeModePreference {
  system,
  light,
  dark;

  String get storageValue => name;

  ThemeMode get materialThemeMode => switch (this) {
    AppThemeModePreference.system => ThemeMode.system,
    AppThemeModePreference.light => ThemeMode.light,
    AppThemeModePreference.dark => ThemeMode.dark,
  };

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

  Locale get materialLocale => switch (this) {
    AppLanguage.zh => appZhLocale,
    AppLanguage.en => appEnLocale,
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
