import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';

class PersonalizationPreferencesController
    extends AsyncNotifier<PersonalizationPreferences> {
  Future<void> _pending = Future.value();

  @override
  Future<PersonalizationPreferences> build() async {
    return ref.read(userPreferencesProvider).loadPersonalizationPreferences();
  }

  Future<void> _update(
    PersonalizationPreferences Function(PersonalizationPreferences) change,
  ) {
    final result = _pending.then((_) async {
      final next = change(await future);
      await ref
          .read(userPreferencesProvider)
          .savePersonalizationPreferences(next);
      if (!ref.mounted) return;
      state = AsyncData(next);
      ref.invalidate(storedAppLanguagePreferenceProvider);
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> setImageCompressPreset(ImageCompressPreset value) =>
      _update((current) => current.copyWith(imageCompressPreset: value));

  Future<void> setThemeMode(AppThemeModePreference value) =>
      _update((current) => current.copyWith(themeMode: value));

  Future<void> setSessionTimeoutMinutes(
    SessionBackgroundTimeoutMinutes value,
  ) => _update((current) => current.copyWith(sessionTimeoutMinutes: value));

  Future<void> setLocale(AppLanguage value) =>
      _update((current) => current.copyWith(locale: value));

  /// 首次啟動且尚未寫入語系時，依裝置語系持久化，不改動既有使用者。
  Future<void> seedDeviceLocaleIfUnset(Locale deviceLocale) async {
    final AppLanguage? stored = await ref
        .read(userPreferencesProvider)
        .storedAppLocaleOrNull;
    if (stored != null) {
      return;
    }
    await setLocale(appLanguageFromDeviceLocale(deviceLocale));
  }

  Future<void> setTypography(EditorTypographyPreferences value) =>
      _update((current) => current.copyWith(typography: value.clamped()));

  Future<void> resetTypographyToDefaults() =>
      setTypography(EditorTypographyPreferences.defaults);
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

final userPreferencesProvider = Provider<UserPreferences>((Ref ref) {
  return UserPreferences();
});
