import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';

void main() {
  late Directory tempDir;
  late UserPreferences preferences;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('personalization_locale');
    preferences = UserPreferences(
      storageFile: File('${tempDir.path}/app_preferences.json'),
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('未寫入語系時會依裝置語系持久化，已有語系則不覆蓋', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [userPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    await container
        .read(personalizationPreferencesProvider.notifier)
        .seedDeviceLocaleIfUnset(const Locale('en', 'US'));
    expect(await preferences.storedAppLocaleOrNull, AppLanguage.en);

    await container
        .read(personalizationPreferencesProvider.notifier)
        .seedDeviceLocaleIfUnset(const Locale('zh', 'TW'));
    expect(await preferences.storedAppLocaleOrNull, AppLanguage.en);
  });

  test('未寫入語系且裝置為中文時會持久化繁中', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [userPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    await container
        .read(personalizationPreferencesProvider.notifier)
        .seedDeviceLocaleIfUnset(const Locale('zh', 'TW'));
    expect(await preferences.storedAppLocaleOrNull, AppLanguage.zh);
  });

  test('並行修改個人化設定使用最新狀態合併，不以舊快照覆蓋其他欄位', () async {
    final container = ProviderContainer(
      overrides: [userPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      personalizationPreferencesProvider.notifier,
    );
    await container.read(personalizationPreferencesProvider.future);
    await Future.wait([
      controller.setThemeMode(AppThemeModePreference.dark),
      controller.setLocale(AppLanguage.en),
    ]);
    final state = await container.read(
      personalizationPreferencesProvider.future,
    );
    final restored = await UserPreferences(
      storageFile: File('${tempDir.path}/app_preferences.json'),
    ).loadPersonalizationPreferences();
    expect(state.themeMode, AppThemeModePreference.dark);
    expect(state.locale, AppLanguage.en);
    expect(restored.themeMode, state.themeMode);
    expect(restored.locale, state.locale);
  });

  test('個人化設定保存失敗不更新畫面狀態，排隊中的後續修改仍可保存', () async {
    final container = ProviderContainer(
      overrides: [userPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      personalizationPreferencesProvider.notifier,
    );
    final before = await container.read(
      personalizationPreferencesProvider.future,
    );
    final blocked = Directory('${tempDir.path}/app_preferences.json.tmp');
    await blocked.create();
    await expectLater(
      controller.setLocale(AppLanguage.en),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      (await container.read(personalizationPreferencesProvider.future)).locale,
      before.locale,
    );
    await blocked.delete();
    await controller.setThemeMode(AppThemeModePreference.dark);
    expect(
      (await preferences.loadPersonalizationPreferences()).themeMode,
      AppThemeModePreference.dark,
    );
    expect(
      (await preferences.loadPersonalizationPreferences()).locale,
      before.locale,
    );
  });
}
