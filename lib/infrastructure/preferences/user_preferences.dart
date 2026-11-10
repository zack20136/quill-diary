import 'dart:io';

import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/storage/shared/app_support_string_map.dart';

/// 在日記庫外持久化使用者偏好（設定頁可擴充更多 key）。
class UserPreferences {
  UserPreferences({File? storageFile})
    : _store = AppSupportStringMap(
        fileName: 'app_preferences.json',
        storageFile: storageFile,
      );

  static const String _imageCompressPresetKey = 'image_compress_preset';
  static const String _sessionTimeoutKey = 'session_background_timeout_minutes';
  static const String _themeModeKey = 'theme_mode';
  static const String _appLocaleKey = 'app_locale';
  static const String _onboardingIntroVersionKey = 'onboarding_intro_version';
  static const String _editorTitleFontSizeKey = 'editor_title_font_size';
  static const String _editorTitleLineHeightKey = 'editor_title_line_height';
  static const String _editorBodyFontSizeKey = 'editor_body_font_size';
  static const String _editorBodyLineHeightKey = 'editor_body_line_height';
  static const String _editorBodyParagraphSpacingKey =
      'editor_body_paragraph_spacing';

  final AppSupportStringMap _store;

  Future<ImageCompressPreset> get imageCompressPreset async {
    final String? raw = await _readValue(_imageCompressPresetKey);
    return ImageCompressPreset.fromStorage(raw);
  }

  Future<void> setImageCompressPreset(ImageCompressPreset value) async {
    await _writeValue(_imageCompressPresetKey, value.storageValue);
  }

  Future<EditorTypographyPreferences> get editorTypography async {
    final Map<String, String> store = await _store.load();
    return EditorTypographyPreferences.fromStorage(
      titleFontSize: store[_editorTitleFontSizeKey],
      titleLineHeight: store[_editorTitleLineHeightKey],
      bodyFontSize: store[_editorBodyFontSizeKey],
      bodyLineHeight: store[_editorBodyLineHeightKey],
      bodyParagraphSpacing: store[_editorBodyParagraphSpacingKey],
    );
  }

  Future<AppThemeModePreference> get themeMode async {
    final String? raw = await _readValue(_themeModeKey);
    return AppThemeModePreference.fromStorage(raw);
  }

  Future<void> setThemeMode(AppThemeModePreference value) async {
    await _writeValue(_themeModeKey, value.storageValue);
  }

  Future<SessionBackgroundTimeoutMinutes> get sessionTimeoutMinutes async {
    final String? raw = await _readValue(_sessionTimeoutKey);
    return SessionBackgroundTimeoutMinutes.fromStorage(raw);
  }

  Future<void> setSessionTimeoutMinutes(
    SessionBackgroundTimeoutMinutes value,
  ) async {
    await _writeValue(_sessionTimeoutKey, value.storageValue);
  }

  Future<AppLanguage> get appLocale async {
    final String? raw = await _readValue(_appLocaleKey);
    return AppLanguage.fromStorage(raw);
  }

  Future<AppLanguage?> get storedAppLocaleOrNull async {
    final String? raw = await _readValue(_appLocaleKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return AppLanguage.fromStorage(raw);
  }

  Future<void> setAppLocale(AppLanguage value) async {
    await _writeValue(_appLocaleKey, value.storageValue);
  }

  Future<int> get onboardingIntroVersion async {
    final String? raw = await _readValue(_onboardingIntroVersionKey);
    return int.tryParse(raw?.trim() ?? '') ?? 0;
  }

  Future<void> setOnboardingIntroVersion(int value) async {
    await _writeValue(_onboardingIntroVersionKey, value.toString());
  }

  Future<PersonalizationPreferences> loadPersonalizationPreferences() async {
    final Map<String, String> store = await _store.load();
    return PersonalizationPreferences(
      imageCompressPreset: ImageCompressPreset.fromStorage(
        store[_imageCompressPresetKey],
      ),
      typography: EditorTypographyPreferences.fromStorage(
        titleFontSize: store[_editorTitleFontSizeKey],
        titleLineHeight: store[_editorTitleLineHeightKey],
        bodyFontSize: store[_editorBodyFontSizeKey],
        bodyLineHeight: store[_editorBodyLineHeightKey],
        bodyParagraphSpacing: store[_editorBodyParagraphSpacingKey],
      ),
      themeMode: AppThemeModePreference.fromStorage(store[_themeModeKey]),
      sessionTimeoutMinutes: SessionBackgroundTimeoutMinutes.fromStorage(
        store[_sessionTimeoutKey],
      ),
      locale: AppLanguage.fromStorage(store[_appLocaleKey]),
    );
  }

  Future<void> savePersonalizationPreferences(
    PersonalizationPreferences value,
  ) async {
    final EditorTypographyPreferences typography = value.typography.clamped();
    await _store.update({
      _imageCompressPresetKey: value.imageCompressPreset.storageValue,
      _themeModeKey: value.themeMode.storageValue,
      _sessionTimeoutKey: value.sessionTimeoutMinutes.storageValue,
      _appLocaleKey: value.locale.storageValue,
      _editorTitleFontSizeKey: typography.titleFontSize.toString(),
      _editorTitleLineHeightKey: typography.titleLineHeight.toString(),
      _editorBodyFontSizeKey: typography.bodyFontSize.toString(),
      _editorBodyLineHeightKey: typography.bodyLineHeight.toString(),
      _editorBodyParagraphSpacingKey: typography.bodyParagraphSpacing
          .toString(),
    });
  }

  Future<String?> _readValue(String key) async {
    final Map<String, String> store = await _store.load();
    return store[key];
  }

  Future<void> _writeValue(String key, String value) =>
      _store.update({key: value});
}
