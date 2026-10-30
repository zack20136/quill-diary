import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/transfer/portable_transfer_service.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/security/app_lock_service.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/external_directory_store.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_export_io.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_import_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/shared/platform/vault_platform_support.dart';

final cryptoServiceProvider = Provider<CryptoService>((Ref ref) {
  return LocalCryptoService();
});

final indexDatabaseManagerProvider = Provider<IndexDatabaseManager>((Ref ref) {
  return IndexDatabaseManager(ref.watch(vaultPathStrategyProvider));
});

final driveBackupServiceProvider = Provider<DriveBackupService>((Ref ref) {
  return GoogleDriveBackupService();
});

final frontMatterCodecProvider = Provider<FrontMatterCodec>((Ref ref) {
  return const FrontMatterCodec();
});

final deviceKeyManagerProvider = Provider<DeviceKeyManager>((Ref ref) {
  if (!ref.watch(vaultPlatformSupportProvider)) {
    return const UnsupportedDeviceKeyManager();
  }
  return AndroidDeviceKeyManager();
});

final appLockServiceProvider = Provider<AppLockService>((Ref ref) {
  if (!ref.watch(vaultPlatformSupportProvider)) {
    return const UnsupportedAppLockService();
  }
  return LocalAppLockService();
});

final vaultPathStrategyProvider = Provider<VaultPathStrategy>((Ref ref) {
  return const VaultPathStrategy();
});

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

final portableExportIoProvider = Provider<PortableExportIo>(
  (Ref ref) => PortableExportIo(
    pathStrategy: ref.watch(vaultPathStrategyProvider),
    repository: ref.watch(vaultRepositoryProvider),
    frontMatterCodec: ref.watch(frontMatterCodecProvider),
  ),
);
final portableImportIoProvider = Provider<PortableImportIo>(
  (Ref ref) => PortableImportIo(
    pathStrategy: ref.watch(vaultPathStrategyProvider),
    repository: ref.watch(vaultRepositoryProvider),
    frontMatterCodec: ref.watch(frontMatterCodecProvider),
  ),
);

final portableTransferServiceProvider = Provider<PortableTransferService>((
  Ref ref,
) {
  return PortableTransferService(
    exportIo: ref.watch(portableExportIoProvider),
    importIo: ref.watch(portableImportIoProvider),
    externalDirectoryStore: ref.watch(externalDirectoryStoreProvider),
  );
});
