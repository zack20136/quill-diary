import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/security/unlocked_vault_session.dart';
import '../../../infrastructure/preferences/personalization_preferences.dart';
import '../../../infrastructure/security/app_lock_service.dart';
import '../../../infrastructure/security/app_unlock_mode.dart';
import '../../../infrastructure/security/unlock_mode_policy.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/providers/core_providers.dart';
import '../../settings/providers/personalization_providers.dart';
import '../session_inactivity_watchdog.dart';
import '../session_navigation_coordinator.dart';
import '../session_messages.dart';
import '../session_resume_coordinator.dart';
import '../session_startup_coordinator.dart';
import '../state/app_session_state.dart';
import '../state/session_lock_reason.dart';
import '../state/unlock_result.dart';

export '../state/unlock_result.dart';

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

class AppSessionController extends Notifier<AppSessionState> {
  final SessionResumeCoordinator _resumeCoordinator = SessionResumeCoordinator();
  Future<UnlockOutcome>? _trustedUnlockInFlight;

  SessionStartupCoordinator get _startupCoordinator =>
      SessionStartupCoordinator(ref);
  SessionNavigationCoordinator get _navigationCoordinator =>
      SessionNavigationCoordinator(ref);

  @visibleForTesting
  SessionResumeCoordinator get resumeCoordinator => _resumeCoordinator;

  @override
  AppSessionState build() {
    ref.onDispose(_resumeCoordinator.dispose);
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

  bool get shouldUnlockOnResume =>
      _resumeCoordinator.shouldUnlockOnResume(state);

  bool get trustedUnlockBootstrapFinished =>
      _resumeCoordinator.trustedUnlockBootstrapFinished;

  bool get trustedUnlockBootstrapActive =>
      _resumeCoordinator.trustedUnlockBootstrapActive;

  SessionStartupPhase get startupPhase => _resumeCoordinator.startupPhase;

  int get startupCycleId => _resumeCoordinator.startupCycleId;

  bool get canParticipateInLifecycleResumeUnlock => _resumeCoordinator
      .canParticipateInLifecycleResumeUnlock(state, _trustedUnlockInFlight);

  bool get canRecordLifecycleBackground =>
      _resumeCoordinator.canRecordLifecycleBackground(
        state,
        _trustedUnlockInFlight,
      );

  bool get canScheduleLifecycleResumeUnlock =>
      _resumeCoordinator.canScheduleLifecycleResumeUnlock(
        state,
        _trustedUnlockInFlight,
      );

  @visibleForTesting
  void markTrustedUnlockBootstrapFinished() {
    endTrustedUnlockBootstrap();
  }

  void endTrustedUnlockBootstrap() {
    _resumeCoordinator.endTrustedUnlockBootstrap(state);
  }

  void armLifecycleResumeUnlock() {
    _resumeCoordinator.armLifecycleResumeUnlock();
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
    _resumeCoordinator.disarm();
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
    _resumeCoordinator.disarm();
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
    _resumeCoordinator.reset();
    _trustedUnlockInFlight = null;
    state = const AppSessionState(status: AppLockStatus.uninitialized);
    await ref.read(vaultRepositoryProvider).closeUnlockedResources();
  }

  void adoptBootstrapState(AppSessionState next) {
    _resumeCoordinator.disarm();
    state = next;
    if (next.isUnlocked && next.session != null) {
      onSessionUnlocked();
    }
  }

  Future<void> beginPostRestoreStartup() async {
    _resumeCoordinator.beginPostRestoreStartup();
    final AppLocalizations l10n = await _loadSessionL10n(ref);
    state = AppSessionState(
      status: AppLockStatus.unlocking,
      message: sessionPostRestoreStartupMessage(l10n),
    );
    await ref.read(vaultRepositoryProvider).closeUnlockedResources();
  }

  void notifyAppBackground() {
    _resumeCoordinator.notifyAppBackground(
      state: state,
      saveCurrentRouteBeforeBackground:
          _navigationCoordinator.saveCurrentRouteBeforeBackground,
    );
  }

  Future<ForegroundResumeResult> notifyAppForegroundResumed({
    VoidCallback? onForegroundSettled,
  }) {
    return _resumeCoordinator.notifyAppForegroundResumed(
      onForegroundSettled: onForegroundSettled,
    );
  }

  void notifyUserInteraction() {
    _resumeCoordinator.notifyUserInteraction(state);
  }

  Future<void> expireFromInactivity() async {
    if (!state.isUnlocked || _resumeCoordinator.hasActiveSensitiveTasks()) {
      return;
    }
    final AppLockService appLock = ref.read(appLockServiceProvider);
    final AppUnlockMode mode = await appLock.getUnlockMode();
    final AppLocalizations l10n = await _loadSessionL10n(ref);
    await _expireSession(
      lockReason: SessionLockReason.inactivity,
      message: lockedResumeMessageFor(mode, l10n: l10n),
    );
    _resumeCoordinator.disarm();
  }

  void onSessionUnlocked() {
    _resumeCoordinator.onSessionUnlocked(
      state: state,
      timeout: readSessionBackgroundTimeout(ref),
      onExpired: expireFromInactivity,
    );
  }

  Future<T> runSensitiveTask<T>(
    Future<T> Function(UnlockedVaultSession session) action,
  ) async {
    final UnlockedVaultSession? session = state.session;
    if (!state.isUnlocked || session == null) {
      throw StateError('目前沒有可用的已解鎖 session。');
    }

    return _runWithSensitiveTaskGuard(() => action(session));
  }

  Future<T> runBackgroundSafeTask<T>(Future<T> Function() action) {
    return _runWithSensitiveTaskGuard(action);
  }

  Future<T> _runWithSensitiveTaskGuard<T>(Future<T> Function() action) async {
    return _resumeCoordinator.runProtectedTask(
      action: action,
      isSessionStillUnlocked: () => state.isUnlocked && state.session != null,
      onUnlockedStateStillActive: onSessionUnlocked,
      cleanupUnlockedResourcesIfPossible: _cleanupUnlockedResourcesIfPossible,
    );
  }

  Future<UnlockOutcome> _restoreTrustedSession({
    bool afterRestore = false,
    UnlockRequestSource source = UnlockRequestSource.manual,
  }) async {
    return _startupCoordinator.unlockTrustedSession(
      currentState: state,
      afterRestore: afterRestore,
      source: source,
      applyState: _setState,
      activateUnlockedState: _activateUnlockedState,
      disarmSessionWatchdog: _disarmSessionWatchdog,
      loadKeystoreMigrationMessage: () async {
        final AppLocalizations l10n = await _loadSessionL10n(ref);
        return '$kKeystoreMigrationInProgressMessage '
            '${l10n.sessionKeystoreMigrationMayReverifyMessage}';
      },
      friendlyErrorMessage: (
        Object error, {
        bool afterRestoreTrustedUnlock = false,
      }) async {
        final AppLocalizations l10n = await _loadSessionL10n(ref);
        return friendlySessionErrorMessage(
          l10n,
          error,
          afterRestoreTrustedUnlock: afterRestoreTrustedUnlock,
        );
      },
      loadRetryVerificationMessage: () async {
        return sessionLockedRetryVerificationMessage(
          await _loadSessionL10n(ref),
        );
      },
      loadBiometricNotEnrolledMessage: () async {
        return _sessionL10n(ref).sessionBiometricNotEnrolledSwitchModeMessage;
      },
      loadTrustedUnlockProgressMessage: () async {
        return sessionTrustedUnlockInProgressMessage(
          await _loadSessionL10n(ref),
        );
      },
      recordUnlockResult: _recordUnlockResult,
    );
  }

  Future<void> _recordUnlockResult(SessionUnlockResultEvent event) async {
    _navigationCoordinator.publishUnlockNavigation(event, state);
  }

  Future<void> _expireSession({
    required SessionLockReason lockReason,
    required String message,
  }) async {
    if (lockReason == SessionLockReason.inactivity) {
      _navigationCoordinator.saveLockedRestoreRoute();
    }
    state = AppSessionState(
      status: AppLockStatus.locked,
      lockReason: lockReason,
      message: message,
    );
    _resumeCoordinator.markPendingCleanup();
    await _cleanupUnlockedResourcesIfPossible();
  }

  Future<void> _cleanupUnlockedResourcesIfPossible() async {
    await _resumeCoordinator.cleanupUnlockedResourcesIfPossible(() async {
      await ref
          .read(editorDraftStoreProvider)
          .clearAllMaterializedPendingFiles();
      await ref.read(vaultRepositoryProvider).closeUnlockedResources();
    });
  }

  void _applyState(AppSessionState next) {
    _resumeCoordinator.disarm();
    state = next;
    if (next.isUnlocked && next.session != null) {
      onSessionUnlocked();
    }
  }

  Future<AppSessionState> bootstrapAfterRestore() {
    return _bootstrapSession();
  }

  Future<AppSessionState> resumeSessionAfterRestore(
    UnlockedVaultSession priorSession,
  ) async {
    return _startupCoordinator.resumeSessionAfterRestore(
      priorSession,
      applyState: _setState,
      activateUnlockedState: _activateUnlockedState,
      friendlyErrorMessage: (
        Object error, {
        bool afterRestoreTrustedUnlock = false,
      }) async {
        final AppLocalizations l10n = await _loadSessionL10n(ref);
        return friendlySessionErrorMessage(
          l10n,
          error,
          afterRestoreTrustedUnlock: afterRestoreTrustedUnlock,
        );
      },
      disarmSessionWatchdog: _disarmSessionWatchdog,
    );
  }

  AppSessionState enterRecoveryRequiredAfterRestore() {
    final AppSessionState next = AppSessionState(
      status: AppLockStatus.recoveryRequired,
      message: sessionTrustedUnlockFailedAfterRestoreMessage(_sessionL10n(ref)),
    );
    state = next;
    _resumeCoordinator.disarm();
    return next;
  }

  Future<AppSessionState> _setState(AppSessionState next) async {
    state = next;
    return next;
  }

  Future<void> _activateUnlockedState(AppSessionState next) async {
    state = next;
    onSessionUnlocked();
  }

  Future<void> _disarmSessionWatchdog() async {
    _resumeCoordinator.disarm();
  }

  Future<AppSessionState> _bootstrapSession() async {
    try {
      return await _startupCoordinator.bootstrapSession(
        adoptBootstrapState: (AppSessionState next) async {
          adoptBootstrapState(next);
          return next;
        },
        unlock: unlock,
        readCurrentState: () => state,
        loadUnsupportedRuntimeMessage: () async {
          return sessionUnsupportedRuntimeMessage(await _loadSessionL10n(ref));
        },
        loadStartupNeedsRecoveryKeyMessage: () async {
          return sessionStartupNeedsRecoveryKeyMessage(
            await _loadSessionL10n(ref),
          );
        },
        loadStartupNeedsTrustedDeviceMessage: () async {
          return sessionStartupNeedsTrustedDeviceMessage(
            await _loadSessionL10n(ref),
          );
        },
        friendlyErrorMessage: (
          Object error, {
          bool afterRestoreTrustedUnlock = false,
        }) async {
          final AppLocalizations l10n = await _loadSessionL10n(ref);
          return friendlySessionErrorMessage(
            l10n,
            error,
            afterRestoreTrustedUnlock: afterRestoreTrustedUnlock,
          );
        },
      );
    } finally {
      endTrustedUnlockBootstrap();
    }
  }
}

final appSessionProvider =
    NotifierProvider<AppSessionController, AppSessionState>(
      AppSessionController.new,
    );

final sessionStartupProvider = FutureProvider<AppSessionState>((Ref ref) async {
  return ref.read(appSessionProvider.notifier)._bootstrapSession();
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

final activeVaultSessionProvider = FutureProvider<UnlockedVaultSession?>((Ref ref) async {
  final AppSessionState sessionState = await ref.watch(
    effectiveAppSessionProvider.future,
  );
  return sessionState.isUnlocked ? sessionState.session : null;
});
