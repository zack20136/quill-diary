import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';

void main() {
  test('並行變更語系與主題可合併保存，重新開啟仍保留其他設定', () async {
    final directory = await Directory.systemTemp.createTemp(
      'quill_preferences_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/preferences.json');
    final preferences = UserPreferences(storageFile: file);
    await preferences.setOnboardingIntroVersion(7);
    await Future.wait([
      preferences.setAppLocale(AppLanguage.en),
      preferences.setThemeMode(AppThemeModePreference.dark),
      preferences.setAppLocale(AppLanguage.zh),
    ]);
    final restored = UserPreferences(storageFile: file);
    expect(await restored.appLocale, AppLanguage.zh);
    expect(await restored.themeMode, AppThemeModePreference.dark);
    expect(await restored.onboardingIntroVersion, 7);
  });
}
