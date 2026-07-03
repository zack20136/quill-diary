import 'dart:async' show Timer;

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
import '../../../shared/platform/vault_platform_support.dart';
import '../../settings/providers/personalization_providers.dart';
import '../session_inactivity_watchdog.dart';
import '../session_messages.dart';
import '../session_route_preservation.dart';
import '../state/app_session_state.dart';
import '../state/session_lock_reason.dart';
import '../state/unlock_result.dart';

export '../state/unlock_result.dart';

/// 冷啟動／還原後的 trusted unlock 週期，用來隔離 bootstrap 與 lifecycle resume。
enum TrustedUnlockStartupPhase {
  /// bootstrap 進行中；lifecycle 背景事件視為無效。
  bootstrapping,

  /// bootstrap 已結束，等待前景穩定期；尚未記錄背景或排 resumed 自動解鎖。
  awaitingFirstBackground,

  /// 前景穩定期已過；可記錄背景並在 resumed 時依鎖定狀態自動解鎖。
  lifecycleResumeArmed,
}

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
  TrustedUnlockStartupPhase _startupPhase =
      TrustedUnlockStartupPhase.bootstrapping;
  int _startupCycleId = 0;
  Future<UnlockOutcome>? _trustedUnlockInFlight;
  CompletedUnlockSnapshot? _completedUnlockSnapshot;
  Timer? _lifecycleResumeArmTimer;

  @visibleForTesting
  SessionInactivityWatchdog get inactivityWatchdog => _inactivityWatchdog;

  @visibleForTesting
  CompletedUnlockSnapshot? get completedUnlockSnapshot =>
      _completedUnlockSnapshot;

  CompletedUnlockSnapshot? consumeCompletedUnlockSnapshot() {
    final CompletedUnlockSnapshot? snapshot = _completedUnlockSnapshot;
    _completedUnlockSnapshot = null;
    return snapshot;
  }

  void _recordCompletedUnlock({
    required UnlockRequestSource source,
    required UnlockOutcome outcome,
    bool recoverable = false,
  }) {
    _completedUnlockSnapshot = CompletedUnlockSnapshot(
      source: source,
      outcome: outcome,
      recoverable: recoverable,
    );
  }

  @override
  AppSessionState build() {
    ref.onDispose(() {
      _inactivityWatchdog.disarm();
      _cancelLifecycleResumeArmTimer();
    });
    ref.listen<AsyncValue<PersonalizationPreferences>>(
      personalizationPreferencesProvider,
      (AsyncValue<PersonalizationPreferences>? previous, next) {
        final PersonalizationPreferences? nextPrefs = next.asData?.value;
        if (nextPrefs == null) {
          return;
        }
        final SessionBackgroundTimeoutMinutes? previousTimeout =
            previous?.asData?.value.sessionTimeoutMinutes;
        if (previousTimeout == nextPrefs.sessionTimeoutMinutes) {
          return;
        }
        onSessionUnlocked();
      },
    );
    return const AppSessionState(status: AppLockStatus.uninitialized);
  }

  bool get shouldUnlockOnResume => state.shouldUnlockOnResume;

  bool get trustedUnlockBootstrapFinished =>
      _startupPhase != TrustedUnlockStartupPhase.bootstrapping;

  bool get trustedUnlockBootstrapActive =>
      _startupPhase == TrustedUnlockStartupPhase.bootstrapping;

  @visibleForTesting
  TrustedUnlockStartupPhase get startupPhase => _startupPhase;

  int get startupCycleId => _startupCycleId;

  /// bootstrap 結束後、尚未進入一般 lifecycle 流程前，session 是否可參與背景逾時等行為。
  bool get canParticipateInLifecycleResumeUnlock =>
      _startupPhase != TrustedUnlockStartupPhase.bootstrapping &&
      state.status != AppLockStatus.unlocking &&
      _trustedUnlockInFlight == null;

  /// 是否可將 paused/hidden 記成後續 resumed 的背景依據。
  bool get canRecordLifecycleBackground =>
      canParticipateInLifecycleResumeUnlock &&
      _startupPhase == TrustedUnlockStartupPhase.lifecycleResumeArmed;

  /// resumed 是否可排程 lifecycle 自動解鎖。
  bool get canScheduleLifecycleResumeUnlock =>
      canParticipateInLifecycleResumeUnlock &&
      _startupPhase == TrustedUnlockStartupPhase.lifecycleResumeArmed;

  @visibleForTesting
  void markTrustedUnlockBootstrapFinished() {
    endTrustedUnlockBootstrap();
  }

  void endTrustedUnlockBootstrap() {
    if (_startupPhase != TrustedUnlockStartupPhase.bootstrapping) {
      return;
    }
    _startupCycleId++;
    _startupPhase = TrustedUnlockStartupPhase.awaitingFirstBackground;
    _scheduleLifecycleResumeArmAfterBootstrapSettle();
  }

  /// bootstrap 成功且前景穩定後，才允許記錄真實背景並排 resumed 自動解鎖。
  void armLifecycleResumeUnlock() {
    _cancelLifecycleResumeArmTimer();
    if (_startupPhase == TrustedUnlockStartupPhase.awaitingFirstBackground) {
      _startupPhase = TrustedUnlockStartupPhase.lifecycleResumeArmed;
    }
  }

  void _scheduleLifecycleResumeArmAfterBootstrapSettle() {
    _cancelLifecycleResumeArmTimer();
    if (_startupPhase != TrustedUnlockStartupPhase.awaitingFirstBackground) {
      return;
    }
    if (!state.isUnlocked || state.session == null) {
      return;
    }
    _lifecycleResumeArmTimer = Timer(kSessionForegroundSettleDelay, () {
      _lifecycleResumeArmTimer = null;
      if (_startupPhase != TrustedUnlockStartupPhase.awaitingFirstBackground) {
        return;
      }
      if (!state.isUnlocked || state.session == null) {
        return;
      }
      armLifecycleResumeUnlock();
    });
  }

  void _cancelLifecycleResumeArmTimer() {
    _lifecycleResumeArmTimer?.cancel();
    _lifecycleResumeArmTimer = null;
  }

  void _beginTrustedUnlockStartupCycle() {
    _cancelLifecycleResumeArmTimer();
    _startupPhase = TrustedUnlockStartupPhase.bootstrapping;
  }

  Future<UnlockOutcome> unlock({
    bool afterRestore = false,
    UnlockRequestSource source = UnlockRequestSource.manual,
  }) async {
    final Future<UnlockOutcome>? inFlight = _trustedUnlockInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final Future<UnlockOutcome> future = _restoreTrustedSession(
      afterRestore: afterRestore,
      source: source,
    );
    _trustedUnlockInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_trustedUnlockInFlight, future)) {
        _trustedUnlockInFlight = null;
      }
    }
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
    _trustedUnlockInFlight = null;
    _completedUnlockSnapshot = null;
    _beginTrustedUnlockStartupCycle();
    state = const AppSessionState(status: AppLockStatus.uninitialized);
    await ref.read(vaultRepositoryProvider).closeUnlockedResources();
  }

  void adoptBootstrapState(AppSessionState next) {
    _inactivityWatchdog.disarm();
    state = next;
    if (next.isUnlocked && next.session != null) {
      onSessionUnlocked();
    }
  }

  /// 還原覆寫 vault 後進入啟動流程，避免與 [appStartupProvider] 並行解鎖。
  Future<void> beginPostRestoreStartup() async {
    _inactivityWatchdog.disarm();
    _activeSensitiveTasks = 0;
    _pendingResourceCleanup = false;
    _beginTrustedUnlockStartupCycle();
    final AppLocalizations l10n = await _loadSessionL10n(ref);
    state = AppSessionState(
      status: AppLockStatus.unlocking,
      message: sessionPostRestoreStartupMessage(l10n),
    );
    await ref.read(vaultRepositoryProvider).closeUnlockedResources();
  }

  void notifyAppBackground() {
    _isInForeground = false;
    if (state.isUnlocked) {
      ref
          .read(sessionRoutePreservationProvider.notifier)
          .savePreBackgroundLocation();
    }
    if (!_shouldWatchInactivity) {
      return;
    }
    _inactivityWatchdog.notifyBackground();
  }

  Future<ForegroundResumeResult> notifyAppForegroundResumed({
    VoidCallback? onForegroundSettled,
  }) {
    _isInForeground = true;
    return _inactivityWatchdog.notifyForegroundResumed(
      onForegroundSettled: onForegroundSettled ?? () {},
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
    if (!state.isUnlocked || !_shouldWatchInactivity) {
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
    final AppLocalizations l10n = await _loadSessionL10n(ref);

    _inactivityWatchdog.disarm();
    state = AppSessionState(
      status: AppLockStatus.unlocking,
      message: sessionTrustedUnlockInProgressMessage(l10n),
    );
    try {
      if (await repository.needsKeystoreMigrationForVault()) {
        final String migrationMessage =
            '$kKeystoreMigrationInProgressMessage '
            '${l10n.sessionKeystoreMigrationMayReverifyMessage}';
        state = state.copyWith(message: migrationMessage);
      }
      final UnlockedVaultSession session = await repository
          .openTrustedSessionEnsuringKeystore();
      state = AppSessionState(status: AppLockStatus.unlocked, session: session);
      onSessionUnlocked();
      _recordCompletedUnlock(source: source, outcome: UnlockOutcome.success);
      return UnlockOutcome.success;
    } on DeviceKeyUserCancelledException {
      return _handleTrustedDeviceFailure(
        source: source,
        recoverable: true,
        preservedLockReason: priorLockReason,
        preservedMessage: priorMessage,
      );
    } on DeviceKeyAuthTimeoutException {
      return _handleTrustedDeviceFailure(
        source: source,
        recoverable: true,
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
      _recordCompletedUnlock(source: source, outcome: UnlockOutcome.failed);
      return UnlockOutcome.failed;
    } on DeviceKeyNoDeviceCredentialException catch (error) {
      state = AppSessionState(
        status: AppLockStatus.locked,
        lockReason: SessionLockReason.authFailed,
        message: error.message,
      );
      _inactivityWatchdog.disarm();
      _recordCompletedUnlock(source: source, outcome: UnlockOutcome.failed);
      return UnlockOutcome.failed;
    } on DeviceKeyAuthFailedException {
      return _handleTrustedDeviceFailure(
        source: source,
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
      _recordCompletedUnlock(source: source, outcome: UnlockOutcome.failed);
      return UnlockOutcome.failed;
    } on DeviceKeyUnsupportedFormatException catch (error) {
      await repository.clearTrustedDeviceAccess();
      state = AppSessionState(
        status: AppLockStatus.recoveryRequired,
        message: error.message,
      );
      _inactivityWatchdog.disarm();
      _recordCompletedUnlock(source: source, outcome: UnlockOutcome.failed);
      return UnlockOutcome.failed;
    } on DeviceKeyInvalidatedException catch (error) {
      await repository.clearTrustedDeviceAccess();
      state = AppSessionState(
        status: AppLockStatus.recoveryRequired,
        message: error.message,
      );
      _inactivityWatchdog.disarm();
      _recordCompletedUnlock(source: source, outcome: UnlockOutcome.failed);
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
      _recordCompletedUnlock(source: source, outcome: UnlockOutcome.failed);
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
        _recordCompletedUnlock(source: source, outcome: UnlockOutcome.failed);
        return UnlockOutcome.failed;
      }
      state = AppSessionState(
        status: AppLockStatus.fatalError,
        message: message,
      );
      _inactivityWatchdog.disarm();
      _recordCompletedUnlock(source: source, outcome: UnlockOutcome.failed);
      return UnlockOutcome.failed;
    }
  }

  Future<UnlockOutcome> _handleTrustedDeviceFailure({
    required UnlockRequestSource source,
    bool recoverable = false,
    SessionLockReason? preservedLockReason,
    String? preservedMessage,
  }) async {
    if (recoverable && preservedLockReason != null) {
      state = AppSessionState(
        status: AppLockStatus.locked,
        lockReason: preservedLockReason,
        message: preservedMessage,
      );
      _inactivityWatchdog.disarm();
      _recordCompletedUnlock(
        source: source,
        outcome: UnlockOutcome.failed,
        recoverable: true,
      );
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
    _recordCompletedUnlock(source: source, outcome: UnlockOutcome.failed);
    return UnlockOutcome.failed;
  }

  Future<void> _expireSession({
    required SessionLockReason lockReason,
    required String message,
  }) async {
    if (lockReason == SessionLockReason.inactivity) {
      ref.read(sessionRoutePreservationProvider.notifier).onInactivityLock();
    }
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
    await ref.read(editorDraftStoreProvider).clearAllMaterializedPendingFiles();
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
  final AppSessionController controller = ref.read(appSessionProvider.notifier);
  try {
    if (!ref.read(supportedPlatformProvider)) {
      final AppSessionState next = AppSessionState(
        status: AppLockStatus.fatalError,
        message: sessionUnsupportedRuntimeMessage(l10n),
      );
      controller.adoptBootstrapState(next);
      return next;
    }

    final VaultRepository repository = ref.read(vaultRepositoryProvider);

    try {
      await repository.initialize();

      final RecoveryMetadata? metadata = await repository
          .readRecoveryMetadata();
      if (metadata == null) {
        final AppSessionState next = AppSessionState(
          status: AppLockStatus.unlocked,
          message: sessionStartupNeedsRecoveryKeyMessage(l10n),
        );
        controller.adoptBootstrapState(next);
        return next;
      }

      final bool hasTrustedDevice = await repository.hasTrustedDeviceAccess();
      if (!hasTrustedDevice) {
        final AppSessionState next = AppSessionState(
          status: AppLockStatus.recoveryRequired,
          message: sessionStartupNeedsTrustedDeviceMessage(l10n),
        );
        controller.adoptBootstrapState(next);
        return next;
      }

      final UnlockOutcome outcome = await controller.unlock();
      if (outcome != UnlockOutcome.success) {
        return ref.read(appSessionProvider);
      }
      return ref.read(appSessionProvider);
    } catch (error) {
      final String message = friendlySessionErrorMessage(l10n, error);
      final AppSessionState next;
      if (error is SecretBoxAuthenticationError ||
          isUnreadableEncryptedIndexError(error)) {
        await repository.clearTrustedDeviceAccess();
        next = AppSessionState(
          status: AppLockStatus.recoveryRequired,
          message: message,
        );
      } else {
        next = AppSessionState(
          status: AppLockStatus.fatalError,
          message: message,
        );
      }
      controller.adoptBootstrapState(next);
      return next;
    }
  } finally {
    controller.endTrustedUnlockBootstrap();
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
