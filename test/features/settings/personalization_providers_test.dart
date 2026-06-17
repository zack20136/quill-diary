import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/settings/providers/personalization_providers.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

void main() {
  late Directory tempDir;
  late File prefsFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'personalization_providers_test_',
    );
    prefsFile = File('${tempDir.path}/app_preferences.json');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  ProviderContainer buildContainer() {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        userPreferencesProvider.overrideWithValue(
          UserPreferences(storageFile: prefsFile),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('resetTypographyToDefaults 只還原排版，不影響其他偏好', () async {
    final ProviderContainer container = buildContainer();
    final PersonalizationPreferencesController controller = container.read(
      personalizationPreferencesProvider.notifier,
    );

    await container.read(personalizationPreferencesProvider.future);
    await controller.setThemeMode(AppThemeModePreference.dark);
    await controller.setSessionTimeoutMinutes(
      SessionBackgroundTimeoutMinutes.ten,
    );
    await controller.setTypography(
      const EditorTypographyPreferences(
        titleFontSize: 26,
        titleLineHeight: 1.5,
        bodyFontSize: 20,
        bodyLineHeight: 2.0,
        bodyParagraphSpacing: 16,
      ),
    );

    await controller.resetTypographyToDefaults();

    final PersonalizationPreferences prefs = container
        .read(personalizationPreferencesProvider)
        .requireValue;
    expect(prefs.typography, EditorTypographyPreferences.defaults);
    expect(prefs.themeMode, AppThemeModePreference.dark);
    expect(prefs.sessionTimeoutMinutes, SessionBackgroundTimeoutMinutes.ten);

    final UserPreferences reloaded = UserPreferences(storageFile: prefsFile);
    final PersonalizationPreferences stored = await reloaded
        .loadPersonalizationPreferences();
    expect(stored.typography, EditorTypographyPreferences.defaults);
    expect(stored.themeMode, AppThemeModePreference.dark);
  });

  test('storedAppLanguagePreferenceProvider 未設定時回傳 null', () async {
    final ProviderContainer container = buildContainer();

    final AppLanguage? value = await container.read(
      storedAppLanguagePreferenceProvider.future,
    );

    expect(value, isNull);
  });

  test('storedAppLanguagePreferenceProvider 讀出已儲存的 en 偏好', () async {
    await UserPreferences(storageFile: prefsFile).setAppLocale(AppLanguage.en);
    final ProviderContainer container = buildContainer();

    final AppLanguage? value = await container.read(
      storedAppLanguagePreferenceProvider.future,
    );

    expect(value, AppLanguage.en);
  });
}
