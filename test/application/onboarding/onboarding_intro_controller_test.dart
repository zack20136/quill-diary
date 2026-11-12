import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/onboarding/onboarding_providers.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
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

  test('完成介紹後會寫入已看過', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [userPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(await preferences.hasSeenOnboardingIntro, isFalse);
    await container
        .read(hasSeenOnboardingIntroProvider.notifier)
        .markCompleted();
    expect(
      await container.read(hasSeenOnboardingIntroProvider.future),
      isTrue,
    );
    expect(await preferences.hasSeenOnboardingIntro, isTrue);
  });
}
