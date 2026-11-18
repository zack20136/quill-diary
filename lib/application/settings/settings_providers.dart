import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/transfer/vault_backup_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/recovery/recovery_key_identity.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/vault_maintenance_models.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/shared/platform/vault_platform_support.dart';

final backupStatusProvider = FutureProvider<BackupStatusSnapshot>((
  Ref ref,
) async {
  final session = ref.watch(
    appSessionProvider.select((state) => state.session),
  );
  final store = ref.watch(backupStatusStoreProvider);
  final status = await store.read();
  if (session == null || status.pendingRecoveryRotation == null) return status;
  final repository = ref.watch(vaultRepositoryProvider);
  return repository.runVaultMutation(() async {
    final metadata = await repository.readRecoveryMetadata();
    if (metadata != null && metadata.vaultId == session.vaultId) {
      await store.reconcileRecoveryRotation(
        await RecoveryKeyIdentity.fromMetadata(metadata),
      );
    }
    return store.read();
  });
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
    await ref.read(vaultRepositoryProvider).initialize();
  }
  return ref.read(vaultRepositoryProvider).readRecoveryMetadata();
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
  return ref.read(vaultRepositoryProvider).hasTrustedDeviceAccess();
});

final vaultRepairSummaryProvider =
    FutureProvider.autoDispose<VaultRepairSummary?>((Ref ref) async {
      final AppSessionState session = await ref.watch(
        effectiveAppSessionProvider.future,
      );
      if (!session.isUnlocked || session.session == null) return null;
      return ref.read(vaultRepositoryProvider).readLastRepairSummary();
    });

final vaultInspectSummaryProvider =
    FutureProvider.autoDispose<VaultInspectSummary?>((Ref ref) async {
      final AppSessionState session = await ref.watch(
        effectiveAppSessionProvider.future,
      );
      if (!session.isUnlocked || session.session == null) return null;
      return ref.read(vaultRepositoryProvider).readLastInspectSummary();
    });

final recoveryBackupRequiredProvider = FutureProvider<bool>((Ref ref) async {
  final status = await ref.watch(backupStatusProvider.future);
  if (status.requiredBackupIdentity == null) return false;
  final metadata = await ref.watch(recoveryMetadataProvider.future);
  return metadata != null &&
      status.requiredBackupIdentity ==
          await RecoveryKeyIdentity.fromMetadata(metadata);
});
