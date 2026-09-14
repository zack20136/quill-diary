import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/onboarding/onboarding_intro.dart';
import 'package:quill_diary/application/onboarding/onboarding_providers.dart';
import 'package:quill_diary/infrastructure/preferences/preferences_providers.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';

void main() {
  late Directory tempDir;
  late UserPreferences preferences;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onboarding_prefs');
    preferences = UserPreferences(
      storageFile: File('${tempDir.path}/app_preferences.json'),
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('完成介紹後會寫入目前版本', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [userPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(await preferences.onboardingIntroVersion, 0);
    await container
        .read(onboardingIntroVersionProvider.notifier)
        .markCompleted();
    expect(
      await container.read(onboardingIntroVersionProvider.future),
      onboardingIntroCurrentVersion,
    );
    expect(
      await preferences.onboardingIntroVersion,
      onboardingIntroCurrentVersion,
    );
  });
}
