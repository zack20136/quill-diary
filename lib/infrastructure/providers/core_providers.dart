import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/security/app_lock_service.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/external_directory_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_service.dart';
import 'package:quill_diary/shared/platform/vault_platform_support.dart';

final vaultPathStrategyProvider = Provider<VaultPathStrategy>((Ref ref) {
  return const VaultPathStrategy();
});
final frontMatterCodecProvider = Provider<FrontMatterCodec>((Ref ref) {
  return const FrontMatterCodec();
});
final deviceKeyManagerProvider = Provider<DeviceKeyManager>((Ref ref) {
  if (!ref.watch(supportedPlatformProvider)) {
    return const UnsupportedDeviceKeyManager();
  }
  return AndroidDeviceKeyManager();
});
final cryptoServiceProvider = Provider<CryptoService>((Ref ref) {
  return LocalCryptoService();
});
final userPreferencesProvider = Provider<UserPreferences>((Ref ref) {
  return UserPreferences();
});
final backupStatusStoreProvider = Provider<BackupStatusStore>((Ref ref) {
  return BackupStatusStore();
});
final appLockServiceProvider = Provider<AppLockService>((Ref ref) {
  if (!ref.watch(supportedPlatformProvider)) {
    return const UnsupportedAppLockService();
  }
  return LocalAppLockService();
});
final driveBackupServiceProvider = Provider<DriveBackupService>((Ref ref) {
  return GoogleDriveBackupService();
});
final indexDatabaseManagerProvider = Provider<IndexDatabaseManager>((Ref ref) {
  return IndexDatabaseManager(ref.watch(vaultPathStrategyProvider));
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
final vaultArchiveIoProvider = Provider<VaultArchiveIo>((Ref ref) {
  return VaultArchiveIo(
    pathStrategy: ref.watch(vaultPathStrategyProvider),
    repository: ref.watch(vaultRepositoryProvider),
    frontMatterCodec: ref.watch(frontMatterCodecProvider),
    indexDatabaseManager: ref.watch(indexDatabaseManagerProvider),
    editorDraftStore: ref.watch(editorDraftStoreProvider),
  );
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
final vaultTransferServiceProvider = Provider<VaultTransferService>((Ref ref) {
  return VaultTransferService(
    archiveIo: ref.watch(vaultArchiveIoProvider),
    driveBackupService: ref.watch(driveBackupServiceProvider),
    vaultRepository: ref.watch(vaultRepositoryProvider),
    externalDirectoryStore: ref.watch(externalDirectoryStoreProvider),
    pathStrategy: ref.watch(vaultPathStrategyProvider),
  );
});
