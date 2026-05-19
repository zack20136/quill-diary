import 'package:flutter/foundation.dart';
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

/// 管理 app-level session 狀態與 trusted session 還原流程。
///
/// 這個 controller 是整個啟動流程的唯一狀態入口，負責：
/// - 啟動時嘗試還原 trusted session
/// - app 進入背景後的逾時鎖定
/// - Recovery Key 解鎖後重新啟用 session
/// - 敏感操作期間延後清理已解鎖資源
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

  /// 嘗試從 trusted device 狀態還原目前 session。
  Future<bool> unlock() async {
    state = state.copyWith(status: AppLockStatus.unlocking, clearMessage: true);
    return _restoreTrustedSession();
  }

  Future<void> unlockWithRecovery(String recoveryKey) async {
    state = state.copyWith(status: AppLockStatus.unlocking, clearMessage: true);
    try {
      final UnlockedVaultSession session =
          await ref.read(vaultRepositoryProvider).unlockWithRecoveryKey(recoveryKey);
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

  /// 直接以既有 session 啟用 app 狀態，通常用於 Recovery Key 完成後。
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

  /// 根據 app lifecycle 判斷 session 是否逾時，必要時重新鎖定。
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
        await _restoreTrustedSession();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  /// 包裝需要已解鎖保險庫的操作，避免呼叫端自行重複檢查 session。
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

  /// 啟動與逾時恢復都共用這條 trusted session 還原路徑。
  ///
  /// 破壞性策略下，legacy / invalidated / 不可辨識的 trusted state
  /// 會直接清掉並收斂到 `recoveryRequired`，不嘗試相容舊格式。
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
    } on DeviceKeyLegacyStateException catch (error) {
      await repository.clearTrustedDeviceAccess();
      state = AppSessionState(
        status: AppLockStatus.recoveryRequired,
        message: error.message,
      );
      return false;
    } on DeviceKeyInvalidatedException catch (error) {
      await repository.clearTrustedDeviceAccess();
      state = AppSessionState(
        status: AppLockStatus.recoveryRequired,
        message: error.message,
      );
      return false;
    } on StateError catch (error) {
      await repository.clearTrustedDeviceAccess();
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

  /// 只有在沒有敏感操作進行時，才真正釋放已解鎖資源。
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

/// 全域 app session state 的單一來源。
final appSessionProvider = NotifierProvider<AppSessionController, AppSessionState>(
  AppSessionController.new,
);

/// 啟動時初始化保險庫、檢查 Recovery Key 與 trusted device 狀態。
///
/// 若沒有 Recovery Key，代表是首次建立保險庫，直接進入 unlocked 狀態；
/// 若 trusted device 不存在或不相容，則導向 `recoveryRequired`。
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

    final bool success = await controller.unlock();
    if (!success) {
      return controller.currentState;
    }
    return controller.currentState;
  } catch (error) {
    return AppSessionState(
      status: AppLockStatus.fatalError,
      message: '$error',
    );
  }
});

/// 合併啟動初始狀態與本地互動後的新狀態，供 UI 統一觀察。
final effectiveAppSessionProvider = FutureProvider<AppSessionState>((Ref ref) async {
  final AppSessionState startupState = await ref.watch(appStartupProvider.future);
  final AppSessionState localState = ref.watch(appSessionProvider);
  if (localState.status == AppLockStatus.uninitialized) {
    return startupState;
  }
  return localState;
});

/// 只暴露目前可用的已解鎖 vault session，避免 UI 直接碰觸完整 app state。
final activeVaultSessionProvider = FutureProvider<UnlockedVaultSession?>((Ref ref) async {
  final AppSessionState sessionState = await ref.watch(effectiveAppSessionProvider.future);
  return sessionState.isUnlocked ? sessionState.session : null;
});
