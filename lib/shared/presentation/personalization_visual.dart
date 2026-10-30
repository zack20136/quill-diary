import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';

extension PersonalizationVisual on PersonalizationPreferences {
  ThemeMode get materialThemeMode => themeMode.materialThemeMode;
  Locale get materialLocale => locale.materialLocale;
}

extension ThemeModeVisual on AppThemeModePreference {
  ThemeMode get materialThemeMode => switch (this) {
    AppThemeModePreference.system => ThemeMode.system,
    AppThemeModePreference.light => ThemeMode.light,
    AppThemeModePreference.dark => ThemeMode.dark,
  };
}
