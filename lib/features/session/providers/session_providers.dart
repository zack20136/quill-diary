import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/recovery/recovery_metadata.dart';
import '../../../domain/security/unlocked_vault_session.dart';
import '../../../infrastructure/database/index_database_errors.dart';
import '../../../infrastructure/preferences/personalization_preferences.dart';
import '../../../infrastructure/security/app_lock_service.dart';
import '../../../infrastructure/security/app_unlock_mode.dart';
import '../../../infrastructure/security/unlock_mode_policy.dart';
import '../../../infrastructure/security/device_key_manager.dart';
import '../../../infrastructure/storage/vault_repository.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/providers/core_providers.dart';
import '../../settings/providers/personalization_providers.dart';
import '../session_inactivity_watchdog.dart';
import '../session_messages.dart';
import '../state/app_session_state.dart';
import '../state/session_lock_reason.dart';
import '../state/unlock_result.dart';

enum UnlockRequestSource { manual, lifecycleResume }

AppLocalizations _sessionL10n(Ref ref) {
  final Locale locale = ref
      .read(personalizationPreferencesProvider)
      .maybeWhen(
        data: (PersonalizationPreferences prefs) => prefs.materialLocale,
        orElse: () => appZhLocale,
      );
  return lookupAppLocalizations(locale);
}

Future<AppLocalizations> _loadSessionL10n(Ref ref) async {
  final PersonalizationPreferences? prefs = ref
      .read(personalizationPreferencesProvider)
      .maybeWhen(
        data: (PersonalizationPreferences value) => value,
        orElse: () => null,
      );
  if (prefs != null) {
    return lookupAppLocalizations(prefs.materialLocale);
  }
  final AppLanguage? stored = await ref
      .read(userPreferencesProvider)
      .storedAppLocaleOrNull;
  return lookupAppLocalizations(stored?.materialLocale ?? appZhLocale);
}

/// 管理應用層級 session 狀態與可信 session 還原流程。
class AppSessionController extends Notifier<AppSessionState> {
  final SessionInactivityWatchdog _inactivityWatchdog =
      SessionInactivityWatchdog();
  int _activeSensitiveTasks = 0;
  bool _pendingResourceCleanup = false;
  bool _isInForeground = true;

  @visibleForTesting
  SessionInactivityWatchdog get inactivityWatchdog => _inactivityWatchdog;

  @override
  AppSessionState build() {
    ref.onDispose(_inactivityWatchdog.disarm);
    return const AppSessionState(status: AppLockStatus.uninitialized);
  }

  bool get shouldUnlockOnResume => state.shouldUnlockOnResume;

  Future<UnlockOutcome> unlock({
    bool afterRestore = false,
    UnlockRequestSource source = UnlockRequestSource.manual,
  }) async {
    return _restoreTrustedSession(afterRestore: afterRestore, source: source);
  }

  Future<void> unlockWithRecovery(String recoveryKey) async {
    _inactivityWatchdog.disarm();
    final AppLocalizations l10n = await _loadSessionL10n(ref);
    state = state.copyWith(
      status: AppLockStatus.unlocking,
      clearMessage: true,
      clearLockReason: true,
    );
    try {
      final UnlockedVaultSession session = await ref
          .read(vaultRepositoryProvider)
          .unlockWithRecoveryKey(recoveryKey);
      await ref.read(vaultRepositoryProvider).ensureIndexReady(session);
      final UnlockedVaultSession synced = await ref
          .read(vaultRepositoryProvider)
          .ensureKeystoreMatchesUnlockMode(session);
      state = AppSessionState(
        status: AppLockStatus.unlocked,
        session: synced,
        message: sessionRecoveryUnlockSuccessMessage(l10n),
      );
      onSessionUnlocked();
    } catch (error) {
      state = state.copyWith(
        status: AppLockStatus.recoveryRequired,
        clearSession: true,
        message: friendlySessionErrorMessage(l10n, error),
        clearLockReason: true,
      );
      rethrow;
    }
  }

  Future<void> lock() async {
    _inactivityWatchdog.disarm();
    final AppLocalizations l10n = await _loadSessionL10n(ref);
    await _expireSession(
      lockReason: SessionLockReason.manual,
      message: sessionAppLockedMessage(l10n),
    );
  }

  void activateSession(UnlockedVaultSession session, {String? message}) {
    _applyState(
      AppSessionState(
        status: AppLockStatus.unlocked,
        session: session,
        message: message,
      ),
    );
  }

  Future<void> reset() async {
    _inactivityWatchdog.disarm();
    _activeSensitiveTasks = 0;
    _pendingResourceCleanup = false;
    state = const AppSessionState(status: AppLockStatus.uninitialized);
    await ref.read(vaultRepositoryProvider).closeUnlockedResources();
  }

  /// 還原覆寫 vault 後進入啟動流程，避免與 [appStartupProvider] 並行解鎖。
  Future<void> beginPostRestoreStartup() async {
    _inactivityWatchdog.disarm();
    _activeSensitiveTasks = 0;
    _pendingResourceCleanup = false;
    final AppLocalizations l10n = await _loadSessionL10n(ref);
    state = AppSessionState(
      status: AppLockStatus.unlocking,
      message: sessionPostRestoreStartupMessage(l10n),
    );
    await ref.read(vaultRepositoryProvider).closeUnlockedResources();
  }

  void notifyAppBackground() {
    _isInForeground = false;
    if (!_shouldWatchInactivity) {
      return;
    }
    _inactivityWatchdog.notifyBackground();
  }

  Future<ForegroundResumeResult> notifyAppForegroundResumed({
    required VoidCallback onForegroundSettled,
  }) {
    _isInForeground = true;
    return _inactivityWatchdog.notifyForegroundResumed(
      onForegroundSettled: onForegroundSettled,
    );
  }

  void notifyUserInteraction() {
    if (!state.isUnlocked) {
      return;
    }
    _inactivityWatchdog.notifyUserInteraction();
  }

  Future<void> expireFromInactivity() async {
    if (!state.isUnlocked || _activeSensitiveTasks > 0) {
      return;
    }
    final AppLockService appLock = ref.read(appLockServiceProvider);
    final AppUnlockMode mode = await appLock.getUnlockMode();
    final AppLocalizations l10n = await _loadSessionL10n(ref);
    await _expireSession(
      lockReason: SessionLockReason.inactivity,
      message: lockedResumeMessageFor(mode, l10n: l10n),
    );
    _inactivityWatchdog.disarm();
  }

  void onSessionUnlocked() {
    _inactivityWatchdog.disarm();
    if (!state.isUnlocked) {
      return;
    }
    _inactivityWatchdog.arm(
      timeout: readSessionBackgroundTimeout(ref),
      onExpired: expireFromInactivity,
    );
    if (!_isInForeground) {
      _inactivityWatchdog.notifyBackground();
    }
  }

  Future<T> runSensitiveTask<T>(
    Future<T> Function(UnlockedVaultSession session) action,
  ) async {
    final UnlockedVaultSession? session = state.session;
    if (!state.isUnlocked || session == null) {
      throw StateError('目前沒有可用的解鎖 session。');
    }

    return _runWithSensitiveTaskGuard(() => action(session));
  }

  /// 無解鎖 session 的長時間任務（例如還原），避免背景逾時鎖定。
  Future<T> runBackgroundSafeTask<T>(Future<T> Function() action) {
    return _runWithSensitiveTaskGuard(action);
  }

  Future<T> _runWithSensitiveTaskGuard<T>(Future<T> Function() action) async {
    _inactivityWatchdog.disarm();
    _activeSensitiveTasks++;
    try {
      return await action();
    } finally {
      _activeSensitiveTasks--;
      if (state.isUnlocked) {
        onSessionUnlocked();
      }
      await _cleanupUnlockedResourcesIfPossible();
    }
  }

  Future<UnlockOutcome> _restoreTrustedSession({
    bool afterRestore = false,
    UnlockRequestSource source = UnlockRequestSource.manual,
  }) async {
    final VaultRepository repository = ref.read(vaultRepositoryProvider);
    final String? priorMessage = state.message;
    final SessionLockReason? priorLockReason = state.lockReason;
    final bool shouldPreserveLockState =
        source == UnlockRequestSource.lifecycleResume &&
        state.shouldUnlockOnResume;
    final AppLocalizations l10n = await _loadSessionL10n(ref);

    _inactivityWatchdog.disarm();
    state = AppSessionState(
      status: AppLockStatus.unlocking,
      message: sessionTrustedUnlockInProgressMessage(l10n),
    );
    try {
      UnlockedVaultSession session = await repository.openTrustedSession();
      if (await repository.needsKeystoreMigration(session)) {
        state = state.copyWith(message: kKeystoreMigrationInProgressMessage);
      }
      session = await repository.ensureKeystoreMatchesUnlockMode(session);
      await repository.ensureIndexReady(session);
      state = AppSessionState(status: AppLockStatus.unlocked, session: session);
      onSessionUnlocked();
      return UnlockOutcome.success;
    } on DeviceKeyUserCancelledException {
      return _handleTrustedDeviceFailure(
        source: source,
        recoverable: true,
        preserveLockState: shouldPreserveLockState,
        preservedLockReason: priorLockReason,
        preservedMessage: priorMessage,
      );
    } on DeviceKeyAuthTimeoutException {
      return _handleTrustedDeviceFailure(
        source: source,
        recoverable: true,
        preserveLockState: shouldPreserveLockState,
        preservedLockReason: priorLockReason,
        preservedMessage: priorMessage,
      );
    } on DeviceKeyAuthLockoutException catch (error) {
      state = AppSessionState(
        status: AppLockStatus.locked,
        lockReason: SessionLockReason.authFailed,
        message: error.message,
      );
      _inactivityWatchdog.disarm();
      return UnlockOutcome.failed;
    } on DeviceKeyNoDeviceCredentialException catch (error) {
      state = AppSessionState(
        status: AppLockStatus.locked,
        lockReason: SessionLockReason.authFailed,
        message: error.message,
      );
      _inactivityWatchdog.disarm();
      return UnlockOutcome.failed;
    } on DeviceKeyAuthFailedException {
      return _handleTrustedDeviceFailure(
        source: source,
        preserveLockState: shouldPreserveLockState,
        preservedLockReason: priorLockReason,
        preservedMessage: priorMessage,
      );
    } on DeviceKeyBiometricNotEnrolledException {
      state = AppSessionState(
        status: AppLockStatus.locked,
        lockReason: SessionLockReason.authFailed,
        message: _sessionL10n(ref).sessionBiometricNotEnrolledSwitchModeMessage,
      );
      _inactivityWatchdog.disarm();
      return UnlockOutcome.failed;
    } on DeviceKeyUnsupportedFormatException catch (error) {
      await repository.clearTrustedDeviceAccess();
      state = AppSessionState(
        status: AppLockStatus.recoveryRequired,
        message: error.message,
      );
      _inactivityWatchdog.disarm();
      return UnlockOutcome.failed;
    } on DeviceKeyInvalidatedException catch (error) {
      await repository.clearTrustedDeviceAccess();
      state = AppSessionState(
        status: AppLockStatus.recoveryRequired,
        message: error.message,
      );
      _inactivityWatchdog.disarm();
      return UnlockOutcome.failed;
    } on StateError catch (error) {
      await repository.clearTrustedDeviceAccess();
      state = AppSessionState(
        status: AppLockStatus.recoveryRequired,
        message: friendlySessionErrorMessage(
          l10n,
          error,
          afterRestoreTrustedUnlock: afterRestore,
        ),
      );
      _inactivityWatchdog.disarm();
      return UnlockOutcome.failed;
    } catch (error) {
      final String message = friendlySessionErrorMessage(
        l10n,
        error,
        afterRestoreTrustedUnlock: afterRestore,
      );
      if (error is SecretBoxAuthenticationError ||
          isUnreadableEncryptedIndexError(error)) {
        await repository.clearTrustedDeviceAccess();
        state = AppSessionState(
          status: AppLockStatus.recoveryRequired,
          message: message,
        );
        _inactivityWatchdog.disarm();
        return UnlockOutcome.failed;
      }
      state = AppSessionState(
        status: AppLockStatus.fatalError,
        message: message,
      );
      _inactivityWatchdog.disarm();
      return UnlockOutcome.failed;
    }
  }

  Future<UnlockOutcome> _handleTrustedDeviceFailure({
    required UnlockRequestSource source,
    bool recoverable = false,
    bool preserveLockState = false,
    SessionLockReason? preservedLockReason,
    String? preservedMessage,
  }) async {
    if (source == UnlockRequestSource.lifecycleResume &&
        recoverable &&
        preserveLockState) {
      state = AppSessionState(
        status: AppLockStatus.locked,
        lockReason: preservedLockReason,
        message: preservedMessage,
      );
      _inactivityWatchdog.disarm();
      return UnlockOutcome.failed;
    }
    state = AppSessionState(
      status: AppLockStatus.locked,
      lockReason: SessionLockReason.authFailed,
      message: sessionLockedRetryVerificationMessage(
        await _loadSessionL10n(ref),
      ),
    );
    _inactivityWatchdog.disarm();
    return UnlockOutcome.failed;
  }

  Future<void> _expireSession({
    required SessionLockReason lockReason,
    required String message,
  }) async {
    state = AppSessionState(
      status: AppLockStatus.locked,
      lockReason: lockReason,
      message: message,
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

  bool get _shouldWatchInactivity =>
      state.isUnlocked && _activeSensitiveTasks == 0;

  void _applyState(AppSessionState next) {
    _inactivityWatchdog.disarm();
    state = next;
    if (next.isUnlocked && next.session != null) {
      onSessionUnlocked();
    }
  }

  /// 還原流程持有的是 [WidgetRef]，透過此入口接到共用啟動邏輯。
  Future<AppSessionState> bootstrapAfterRestore() {
    return bootstrapAppSession(ref);
  }

  /// 同 vault 還原後沿用還原前已解鎖 session，不再要求生物驗證或螢幕鎖。
  Future<AppSessionState> resumeSessionAfterRestore(
    UnlockedVaultSession priorSession,
  ) async {
    final VaultRepository repository = ref.read(vaultRepositoryProvider);
    final AppLocalizations l10n = await _loadSessionL10n(ref);

    _inactivityWatchdog.disarm();
    state = AppSessionState(
      status: AppLockStatus.unlocking,
      message: sessionPostRestoreStartupMessage(l10n),
    );

    try {
      await repository.initialize();
      final UnlockedVaultSession session = await repository
          .resumeUnlockedSessionAfterRestore(priorSession);
      await repository.ensureIndexReady(session);
      state = AppSessionState(status: AppLockStatus.unlocked, session: session);
      onSessionUnlocked();
      return state;
    } catch (error) {
      return _recoveryRequiredAfterRestore(repository, error);
    }
  }

  Future<AppSessionState> _recoveryRequiredAfterRestore(
    VaultRepository repository,
    Object error,
  ) async {
    final AppLocalizations l10n = await _loadSessionL10n(ref);
    if (error is SecretBoxAuthenticationError ||
        isUnreadableEncryptedIndexError(error)) {
      await repository.clearTrustedDeviceAccess();
    }
    final AppSessionState next = AppSessionState(
      status: AppLockStatus.recoveryRequired,
      message: friendlySessionErrorMessage(
        l10n,
        error,
        afterRestoreTrustedUnlock: true,
      ),
    );
    state = next;
    _inactivityWatchdog.disarm();
    return next;
  }

  /// 同 vault 還原後無法接續 session 時，改要求復原金鑰而非 Keystore 驗證。
  AppSessionState enterRecoveryRequiredAfterRestore() {
    final AppSessionState next = AppSessionState(
      status: AppLockStatus.recoveryRequired,
      message: sessionTrustedUnlockFailedAfterRestoreMessage(_sessionL10n(ref)),
    );
    state = next;
    _inactivityWatchdog.disarm();
    return next;
  }
}

final appSessionProvider =
    NotifierProvider<AppSessionController, AppSessionState>(
      AppSessionController.new,
    );

/// 冷啟動或還原後重新建立應用 session（請在還原流程直接呼叫，避免與 provider 並行）。
Future<AppSessionState> bootstrapAppSession(Ref ref) async {
  final AppLocalizations l10n = await _loadSessionL10n(ref);
  if (!ref.read(supportedPlatformProvider)) {
    return AppSessionState(
      status: AppLockStatus.fatalError,
      message: sessionAndroidOnlyMessage(l10n),
    );
  }

  final VaultRepository repository = ref.read(vaultRepositoryProvider);
  final AppSessionController controller = ref.read(appSessionProvider.notifier);

  try {
    await repository.initialize();

    final RecoveryMetadata? metadata = await repository.readRecoveryMetadata();
    if (metadata == null) {
      return AppSessionState(
        status: AppLockStatus.unlocked,
        message: sessionStartupNeedsRecoveryKeyMessage(l10n),
      );
    }

    final bool hasTrustedDevice = await repository.hasTrustedDeviceAccess();
    if (!hasTrustedDevice) {
      return AppSessionState(
        status: AppLockStatus.recoveryRequired,
        message: sessionStartupNeedsTrustedDeviceMessage(l10n),
      );
    }

    final UnlockOutcome outcome = await controller.unlock();
    if (outcome != UnlockOutcome.success) {
      return ref.read(appSessionProvider);
    }
    return ref.read(appSessionProvider);
  } catch (error) {
    final String message = friendlySessionErrorMessage(l10n, error);
    if (error is SecretBoxAuthenticationError ||
        isUnreadableEncryptedIndexError(error)) {
      await repository.clearTrustedDeviceAccess();
      return AppSessionState(
        status: AppLockStatus.recoveryRequired,
        message: message,
      );
    }
    return AppSessionState(status: AppLockStatus.fatalError, message: message);
  }
}

final appStartupProvider = FutureProvider<AppSessionState>((Ref ref) async {
  return bootstrapAppSession(ref);
});

final effectiveAppSessionProvider = FutureProvider<AppSessionState>((
  Ref ref,
) async {
  final AppSessionState localState = ref.watch(appSessionProvider);
  if (localState.status != AppLockStatus.uninitialized) {
    return localState;
  }
  return ref.watch(appStartupProvider.future);
});

final activeVaultSessionProvider = FutureProvider<UnlockedVaultSession?>((
  Ref ref,
) async {
  final AppSessionState sessionState = await ref.watch(
    effectiveAppSessionProvider.future,
  );
  return sessionState.isUnlocked ? sessionState.session : null;
});
