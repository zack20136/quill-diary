import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';

extension PersonalizationVisual on PersonalizationPreferences {
  ThemeMode get materialThemeMode => themeMode.materialThemeMode;
}

extension ThemeModeVisual on AppThemeModePreference {
  ThemeMode get materialThemeMode => switch (this) {
    AppThemeModePreference.system => ThemeMode.system,
    AppThemeModePreference.light => ThemeMode.light,
    AppThemeModePreference.dark => ThemeMode.dark,
  };
}
