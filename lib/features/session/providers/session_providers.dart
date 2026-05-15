import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/recovery/recovery_metadata.dart';
import '../../../domain/security/unlocked_vault_session.dart';
import '../../../infrastructure/security/app_lock_service.dart';
import '../../../infrastructure/storage/vault_repository.dart';
import '../../../shared/providers/core_providers.dart';
import '../session_messages.dart';
import '../state/app_session_state.dart';

class AppSessionController extends Notifier<AppSessionState> {
  @override
  AppSessionState build() {
    return const AppSessionState(status: AppLockStatus.uninitialized);
  }

  Future<bool> unlock() async {
    state = state.copyWith(status: AppLockStatus.unlocking, clearMessage: true);
    final bool success = await ref.read(unlockAppUseCaseProvider).call();
    state = state.copyWith(
      status: success ? AppLockStatus.unlocked : AppLockStatus.locked,
      message: success ? null : kUnlockFailedMessage,
      clearMessage: success,
    );
    return success;
  }

  Future<void> unlockWithRecovery(String recoveryKey) async {
    state = state.copyWith(status: AppLockStatus.unlocking, clearMessage: true);
    try {
      final UnlockedVaultSession session =
          await ref.read(unlockWithRecoveryKeyUseCaseProvider).call(recoveryKey);
      state = AppSessionState(
        status: AppLockStatus.unlocked,
        session: session,
        message: kRecoveryUnlockSuccessMessage,
      );
    } catch (error) {
      state = state.copyWith(
        status: AppLockStatus.recoveryRequired,
        clearSession: true,
        message: '$error',
      );
      rethrow;
    }
  }

  Future<void> lock(AppLockService appLockService) async {
    await appLockService.lock();
    state = state.copyWith(
      status: AppLockStatus.locked,
      message: kAppLockedMessage,
    );
  }

  void activateSession(
    UnlockedVaultSession session, {
    String? message,
  }) {
    state = AppSessionState(
      status: AppLockStatus.unlocked,
      session: session,
      message: message,
    );
  }

  void reset() {
    state = const AppSessionState(status: AppLockStatus.uninitialized);
  }
}

final appSessionProvider = NotifierProvider<AppSessionController, AppSessionState>(
  AppSessionController.new,
);

final appStartupProvider = FutureProvider<AppSessionState>((Ref ref) async {
  if (!ref.watch(supportedPlatformProvider)) {
    return const AppSessionState(
      status: AppLockStatus.fatalError,
      message: kAndroidOnlyMessage,
    );
  }

  final VaultRepository repository = ref.read(vaultRepositoryProvider);
  final AppLockService appLockService = ref.read(appLockServiceProvider);

  try {
    await repository.initialize();

    final RecoveryMetadata? metadata = await repository.readRecoveryMetadata();
    if (metadata == null) {
      return const AppSessionState(
        status: AppLockStatus.unlocked,
        message: kStartupNeedsRecoveryKeyMessage,
      );
    }

    final bool hasTrustedDevice = await repository.hasTrustedDeviceAccess();
    if (!hasTrustedDevice) {
      return const AppSessionState(
        status: AppLockStatus.recoveryRequired,
        message: kStartupNeedsTrustedDeviceMessage,
      );
    }

    final UnlockedVaultSession session = await repository.openTrustedSession();
    if ((await ref.read(indexDatabaseProvider).getAppValue('last_rebuild_at')) == null) {
      await repository.rebuildIndex(session);
    }

    if (await appLockService.isSessionLocked()) {
      return AppSessionState(
        status: AppLockStatus.locked,
        session: session,
        message: kStartupNeedsBiometricMessage,
      );
    }

    return AppSessionState(
      status: AppLockStatus.unlocked,
      session: session,
    );
  } catch (error) {
    return AppSessionState(
      status: AppLockStatus.fatalError,
      message: '$error',
    );
  }
});

final effectiveAppSessionProvider = FutureProvider<AppSessionState>((Ref ref) async {
  final AppSessionState startupState = await ref.watch(appStartupProvider.future);
  final AppSessionState localState = ref.watch(appSessionProvider);
  if (localState.status == AppLockStatus.uninitialized) {
    return startupState;
  }
  return localState;
});

final activeVaultSessionProvider = FutureProvider<UnlockedVaultSession?>((Ref ref) async {
  final AppSessionState sessionState = await ref.watch(effectiveAppSessionProvider.future);
  return sessionState.isUnlocked ? sessionState.session : null;
});
