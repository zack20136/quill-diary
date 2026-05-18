import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/recovery/recovery_metadata.dart';
import '../../../domain/security/unlocked_vault_session.dart';
import '../../../infrastructure/security/device_key_manager.dart';
import '../../../infrastructure/storage/vault_repository.dart';
import '../../../shared/providers/core_providers.dart';
import '../session_messages.dart';
import '../session_timeout_policy.dart';
import '../state/app_session_state.dart';

class AppSessionController extends Notifier<AppSessionState> {
  DateTime? _lastForegroundExitAt;
  int _activeSensitiveTasks = 0;
  bool _pendingResourceCleanup = false;

  @override
  AppSessionState build() {
    return const AppSessionState(status: AppLockStatus.uninitialized);
  }

  Future<bool> unlock() async {
    state = state.copyWith(status: AppLockStatus.unlocking, clearMessage: true);
    return _restoreTrustedSession();
  }

  Future<void> unlockWithRecovery(String recoveryKey) async {
    state = state.copyWith(status: AppLockStatus.unlocking, clearMessage: true);
    try {
      final UnlockedVaultSession session =
          await ref.read(unlockWithRecoveryKeyUseCaseProvider).call(recoveryKey);
      await ref.read(vaultRepositoryProvider).ensureIndexReady(session);
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

  Future<void> lock() async {
    state = state.copyWith(
      status: AppLockStatus.locked,
      clearSession: true,
      message: kAppLockedMessage,
    );
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
        _lastForegroundExitAt ??= DateTime.now();
        break;
      case AppLifecycleState.resumed:
        final DateTime? exitAt = _lastForegroundExitAt;
        _lastForegroundExitAt = null;
        if (exitAt == null) {
          return;
        }
        if (!hasSessionTimedOut(
          lastForegroundExitAt: exitAt,
          now: DateTime.now(),
          timeout: defaultSessionTimeout,
        )) {
          return;
        }
        await _expireCurrentSession();
        await _restoreTrustedSession();
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

  Future<bool> _restoreTrustedSession() async {
    final VaultRepository repository = ref.read(vaultRepositoryProvider);
    final bool biometricEnabled = await ref.read(appLockServiceProvider).isBiometricLockEnabled();
    try {
      final UnlockedVaultSession session = await repository.openTrustedSession();
      await repository.ensureIndexReady(session);
      state = AppSessionState(
        status: AppLockStatus.unlocked,
        session: session,
      );
      return true;
    } on DeviceKeyUserCancelledException {
      state = AppSessionState(
        status: AppLockStatus.locked,
        message: biometricEnabled ? kStartupNeedsBiometricMessage : kAppLockedMessage,
      );
      return false;
    } on DeviceKeyAuthFailedException catch (error) {
      state = AppSessionState(
        status: AppLockStatus.locked,
        message: biometricEnabled ? error.message : kUnlockFailedMessage,
      );
      return false;
    } on StateError catch (error) {
      state = AppSessionState(
        status: AppLockStatus.recoveryRequired,
        message: '$error',
      );
      return false;
    } catch (error) {
      state = AppSessionState(
        status: AppLockStatus.fatalError,
        message: '$error',
      );
      return false;
    }
  }

  Future<void> _expireCurrentSession() async {
    state = state.copyWith(
      status: AppLockStatus.locked,
      clearSession: true,
      message: kAppLockedMessage,
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
  final bool biometricEnabled = await ref.read(appLockServiceProvider).isBiometricLockEnabled();

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

    final bool success = await controller.unlock();
    if (!success) {
      return AppSessionState(
        status: AppLockStatus.locked,
        message: biometricEnabled ? kStartupNeedsBiometricMessage : kAppLockedMessage,
      );
    }
    return controller.currentState;
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
