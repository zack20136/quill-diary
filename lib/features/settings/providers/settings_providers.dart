import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/recovery/recovery_metadata.dart';
import '../../../infrastructure/security/app_unlock_mode.dart';
import '../../../shared/providers/core_providers.dart';
import '../../session/providers/session_providers.dart';

final recoveryMetadataProvider = FutureProvider<RecoveryMetadata?>((Ref ref) async {
  if (!ref.watch(supportedPlatformProvider)) {
    return null;
  }
  await ref.watch(appStartupProvider.future);
  return ref.read(vaultRepositoryProvider).readRecoveryMetadata();
});

final settingsDriveConnectionProvider = FutureProvider.autoDispose<bool>((Ref ref) async {
  return ref.read(vaultTransferServiceProvider).isGoogleDriveConnected();
});

final unlockModeProvider = FutureProvider<AppUnlockMode>((Ref ref) async {
  return ref.read(appLockServiceProvider).getUnlockMode();
});
