import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backup_status_store.dart';
import 'editor_draft_store.dart';
import 'external_directory_store.dart';
import 'portable_transfer_service.dart';
import 'storage_path_providers.dart';
import 'vault_archive_io.dart';
import 'vault_backup_service.dart';
import 'vault_entry_store.dart';
import 'vault_recovery_service.dart';
import 'vault_repair_service.dart';
import 'vault_repository.dart';
import 'vault_restore_service.dart';
import 'vault_tag_service.dart';
import 'vault_transfer_service.dart';
import '../crypto/crypto_providers.dart';
import '../database/database_providers.dart';
import '../drive/drive_providers.dart';
import '../markdown/markdown_providers.dart';
import '../security/security_providers.dart';

final backupStatusStoreProvider = Provider<BackupStatusStore>((Ref ref) {
  return BackupStatusStore();
});

final externalDirectoryStoreProvider = Provider<ExternalDirectoryStore>((
  Ref ref,
) {
  return ExternalDirectoryStore(ref.watch(vaultPathStrategyProvider));
});

final editorDraftStoreProvider = Provider<EditorDraftStore>((Ref ref) {
  return EditorDraftStore(
    pathStrategy: ref.watch(vaultPathStrategyProvider),
    cryptoService: ref.watch(cryptoServiceProvider),
  );
});

final vaultRepositoryProvider = Provider<VaultRepository>((Ref ref) {
  return VaultRepository(
    pathStrategy: ref.watch(vaultPathStrategyProvider),
    frontMatterCodec: ref.watch(frontMatterCodecProvider),
    cryptoService: ref.watch(cryptoServiceProvider),
    indexDatabaseManager: ref.watch(indexDatabaseManagerProvider),
    deviceKeyManager: ref.watch(deviceKeyManagerProvider),
    appLockService: ref.watch(appLockServiceProvider),
  );
});

final vaultRecoveryServiceProvider = Provider<VaultRecoveryService>((Ref ref) {
  return VaultRecoveryService(ref.watch(vaultRepositoryProvider));
});

final vaultEntryStoreProvider = Provider<VaultEntryStore>((Ref ref) {
  return VaultEntryStore(ref.watch(vaultRepositoryProvider));
});

final vaultTagServiceProvider = Provider<VaultTagService>((Ref ref) {
  return VaultTagService(ref.watch(vaultRepositoryProvider));
});

final vaultRepairServiceProvider = Provider<VaultRepairService>((Ref ref) {
  return VaultRepairService(ref.watch(vaultRepositoryProvider));
});

final vaultArchiveIoProvider = Provider<VaultArchiveIo>((Ref ref) {
  return VaultArchiveIo(
    pathStrategy: ref.watch(vaultPathStrategyProvider),
    repository: ref.watch(vaultRepositoryProvider),
    frontMatterCodec: ref.watch(frontMatterCodecProvider),
    indexDatabaseManager: ref.watch(indexDatabaseManagerProvider),
    editorDraftStore: ref.watch(editorDraftStoreProvider),
  );
});

final vaultBackupServiceProvider = Provider<VaultBackupService>((Ref ref) {
  return VaultBackupService(
    archiveIo: ref.watch(vaultArchiveIoProvider),
    driveBackupService: ref.watch(driveBackupServiceProvider),
    externalDirectoryStore: ref.watch(externalDirectoryStoreProvider),
    pathStrategy: ref.watch(vaultPathStrategyProvider),
  );
});

final portableTransferServiceProvider = Provider<PortableTransferService>((
  Ref ref,
) {
  return PortableTransferService(
    archiveIo: ref.watch(vaultArchiveIoProvider),
    externalDirectoryStore: ref.watch(externalDirectoryStoreProvider),
  );
});

final vaultRestoreServiceProvider = Provider<VaultRestoreService>((Ref ref) {
  return VaultRestoreService(
    archiveIo: ref.watch(vaultArchiveIoProvider),
    vaultRepository: ref.watch(vaultRepositoryProvider),
    backupService: ref.watch(vaultBackupServiceProvider),
    pathStrategy: ref.watch(vaultPathStrategyProvider),
  );
});

final vaultTransferServiceProvider = Provider<VaultTransferService>((Ref ref) {
  return VaultTransferService.fromServices(
    backupService: ref.watch(vaultBackupServiceProvider),
    restoreService: ref.watch(vaultRestoreServiceProvider),
    portableTransferService: ref.watch(portableTransferServiceProvider),
  );
});
