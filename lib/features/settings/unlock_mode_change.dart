import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/security/unlocked_vault_session.dart';
import '../../infrastructure/security/app_lock_service.dart';
import '../../infrastructure/security/app_unlock_mode.dart';
import '../../infrastructure/security/device_key_manager.dart';
import '../../shared/providers/core_providers.dart';
import '../session/providers/session_providers.dart';
import '../session/session_messages.dart';
import 'providers/settings_providers.dart';
import 'settings_copy.dart';

/// 設定頁變更解鎖方式的結果。
sealed class UnlockModeChangeOutcome {
  const UnlockModeChangeOutcome();
}

class UnlockModeChangeSucceeded extends UnlockModeChangeOutcome {
  const UnlockModeChangeSucceeded();
}

class UnlockModeChangeMessage extends UnlockModeChangeOutcome {
  const UnlockModeChangeMessage(this.message);

  final String message;
}

/// 變更解鎖方式：precheck → keystore 同步 → 寫入偏好。
Future<UnlockModeChangeOutcome> applyUnlockModeChange({
  required WidgetRef ref,
  required AppUnlockMode mode,
}) async {
  final AppLockService appLock = ref.read(appLockServiceProvider);
  final AppUnlockMode previousMode = await appLock.getUnlockMode();
  if (previousMode == mode) {
    return const UnlockModeChangeSucceeded();
  }

  if (mode == AppUnlockMode.deviceLock && !await appLock.canUseDeviceCredential()) {
    return const UnlockModeChangeMessage(kUnlockModeNeedsDeviceLockMessage);
  }

  if (mode == AppUnlockMode.biometric && !await appLock.canUseDeviceCredential()) {
    return const UnlockModeChangeMessage(kUnlockModeNeedsDeviceLockMessage);
  }

  try {
    final UnlockedVaultSession? session = await ref.read(activeVaultSessionProvider.future);
    if (session == null) {
      await appLock.setUnlockMode(mode);
      ref.invalidate(unlockModeProvider);
      return const UnlockModeChangeSucceeded();
    }

    await ref.read(appSessionProvider.notifier).runSensitiveTask((UnlockedVaultSession active) async {
      final UnlockedVaultSession synced = await ref
          .read(vaultRepositoryProvider)
          .ensureKeystoreMatchesUnlockMode(active, targetMode: mode);
      await appLock.setUnlockMode(mode);
      ref.read(appSessionProvider.notifier).activateSession(synced);
    });
    ref.invalidate(unlockModeProvider);
    return const UnlockModeChangeSucceeded();
  } on DeviceKeyUserCancelledException {
    await appLock.setUnlockMode(previousMode);
    ref.invalidate(unlockModeProvider);
    return const UnlockModeChangeMessage(SettingsUnlockMethodCopy.unlockModeChangeCancelled);
  } on DeviceKeyAuthFailedException {
    await appLock.setUnlockMode(previousMode);
    ref.invalidate(unlockModeProvider);
    return const UnlockModeChangeMessage(SettingsUnlockMethodCopy.unlockModeChangeAuthFailed);
  } on DeviceKeyBiometricNotEnrolledException {
    await appLock.setUnlockMode(previousMode);
    ref.invalidate(unlockModeProvider);
    return const UnlockModeChangeMessage(kBiometricNotEnrolledSwitchModeMessage);
  }
}
