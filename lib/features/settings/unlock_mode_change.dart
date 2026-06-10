import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/security/unlocked_vault_session.dart';
import '../../infrastructure/security/app_lock_service.dart';
import '../../infrastructure/security/app_unlock_mode.dart';
import '../../infrastructure/security/unlock_mode_change_service.dart';
import '../../infrastructure/security/unlock_mode_policy.dart';
import '../../shared/providers/core_providers.dart';
import '../session/providers/session_providers.dart';
import 'providers/settings_providers.dart';

export '../../infrastructure/security/unlock_mode_change_service.dart';

/// 變更解鎖方式：precheck → keystore 同步 → 寫入偏好。
Future<UnlockModeChangeOutcome> applyUnlockModeChange({
  required WidgetRef ref,
  required AppUnlockMode mode,
}) async {
  final AppLockService appLock = ref.read(appLockServiceProvider);
  final UnlockedVaultSession? session = await ref.read(activeVaultSessionProvider.future);
  if (session == null) {
    return UnlockModeChangeMessage(
      UnlockModeCapabilityFailure.requiresUnlockedSession.message,
    );
  }

  final UnlockModeChangeService service = UnlockModeChangeService(
    appLock: appLock,
    vaultRepository: ref.read(vaultRepositoryProvider),
  );

  late UnlockModeChangeOutcome outcome;
  await ref.read(appSessionProvider.notifier).runSensitiveTask((UnlockedVaultSession active) async {
    outcome = await service.apply(mode: mode, session: active);
    if (outcome case UnlockModeChangeSucceededWithSession(:final session)) {
      ref.read(appSessionProvider.notifier).activateSession(session);
    }
  });

  ref.invalidate(unlockModeProvider);
  return outcome;
}
