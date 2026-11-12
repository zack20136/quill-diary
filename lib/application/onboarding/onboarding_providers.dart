import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';

class OnboardingIntroController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() {
    return ref.read(userPreferencesProvider).hasSeenOnboardingIntro;
  }

  Future<void> markCompleted() async {
    await ref.read(userPreferencesProvider).markOnboardingIntroSeen();
    state = const AsyncData<bool>(true);
  }
}

final hasSeenOnboardingIntroProvider =
    AsyncNotifierProvider<OnboardingIntroController, bool>(
      OnboardingIntroController.new,
    );
