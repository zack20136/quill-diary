import 'package:cryptography/cryptography.dart';

import 'package:flutter/widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../domain/recovery/recovery_metadata.dart';

import '../../../domain/security/unlocked_vault_session.dart';

import '../../../infrastructure/security/app_lock_service.dart';

import '../../../infrastructure/security/app_unlock_mode.dart';

import '../../../infrastructure/security/device_key_manager.dart';

import '../../../infrastructure/storage/vault_repository.dart';

import '../../../shared/providers/core_providers.dart';

import '../session_messages.dart';

import '../session_timeout_policy.dart';

import '../state/app_session_state.dart';

import '../state/resume_unlock_action.dart';

import '../state/unlock_result.dart';



/// 管理 app-level session 狀態與 trusted session 還原流程。

class AppSessionController extends Notifier<AppSessionState> {

  DateTime? _lastForegroundExitAt;

  int _activeSensitiveTasks = 0;

  bool _pendingResourceCleanup = false;



  @visibleForTesting

  DateTime Function() clock = DateTime.now;



  @override

  AppSessionState build() {

    return const AppSessionState(status: AppLockStatus.uninitialized);

  }



  void beginTrustedUnlock() {
    state = const AppSessionState(
      status: AppLockStatus.unlocking,
      message: kTrustedUnlockInProgressMessage,
    );
  }



  Future<UnlockOutcome> unlock({
    bool deviceCredentialFallback = false,
    bool afterRestore = false,
  }) async {
    return _restoreTrustedSession(
      deviceCredentialFallback: deviceCredentialFallback,
      afterRestore: afterRestore,
    );
  }



  Future<void> unlockWithRecovery(String recoveryKey) async {

    state = state.copyWith(

      status: AppLockStatus.unlocking,

      clearMessage: true,

      clearResumeAction: true,

    );

    try {

      final UnlockedVaultSession session =

          await ref.read(vaultRepositoryProvider).unlockWithRecoveryKey(recoveryKey);

      await ref.read(vaultRepositoryProvider).ensureIndexReady(session);

      final UnlockedVaultSession synced =

          await ref.read(vaultRepositoryProvider).ensureKeystoreMatchesUnlockMode(session);

      state = AppSessionState(

        status: AppLockStatus.unlocked,

        session: synced,

        message: kRecoveryUnlockSuccessMessage,

      );

    } catch (error) {

      state = state.copyWith(

        status: AppLockStatus.recoveryRequired,

        clearSession: true,

        message: friendlySessionErrorMessage(error),

        clearResumeAction: true,

      );

      rethrow;

    }

  }



  Future<void> lock() async {

    state = state.copyWith(

      status: AppLockStatus.locked,

      clearSession: true,

      message: kAppLockedMessage,

      clearResumeAction: true,

    );

    _pendingResourceCleanup = true;

    await _cleanupUnlockedResourcesIfPossible();

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



  Future<void> reset() async {

    _lastForegroundExitAt = null;

    _activeSensitiveTasks = 0;

    _pendingResourceCleanup = false;

    state = const AppSessionState(status: AppLockStatus.uninitialized);

    await ref.read(vaultRepositoryProvider).closeUnlockedResources();

  }



  Future<void> handleLifecycleChange(AppLifecycleState lifecycleState) async {

    switch (lifecycleState) {

      case AppLifecycleState.hidden:

      case AppLifecycleState.inactive:

      case AppLifecycleState.paused:

        _lastForegroundExitAt ??= clock();

        break;

      case AppLifecycleState.resumed:

        final DateTime? exitAt = _lastForegroundExitAt;

        _lastForegroundExitAt = null;

        if (exitAt == null) {

          return;

        }

        if (!hasSessionTimedOut(

          lastForegroundExitAt: exitAt,

          now: clock(),

          timeout: defaultSessionTimeout,

        )) {

          return;

        }

        await _expireCurrentSession();

        final AppLockService appLock = ref.read(appLockServiceProvider);

        final AppUnlockMode mode = await appLock.getUnlockMode();

        switch (mode) {

          case AppUnlockMode.none:

            state = state.copyWith(resumeAction: ResumeUnlockAction.autoTrusted);

            await unlock();

          case AppUnlockMode.deviceLock:

            state = const AppSessionState(

              status: AppLockStatus.locked,

              message: kUseDeviceLockToUnlockMessage,

              resumeAction: ResumeUnlockAction.keystoreUnlock,

            );

          case AppUnlockMode.biometric:

            state = const AppSessionState(

              status: AppLockStatus.locked,

              message: kStartupNeedsBiometricMessage,

              resumeAction: ResumeUnlockAction.keystoreUnlock,

            );

        }

        break;

      case AppLifecycleState.detached:

        break;

    }

  }



  Future<T> runSensitiveTask<T>(

    Future<T> Function(UnlockedVaultSession session) action,

  ) async {

    final UnlockedVaultSession? session = state.session;

    if (!state.isUnlocked || session == null) {

      throw StateError('目前沒有可用的解鎖 session。');

    }



    _activeSensitiveTasks++;

    try {

      return await action(session);

    } finally {

      _activeSensitiveTasks--;

      await _cleanupUnlockedResourcesIfPossible();

    }

  }



  Future<UnlockOutcome> _restoreTrustedSession({
    required bool deviceCredentialFallback,
    bool afterRestore = false,
  }) async {

    final VaultRepository repository = ref.read(vaultRepositoryProvider);

    final AppLockService appLock = ref.read(appLockServiceProvider);

    final AppUnlockMode mode = await appLock.getUnlockMode();



    if (mode == AppUnlockMode.biometric &&

        deviceCredentialFallback &&

        !await appLock.canUseDeviceCredential()) {

      state = const AppSessionState(

        status: AppLockStatus.locked,

        message: kUnlockModeNeedsDeviceLockMessage,

      );

      return UnlockOutcome.failed;

    }



    beginTrustedUnlock();

    try {

      UnlockedVaultSession session = await repository.openTrustedSession(

        deviceCredentialFallback: mode == AppUnlockMode.biometric && deviceCredentialFallback,

      );

      session = await repository.ensureKeystoreMatchesUnlockMode(session);

      await repository.ensureIndexReady(session);

      state = AppSessionState(

        status: AppLockStatus.unlocked,

        session: session,

      );

      return UnlockOutcome.success;

    } on DeviceKeyUserCancelledException {

      return _handleTrustedDeviceFailure(

        appLock: appLock,

        mode: mode,

        deviceCredentialFallback: deviceCredentialFallback,

        message: kStartupNeedsBiometricMessage,

      );

    } on DeviceKeyAuthFailedException catch (error) {

      return _handleTrustedDeviceFailure(

        appLock: appLock,

        mode: mode,

        deviceCredentialFallback: deviceCredentialFallback,

        message: error.message,

      );

    } on DeviceKeyBiometricNotEnrolledException {

      if (mode == AppUnlockMode.biometric && await appLock.canUseDeviceCredential()) {

        state = const AppSessionState(

          status: AppLockStatus.locked,

          message: kUseDeviceLockToUnlockMessage,

          resumeAction: ResumeUnlockAction.deviceCredentialFallback,

        );

        return UnlockOutcome.needsUserStep;

      }

      state = AppSessionState(

        status: AppLockStatus.locked,

        message: kBiometricNotEnrolledSwitchModeMessage,

      );

      return UnlockOutcome.failed;

    } on DeviceKeyLegacyStateException catch (error) {

      await repository.clearTrustedDeviceAccess();

      state = AppSessionState(

        status: AppLockStatus.recoveryRequired,

        message: error.message,

      );

      return UnlockOutcome.failed;

    } on DeviceKeyInvalidatedException catch (error) {

      await repository.clearTrustedDeviceAccess();

      state = AppSessionState(

        status: AppLockStatus.recoveryRequired,

        message: error.message,

      );

      return UnlockOutcome.failed;

    } on StateError catch (error) {

      await repository.clearTrustedDeviceAccess();

      state = AppSessionState(

        status: AppLockStatus.recoveryRequired,

        message: friendlySessionErrorMessage(
          error,
          afterRestoreTrustedUnlock: afterRestore,
        ),

      );

      return UnlockOutcome.failed;

    } catch (error) {

      final String message = friendlySessionErrorMessage(
        error,
        afterRestoreTrustedUnlock: afterRestore,
      );

      if (error is SecretBoxAuthenticationError) {

        await repository.clearTrustedDeviceAccess();

        state = AppSessionState(

          status: AppLockStatus.recoveryRequired,

          message: message,

        );

        return UnlockOutcome.failed;

      }

      state = AppSessionState(

        status: AppLockStatus.fatalError,

        message: message,

      );

      return UnlockOutcome.failed;

    }

  }



  Future<UnlockOutcome> _handleTrustedDeviceFailure({

    required AppLockService appLock,

    required AppUnlockMode mode,

    required bool deviceCredentialFallback,

    required String message,

  }) async {

    if (mode == AppUnlockMode.biometric &&

        !deviceCredentialFallback &&

        await appLock.canUseDeviceCredential()) {

      state = const AppSessionState(

        status: AppLockStatus.locked,

        message: kBiometricFallbackDeviceLockMessage,

        resumeAction: ResumeUnlockAction.deviceCredentialFallback,

      );

      return UnlockOutcome.needsUserStep;

    }

    state = AppSessionState(

      status: AppLockStatus.locked,

      message: kLockedRetryVerificationMessage,

    );

    return UnlockOutcome.failed;

  }



  Future<void> _expireCurrentSession() async {

    state = state.copyWith(

      status: AppLockStatus.locked,

      clearSession: true,

      message: kAppLockedMessage,

      clearResumeAction: true,

    );

    _pendingResourceCleanup = true;

    await _cleanupUnlockedResourcesIfPossible();

  }



  Future<void> _cleanupUnlockedResourcesIfPossible() async {

    if (!_pendingResourceCleanup) {

      return;

    }

    if (_activeSensitiveTasks > 0) {

      return;

    }

    _pendingResourceCleanup = false;

    await ref.read(vaultRepositoryProvider).closeUnlockedResources();

  }



  AppSessionState get currentState => state;

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

  final AppSessionController controller = ref.read(appSessionProvider.notifier);



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



    final UnlockOutcome outcome = await controller.unlock();

    if (outcome != UnlockOutcome.success) {

      return controller.currentState;

    }

    return controller.currentState;

  } catch (error) {

    final String message = friendlySessionErrorMessage(error);

    if (error is SecretBoxAuthenticationError) {

      await repository.clearTrustedDeviceAccess();

      return AppSessionState(

        status: AppLockStatus.recoveryRequired,

        message: message,

      );

    }

    return AppSessionState(

      status: AppLockStatus.fatalError,

      message: message,

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


