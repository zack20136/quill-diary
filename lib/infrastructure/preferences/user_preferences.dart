import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:quill_diary/app/app_identifiers.dart';
import 'editor_typography_preferences.dart';
import 'personalization_preferences.dart';

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

/// 在 vault 外持久化使用者偏好（設定頁可擴充更多 key）。
class UserPreferences {
  UserPreferences({File? storageFile}) : _storageFileOverride = storageFile;

  static const String _imageCompressPresetKey = 'image_compress_preset';
  static const String _sessionTimeoutKey = 'session_background_timeout_minutes';
  static const String _themeModeKey = 'theme_mode';
  static const String _appLocaleKey = 'app_locale';
  static const String _editorTitleFontSizeKey = 'editor_title_font_size';
  static const String _editorTitleLineHeightKey = 'editor_title_line_height';
  static const String _editorBodyFontSizeKey = 'editor_body_font_size';
  static const String _editorBodyLineHeightKey = 'editor_body_line_height';
  static const String _editorBodyParagraphSpacingKey =
      'editor_body_paragraph_spacing';

  final File? _storageFileOverride;
  Map<String, String>? _cache;

  Future<ImageCompressPreset> get imageCompressPreset async {
    final String? raw = await _readValue(_imageCompressPresetKey);
    return ImageCompressPreset.fromStorage(raw);
  }

  Future<void> setImageCompressPreset(ImageCompressPreset value) async {
    await _writeValue(_imageCompressPresetKey, value.storageValue);
  }

  Future<EditorTypographyPreferences> get editorTypography async {
    final Map<String, String> store = await _loadStore();
    return EditorTypographyPreferences.fromStorage(
      titleFontSize: store[_editorTitleFontSizeKey],
      titleLineHeight: store[_editorTitleLineHeightKey],
      bodyFontSize: store[_editorBodyFontSizeKey],
      bodyLineHeight: store[_editorBodyLineHeightKey],
      bodyParagraphSpacing: store[_editorBodyParagraphSpacingKey],
    );
  }

  Future<void> setEditorTypography(EditorTypographyPreferences value) async {
    final EditorTypographyPreferences clamped = value.clamped();
    final Map<String, String> store = await _loadStore();
    store[_editorTitleFontSizeKey] = clamped.titleFontSize.toString();
    store[_editorTitleLineHeightKey] = clamped.titleLineHeight.toString();
    store[_editorBodyFontSizeKey] = clamped.bodyFontSize.toString();
    store[_editorBodyLineHeightKey] = clamped.bodyLineHeight.toString();
    store[_editorBodyParagraphSpacingKey] = clamped.bodyParagraphSpacing
        .toString();
    await _persistStore(store);
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

  Future<PersonalizationPreferences> loadPersonalizationPreferences() async {
    final Map<String, String> store = await _loadStore();
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
    final Map<String, String> store = await _loadStore();
    store[_imageCompressPresetKey] = value.imageCompressPreset.storageValue;
    store[_themeModeKey] = value.themeMode.storageValue;
    store[_sessionTimeoutKey] = value.sessionTimeoutMinutes.storageValue;
    store[_appLocaleKey] = value.locale.storageValue;
    store[_editorTitleFontSizeKey] = typography.titleFontSize.toString();
    store[_editorTitleLineHeightKey] = typography.titleLineHeight.toString();
    store[_editorBodyFontSizeKey] = typography.bodyFontSize.toString();
    store[_editorBodyLineHeightKey] = typography.bodyLineHeight.toString();
    store[_editorBodyParagraphSpacingKey] = typography.bodyParagraphSpacing
        .toString();
    await _persistStore(store);
  }

  Future<String?> _readValue(String key) async {
    final Map<String, String> store = await _loadStore();
    return store[key];
  }

  Future<void> _writeValue(String key, String value) async {
    final Map<String, String> store = await _loadStore();
    store[key] = value;
    await _persistStore(store);
  }

  Future<Map<String, String>> _loadStore() async {
    if (_cache != null) {
      return _cache!;
    }

    final File file = await _storageFile();
    if (!file.existsSync()) {
      _cache = <String, String>{};
      return _cache!;
    }

    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, dynamic>) {
      _cache = decoded.map(
        (String key, dynamic value) => MapEntry(key, value.toString()),
      );
    } else {
      _cache = <String, String>{};
    }
    return _cache!;
  }

  Future<void> _persistStore(Map<String, String> store) async {
    final File file = await _storageFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(store),
      flush: true,
    );
    _cache = Map<String, String>.from(store);
  }

  Future<File> _storageFile() async {
    final File? override = _storageFileOverride;
    if (override != null) {
      return override;
    }
    final Directory supportDir = await getApplicationSupportDirectory();
    return File(
      p.join(
        supportDir.path,
        AppIdentifiers.appStorageDirectory,
        'app_preferences.json',
      ),
    );
  }
}
