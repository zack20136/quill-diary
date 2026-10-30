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
}
