import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/infrastructure/preferences/preferences_providers.dart';
import 'onboarding_intro.dart';

class OnboardingIntroController extends AsyncNotifier<int> {
  @override
  Future<int> build() {
    return ref.read(userPreferencesProvider).onboardingIntroVersion;
  }

  Future<void> markCompleted() async {
    await ref
        .read(userPreferencesProvider)
        .setOnboardingIntroVersion(onboardingIntroCurrentVersion);
    state = const AsyncData<int>(onboardingIntroCurrentVersion);
  }
}

final onboardingIntroVersionProvider =
    AsyncNotifierProvider<OnboardingIntroController, int>(
      OnboardingIntroController.new,
    );
