import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/security_providers.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/shared/platform/vault_platform_support.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';

final backupStatusProvider = FutureProvider<BackupStatusSnapshot>((Ref ref) {
  return ref.watch(backupStatusStoreProvider).read();
});

final recoveryMetadataProvider = FutureProvider<RecoveryMetadata?>((
  Ref ref,
) async {
  if (!ref.watch(vaultPlatformSupportProvider)) {
    return null;
  }
  final AppSessionState localState = ref.watch(appSessionProvider);
  if (localState.status == AppLockStatus.uninitialized) {
    await ref.watch(sessionStartupProvider.future);
  } else {
    await ref.read(vaultRecoveryServiceProvider).initialize();
  }
  return ref.read(vaultRecoveryServiceProvider).readRecoveryMetadata();
});

final settingsDriveConnectionProvider =
    FutureProvider.autoDispose<DriveConnectionState>((Ref ref) async {
      return ref
          .read(vaultBackupServiceProvider)
          .getGoogleDriveConnectionState();
    });

final unlockModeProvider = FutureProvider<AppUnlockMode>((Ref ref) async {
  return ref.read(appLockServiceProvider).getUnlockMode();
});

final trustedDeviceAccessProvider = FutureProvider<bool>((Ref ref) async {
  if (!ref.watch(vaultPlatformSupportProvider)) {
    return false;
  }
  return ref.read(vaultRecoveryServiceProvider).hasTrustedDeviceAccess();
});

final vaultRepairSummaryProvider =
    FutureProvider.autoDispose<VaultRepairSummary?>((Ref ref) async {
      final AppSessionState session = await ref.watch(
        effectiveAppSessionProvider.future,
      );
      if (!session.isUnlocked || session.session == null) return null;
      return ref.read(vaultRepairServiceProvider).readLastRepairSummary();
    });
