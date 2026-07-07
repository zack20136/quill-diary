import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';

final NotifierProvider<MutableAppSessionNotifier, AppSessionState>
mutableAppSessionProvider =
    NotifierProvider<MutableAppSessionNotifier, AppSessionState>(
      MutableAppSessionNotifier.new,
    );

class MutableAppSessionNotifier extends Notifier<AppSessionState> {
  @override
  AppSessionState build() =>
      const AppSessionState(status: AppLockStatus.locked);

  void unlock(UnlockedVaultSession session) {
    state = AppSessionState(status: AppLockStatus.unlocked, session: session);
  }

  void lock() {
    state = const AppSessionState(status: AppLockStatus.locked);
  }
}

ProviderContainer buildMutableAppSessionContainer({required List overrides}) {
  return ProviderContainer(
    overrides: [
      effectiveAppSessionProvider.overrideWith(
        (Ref ref) async => ref.watch(mutableAppSessionProvider),
      ),
      ...overrides,
    ],
  );
}
