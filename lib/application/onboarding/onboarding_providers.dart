import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/shared/data_versions.dart';

class OnboardingIntroController extends AsyncNotifier<int> {
  @override
  Future<int> build() {
    return ref.read(userPreferencesProvider).onboardingIntroVersion;
  }

  Future<void> markCompleted() async {
    await ref
        .read(userPreferencesProvider)
        .setOnboardingIntroVersion(DataVersions.onboardingIntro);
    state = const AsyncData<int>(DataVersions.onboardingIntro);
  }
}

final onboardingIntroVersionProvider =
    AsyncNotifierProvider<OnboardingIntroController, int>(
      OnboardingIntroController.new,
    );
