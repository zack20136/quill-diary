import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/application/session/app_session_controller.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';

export '../state/unlock_result.dart';

final appSessionProvider =
    NotifierProvider<AppSessionController, AppSessionState>(
      AppSessionController.new,
    );

final sessionStartupProvider = FutureProvider<AppSessionState>((Ref ref) async {
  return ref.read(appSessionProvider.notifier).bootstrapAfterRestore();
});

class IndexQueryableVaultSession extends Notifier<UnlockedVaultSession?> {
  UnlockedVaultSession? _held;

  @override
  UnlockedVaultSession? build() {
    ref.listen(appSessionProvider, (_, AppSessionState next) {
      final UnlockedVaultSession? synced = _derive(next);
      if (synced != _held) {
        _held = synced;
        state = synced;
      }
    });
    _held = _derive(ref.watch(appSessionProvider));
    return _held;
  }

  UnlockedVaultSession? _derive(AppSessionState next) {
    if (next.isUnlocked && next.session != null) {
      return next.session;
    }
    if (next.status == AppLockStatus.unlocking) {
      return _held;
    }
    return null;
  }
}

final indexQueryableVaultSessionProvider =
    NotifierProvider<IndexQueryableVaultSession, UnlockedVaultSession?>(
      IndexQueryableVaultSession.new,
    );

final effectiveAppSessionProvider = FutureProvider<AppSessionState>((
  Ref ref,
) async {
  final AppSessionState localState = ref.watch(appSessionProvider);
  if (localState.status != AppLockStatus.uninitialized) {
    return localState;
  }
  return ref.watch(sessionStartupProvider.future);
});

final activeVaultSessionProvider = FutureProvider<UnlockedVaultSession?>((
  Ref ref,
) async {
  final AppSessionState sessionState = await ref.watch(
    effectiveAppSessionProvider.future,
  );
  return sessionState.isUnlocked ? sessionState.session : null;
});
