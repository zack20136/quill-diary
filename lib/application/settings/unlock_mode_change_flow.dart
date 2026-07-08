import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/security/app_lock_service.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/unlock_mode_change_service.dart';
import 'package:quill_diary/infrastructure/security/security_providers.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';

export '../../infrastructure/security/unlock_mode_change_service.dart';

Future<UnlockModeChangeOutcome> applyUnlockModeChange({
  required Ref ref,
  required AppUnlockMode mode,
}) async {
  final AppLockService appLock = ref.read(appLockServiceProvider);
  final UnlockedVaultSession? session = await ref.read(
    activeVaultSessionProvider.future,
  );
  if (session == null) {
    return const UnlockModeChangeMessage(
      UnlockModeChangeMessageKind.requiresUnlockedSession,
    );
  }

  final UnlockModeChangeService service = UnlockModeChangeService(
    appLock: appLock,
    vaultRepository: ref.read(vaultRepositoryProvider),
  );

  late UnlockModeChangeOutcome outcome;
  await ref.read(appSessionProvider.notifier).runSensitiveTask((
    UnlockedVaultSession active,
  ) async {
    outcome = await service.apply(mode: mode, session: active);
    if (outcome case UnlockModeChangeSucceededWithSession(:final session)) {
      ref.read(appSessionProvider.notifier).activateSession(session);
    }
  });

  ref.invalidate(unlockModeProvider);
  return outcome;
}
