import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/recovery/recovery_metadata.dart';
import '../../../infrastructure/drive/drive_backup_service.dart';
import '../../../infrastructure/security/app_unlock_mode.dart';
import '../../../shared/providers/core_providers.dart';
import '../../session/providers/session_providers.dart';
import '../../session/state/app_session_state.dart';

final recoveryMetadataProvider = FutureProvider<RecoveryMetadata?>((
  Ref ref,
) async {
  if (!ref.watch(supportedPlatformProvider)) {
    return null;
  }
  final AppSessionState localState = ref.watch(appSessionProvider);
  if (localState.status == AppLockStatus.uninitialized) {
    await ref.watch(appStartupProvider.future);
  } else {
    await ref.read(vaultRepositoryProvider).initialize();
  }
  return ref.read(vaultRepositoryProvider).readRecoveryMetadata();
});

final settingsDriveConnectionProvider =
    FutureProvider.autoDispose<DriveConnectionState>((Ref ref) async {
      return ref
          .read(vaultTransferServiceProvider)
          .getGoogleDriveConnectionState();
    });

final unlockModeProvider = FutureProvider<AppUnlockMode>((Ref ref) async {
  return ref.read(appLockServiceProvider).getUnlockMode();
});
