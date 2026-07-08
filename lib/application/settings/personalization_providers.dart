import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/preferences_providers.dart';

class PersonalizationPreferencesController
    extends AsyncNotifier<PersonalizationPreferences> {
  @override
  Future<PersonalizationPreferences> build() async {
    return ref.read(userPreferencesProvider).loadPersonalizationPreferences();
  }

  Future<void> _persist(PersonalizationPreferences value) async {
    await ref
        .read(userPreferencesProvider)
        .savePersonalizationPreferences(value);
    state = AsyncData<PersonalizationPreferences>(value);
    ref.invalidate(storedAppLanguagePreferenceProvider);
  }

  Future<void> setImageCompressPreset(ImageCompressPreset value) async {
    final PersonalizationPreferences current = await future;
    await _persist(current.copyWith(imageCompressPreset: value));
  }

  Future<void> setThemeMode(AppThemeModePreference value) async {
    final PersonalizationPreferences current = await future;
    await _persist(current.copyWith(themeMode: value));
  }

  Future<void> setSessionTimeoutMinutes(
    SessionBackgroundTimeoutMinutes value,
  ) async {
    final PersonalizationPreferences current = await future;
    await _persist(current.copyWith(sessionTimeoutMinutes: value));
  }

  Future<void> setLocale(AppLanguage value) async {
    final PersonalizationPreferences current = await future;
    await _persist(current.copyWith(locale: value));
  }

  Future<void> setTypography(EditorTypographyPreferences value) async {
    final PersonalizationPreferences current = await future;
    await _persist(current.copyWith(typography: value.clamped()));
  }

  Future<void> resetTypographyToDefaults() async {
    final PersonalizationPreferences current = await future;
    await _persist(
      current.copyWith(typography: EditorTypographyPreferences.defaults),
    );
  }
}

final personalizationPreferencesProvider =
    AsyncNotifierProvider<
      PersonalizationPreferencesController,
      PersonalizationPreferences
    >(PersonalizationPreferencesController.new);
final storedAppLanguagePreferenceProvider = FutureProvider<AppLanguage?>((
  Ref ref,
) {
  return ref.read(userPreferencesProvider).storedAppLocaleOrNull;
});

Duration readSessionBackgroundTimeout(Ref ref) {
  return ref
      .read(personalizationPreferencesProvider)
      .maybeWhen(
        data: (PersonalizationPreferences prefs) => prefs.sessionTimeout,
        orElse: () => SessionBackgroundTimeoutMinutes.three.duration,
      );
}

PersonalizationPreferences watchPersonalizationPreferences(WidgetRef ref) {
  return ref
      .watch(personalizationPreferencesProvider)
      .maybeWhen(
        data: (PersonalizationPreferences value) => value,
        orElse: () => PersonalizationPreferences.defaults,
      );
}
