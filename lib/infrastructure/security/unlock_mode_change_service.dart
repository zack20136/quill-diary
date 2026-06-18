import '../../domain/security/unlocked_vault_session.dart';
import 'app_lock_service.dart';
import 'app_unlock_mode.dart';
import 'device_key_manager.dart';
import 'unlock_mode_policy.dart';
import '../storage/vault_repository.dart';

/// 設定頁變更解鎖方式的結果。
sealed class UnlockModeChangeOutcome {
  const UnlockModeChangeOutcome();
}

enum UnlockModeChangeMessageKind {
  requiresUnlockedSession,
  requiresDeviceLock,
  requiresBiometricEnrollment,
  changeCancelled,
  authFailed,
}

class UnlockModeChangeSucceeded extends UnlockModeChangeOutcome {
  const UnlockModeChangeSucceeded();
}

class UnlockModeChangeMessage extends UnlockModeChangeOutcome {
  const UnlockModeChangeMessage(this.kind);

  final UnlockModeChangeMessageKind kind;
}

/// 安全地切換解鎖模式：能力檢查 → Keystore 同步 → 最後才寫入偏好。
class UnlockModeChangeService {
  const UnlockModeChangeService({
    required AppLockService appLock,
    required VaultRepository vaultRepository,
  }) : _appLock = appLock,
       _vaultRepository = vaultRepository;

  final AppLockService _appLock;
  final VaultRepository _vaultRepository;

  Future<UnlockModeChangeOutcome> apply({
    required AppUnlockMode mode,
    required UnlockedVaultSession session,
  }) async {
    final AppUnlockMode previousMode = await _appLock.getUnlockMode();
    if (previousMode == mode) {
      return const UnlockModeChangeSucceeded();
    }

    final UnlockModeCapabilityFailure? capabilityFailure =
        await precheckUnlockModeChange(appLock: _appLock, mode: mode);
    if (capabilityFailure != null) {
      return UnlockModeChangeMessage(switch (capabilityFailure) {
        UnlockModeCapabilityFailure.requiresUnlockedSession =>
          UnlockModeChangeMessageKind.requiresUnlockedSession,
        UnlockModeCapabilityFailure.requiresDeviceLock =>
          UnlockModeChangeMessageKind.requiresDeviceLock,
        UnlockModeCapabilityFailure.requiresBiometricEnrollment =>
          UnlockModeChangeMessageKind.requiresBiometricEnrollment,
      });
    }

    try {
      final UnlockedVaultSession synced = await _vaultRepository
          .ensureKeystoreMatchesUnlockMode(session, targetMode: mode);
      await _appLock.setUnlockMode(mode);
      return UnlockModeChangeSucceededWithSession(synced);
    } on DeviceKeyUserCancelledException {
      return const UnlockModeChangeMessage(
        UnlockModeChangeMessageKind.changeCancelled,
      );
    } on DeviceKeyAuthFailedException {
      return const UnlockModeChangeMessage(
        UnlockModeChangeMessageKind.authFailed,
      );
    } on DeviceKeyBiometricNotEnrolledException {
      return const UnlockModeChangeMessage(
        UnlockModeChangeMessageKind.requiresBiometricEnrollment,
      );
    }
  }
}

class UnlockModeChangeSucceededWithSession extends UnlockModeChangeSucceeded {
  const UnlockModeChangeSucceededWithSession(this.session);

  final UnlockedVaultSession session;
}
