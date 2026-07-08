import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/database/index_database_errors.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/shared/platform/vault_platform_support.dart';
import 'state/app_session_state.dart';
import 'state/session_lock_reason.dart';
import 'state/unlock_result.dart';

class SessionStartupCoordinator {
  const SessionStartupCoordinator(this._ref);

  final Ref _ref;

  Future<UnlockOutcome> unlockTrustedSession({
    required AppSessionState currentState,
    required Future<AppSessionState> Function(AppSessionState next) applyState,
    required Future<void> Function(AppSessionState next) activateUnlockedState,
    required Future<void> Function() disarmSessionWatchdog,
    required Future<String> Function() loadKeystoreMigrationMessage,
    required Future<String> Function(
      Object error, {
      bool afterRestoreTrustedUnlock,
    })
    friendlyErrorMessage,
    required Future<String> Function() loadRetryVerificationMessage,
    required Future<String> Function() loadBiometricNotEnrolledMessage,
    required Future<String> Function() loadTrustedUnlockProgressMessage,
    required Future<void> Function(SessionUnlockResultEvent event)
    recordUnlockResult,
    bool afterRestore = false,
    UnlockRequestSource source = UnlockRequestSource.manual,
  }) async {
    final VaultRepository repository = _ref.read(vaultRepositoryProvider);
    final String? priorMessage = currentState.message;
    final SessionLockReason? priorLockReason = currentState.lockReason;

    await disarmSessionWatchdog();
    await applyState(
      AppSessionState(
        status: AppLockStatus.unlocking,
        message: await loadTrustedUnlockProgressMessage(),
      ),
    );
    try {
      if (await repository.needsKeystoreMigrationForVault()) {
        await applyState(
          AppSessionState(
            status: AppLockStatus.unlocking,
            message: await loadKeystoreMigrationMessage(),
          ),
        );
      }
      final UnlockedVaultSession session = await repository
          .openTrustedSessionEnsuringKeystore();
      final AppSessionState next = AppSessionState(
        status: AppLockStatus.unlocked,
        session: session,
      );
      await activateUnlockedState(next);
      await recordUnlockResult(
        SessionUnlockResultEvent(
          source: source,
          outcome: UnlockOutcome.success,
        ),
      );
      return UnlockOutcome.success;
    } on DeviceKeyUserCancelledException {
      return _handleTrustedDeviceFailure(
        source: source,
        recoverable: true,
        preservedLockReason: priorLockReason,
        preservedMessage: priorMessage,
        applyState: applyState,
        disarmSessionWatchdog: disarmSessionWatchdog,
        loadRetryVerificationMessage: loadRetryVerificationMessage,
        recordUnlockResult: recordUnlockResult,
      );
    } on DeviceKeyAuthTimeoutException {
      return _handleTrustedDeviceFailure(
        source: source,
        recoverable: true,
        preservedLockReason: priorLockReason,
        preservedMessage: priorMessage,
        applyState: applyState,
        disarmSessionWatchdog: disarmSessionWatchdog,
        loadRetryVerificationMessage: loadRetryVerificationMessage,
        recordUnlockResult: recordUnlockResult,
      );
    } on DeviceKeyAuthLockoutException catch (error) {
      await applyState(
        AppSessionState(
          status: AppLockStatus.locked,
          lockReason: SessionLockReason.authFailed,
          message: error.message,
        ),
      );
      await disarmSessionWatchdog();
      await recordUnlockResult(
        SessionUnlockResultEvent(source: source, outcome: UnlockOutcome.failed),
      );
      return UnlockOutcome.failed;
    } on DeviceKeyNoDeviceCredentialException catch (error) {
      await applyState(
        AppSessionState(
          status: AppLockStatus.locked,
          lockReason: SessionLockReason.authFailed,
          message: error.message,
        ),
      );
      await disarmSessionWatchdog();
      await recordUnlockResult(
        SessionUnlockResultEvent(source: source, outcome: UnlockOutcome.failed),
      );
      return UnlockOutcome.failed;
    } on DeviceKeyAuthFailedException {
      return _handleTrustedDeviceFailure(
        source: source,
        preservedLockReason: priorLockReason,
        preservedMessage: priorMessage,
        applyState: applyState,
        disarmSessionWatchdog: disarmSessionWatchdog,
        loadRetryVerificationMessage: loadRetryVerificationMessage,
        recordUnlockResult: recordUnlockResult,
      );
    } on DeviceKeyBiometricNotEnrolledException {
      await applyState(
        AppSessionState(
          status: AppLockStatus.locked,
          lockReason: SessionLockReason.authFailed,
          message: await loadBiometricNotEnrolledMessage(),
        ),
      );
      await disarmSessionWatchdog();
      await recordUnlockResult(
        SessionUnlockResultEvent(source: source, outcome: UnlockOutcome.failed),
      );
      return UnlockOutcome.failed;
    } on DeviceKeyUnsupportedFormatException catch (error) {
      await repository.clearTrustedDeviceAccess();
      await applyState(
        AppSessionState(
          status: AppLockStatus.recoveryRequired,
          message: error.message,
        ),
      );
      await disarmSessionWatchdog();
      await recordUnlockResult(
        SessionUnlockResultEvent(source: source, outcome: UnlockOutcome.failed),
      );
      return UnlockOutcome.failed;
    } on DeviceKeyInvalidatedException catch (error) {
      await repository.clearTrustedDeviceAccess();
      await applyState(
        AppSessionState(
          status: AppLockStatus.recoveryRequired,
          message: error.message,
        ),
      );
      await disarmSessionWatchdog();
      await recordUnlockResult(
        SessionUnlockResultEvent(source: source, outcome: UnlockOutcome.failed),
      );
      return UnlockOutcome.failed;
    } on StateError catch (error) {
      await repository.clearTrustedDeviceAccess();
      await applyState(
        AppSessionState(
          status: AppLockStatus.recoveryRequired,
          message: await friendlyErrorMessage(
            error,
            afterRestoreTrustedUnlock: afterRestore,
          ),
        ),
      );
      await disarmSessionWatchdog();
      await recordUnlockResult(
        SessionUnlockResultEvent(source: source, outcome: UnlockOutcome.failed),
      );
      return UnlockOutcome.failed;
    } catch (error) {
      final String message = await friendlyErrorMessage(
        error,
        afterRestoreTrustedUnlock: afterRestore,
      );
      if (error is SecretBoxAuthenticationError ||
          isUnreadableEncryptedIndexError(error)) {
        await repository.clearTrustedDeviceAccess();
        await applyState(
          AppSessionState(
            status: AppLockStatus.recoveryRequired,
            message: message,
          ),
        );
        await disarmSessionWatchdog();
        await recordUnlockResult(
          SessionUnlockResultEvent(
            source: source,
            outcome: UnlockOutcome.failed,
          ),
        );
        return UnlockOutcome.failed;
      }
      await applyState(
        AppSessionState(status: AppLockStatus.fatalError, message: message),
      );
      await disarmSessionWatchdog();
      await recordUnlockResult(
        SessionUnlockResultEvent(source: source, outcome: UnlockOutcome.failed),
      );
      return UnlockOutcome.failed;
    }
  }

  Future<AppSessionState> bootstrapSession({
    required Future<AppSessionState> Function(AppSessionState next)
    adoptBootstrapState,
    required Future<UnlockOutcome> Function({
      bool afterRestore,
      UnlockRequestSource source,
    })
    unlock,
    required AppSessionState Function() readCurrentState,
    required Future<String> Function() loadUnsupportedRuntimeMessage,
    required Future<String> Function() loadStartupNeedsRecoveryKeyMessage,
    required Future<String> Function() loadStartupNeedsTrustedDeviceMessage,
    required Future<String> Function(
      Object error, {
      bool afterRestoreTrustedUnlock,
    })
    friendlyErrorMessage,
  }) async {
    if (!_ref.read(vaultPlatformSupportProvider)) {
      final AppSessionState next = AppSessionState(
        status: AppLockStatus.fatalError,
        message: await loadUnsupportedRuntimeMessage(),
      );
      return adoptBootstrapState(next);
    }

    final VaultRepository repository = _ref.read(vaultRepositoryProvider);
    try {
      await repository.initialize();
      final RecoveryMetadata? metadata = await repository
          .readRecoveryMetadata();
      if (metadata == null) {
        final AppSessionState next = AppSessionState(
          status: AppLockStatus.unlocked,
          message: await loadStartupNeedsRecoveryKeyMessage(),
        );
        return adoptBootstrapState(next);
      }

      final bool hasTrustedDevice = await repository.hasTrustedDeviceAccess();
      if (!hasTrustedDevice) {
        final AppSessionState next = AppSessionState(
          status: AppLockStatus.recoveryRequired,
          message: await loadStartupNeedsTrustedDeviceMessage(),
        );
        return adoptBootstrapState(next);
      }

      final UnlockOutcome outcome = await unlock();
      if (outcome != UnlockOutcome.success) {
        return readCurrentState();
      }
      return readCurrentState();
    } catch (error) {
      final String message = await friendlyErrorMessage(error);
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
      return adoptBootstrapState(next);
    }
  }

  Future<AppSessionState> resumeSessionAfterRestore(
    UnlockedVaultSession priorSession, {
    required Future<AppSessionState> Function(AppSessionState next) applyState,
    required Future<void> Function(AppSessionState next) activateUnlockedState,
    required Future<String> Function(
      Object error, {
      bool afterRestoreTrustedUnlock,
    })
    friendlyErrorMessage,
    required Future<void> Function() disarmSessionWatchdog,
  }) async {
    final VaultRepository repository = _ref.read(vaultRepositoryProvider);
    try {
      await repository.initialize();
      final UnlockedVaultSession session = await repository
          .resumeUnlockedSessionAfterRestore(priorSession);
      await repository.ensureIndexReady(session);
      await repository.rebuildIndex(session);
      final AppSessionState next = AppSessionState(
        status: AppLockStatus.unlocked,
        session: session,
      );
      await activateUnlockedState(next);
      return next;
    } catch (error) {
      if (error is SecretBoxAuthenticationError ||
          isUnreadableEncryptedIndexError(error)) {
        await repository.clearTrustedDeviceAccess();
      }
      final AppSessionState next = AppSessionState(
        status: AppLockStatus.recoveryRequired,
        message: await friendlyErrorMessage(
          error,
          afterRestoreTrustedUnlock: true,
        ),
      );
      await applyState(next);
      await disarmSessionWatchdog();
      return next;
    }
  }

  Future<UnlockOutcome> _handleTrustedDeviceFailure({
    required UnlockRequestSource source,
    required Future<AppSessionState> Function(AppSessionState next) applyState,
    required Future<void> Function() disarmSessionWatchdog,
    required Future<String> Function() loadRetryVerificationMessage,
    required Future<void> Function(SessionUnlockResultEvent event)
    recordUnlockResult,
    bool recoverable = false,
    SessionLockReason? preservedLockReason,
    String? preservedMessage,
  }) async {
    if (recoverable && preservedLockReason != null) {
      await applyState(
        AppSessionState(
          status: AppLockStatus.locked,
          lockReason: preservedLockReason,
          message: preservedMessage,
        ),
      );
      await disarmSessionWatchdog();
      await recordUnlockResult(
        SessionUnlockResultEvent(
          source: source,
          outcome: UnlockOutcome.failed,
          recoverable: true,
        ),
      );
      return UnlockOutcome.failed;
    }
    await applyState(
      AppSessionState(
        status: AppLockStatus.locked,
        lockReason: SessionLockReason.authFailed,
        message: await loadRetryVerificationMessage(),
      ),
    );
    await disarmSessionWatchdog();
    await recordUnlockResult(
      SessionUnlockResultEvent(source: source, outcome: UnlockOutcome.failed),
    );
    return UnlockOutcome.failed;
  }
}
