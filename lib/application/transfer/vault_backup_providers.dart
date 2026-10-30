import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/restore/vault_restore_service.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/transfer/vault_backup_service.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/infrastructure/storage/portable/vault_backup_io.dart';

final vaultBackupIoProvider = Provider<VaultBackupIo>(
  (Ref ref) => VaultBackupIo(
    pathStrategy: ref.watch(vaultPathStrategyProvider),
    repository: ref.watch(vaultRepositoryProvider),
    indexDatabaseManager: ref.watch(indexDatabaseManagerProvider),
    editorDraftStore: ref.watch(editorDraftStoreProvider),
    prepareVault: () async {
      final session = ref.read(appSessionProvider).session;
      if (session == null) return;
      await ref.read(aiSettingsStoreProvider).ensureStored(session);
    },
  ),
);

final vaultBackupServiceProvider = Provider<VaultBackupService>((Ref ref) {
  return VaultBackupService(
    backupIo: ref.watch(vaultBackupIoProvider),
    driveBackupService: ref.watch(driveBackupServiceProvider),
    externalDirectoryStore: ref.watch(externalDirectoryStoreProvider),
    pathStrategy: ref.watch(vaultPathStrategyProvider),
  );
});

final vaultRestoreServiceProvider = Provider<VaultRestoreService>((Ref ref) {
  return VaultRestoreService(
    backupIo: ref.watch(vaultBackupIoProvider),
    vaultRepository: ref.watch(vaultRepositoryProvider),
    backupService: ref.watch(vaultBackupServiceProvider),
  );
});
