import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/crypto/crypto_service.dart';
import '../../infrastructure/database/index_database_manager.dart';
import '../../infrastructure/drive/drive_backup_service.dart';
import '../../infrastructure/markdown/front_matter_codec.dart';
import '../../infrastructure/preferences/user_preferences.dart';
import '../../infrastructure/security/app_lock_service.dart';
import '../../infrastructure/security/device_key_manager.dart';
import '../../infrastructure/storage/editor_draft_store.dart';
import '../../infrastructure/storage/external_directory_store.dart';
import '../../infrastructure/storage/vault_archive_io.dart';
import '../../infrastructure/storage/vault_path_strategy.dart';
import '../../infrastructure/storage/vault_repository.dart';
import '../../infrastructure/storage/vault_transfer_service.dart';
import '../platform/vault_platform_support.dart';

/// 組合 vault 相關檔案路徑策略。
final vaultPathStrategyProvider = Provider<VaultPathStrategy>((Ref ref) {
  return const VaultPathStrategy();
});

/// Markdown front matter 編解碼器。
final frontMatterCodecProvider = Provider<FrontMatterCodec>((Ref ref) {
  return const FrontMatterCodec();
});

/// 裝置金鑰管理器，非支援平台會退回 no-op 實作。
final deviceKeyManagerProvider = Provider<DeviceKeyManager>((Ref ref) {
  if (!ref.watch(supportedPlatformProvider)) {
    return const UnsupportedDeviceKeyManager();
  }
  return AndroidDeviceKeyManager();
});

/// LDJ2 加解密服務。
final cryptoServiceProvider = Provider<CryptoService>((Ref ref) {
  return LocalCryptoService();
});

/// 使用者偏好儲存。
final userPreferencesProvider = Provider<UserPreferences>((Ref ref) {
  return UserPreferences();
});

/// App 解鎖模式服務，非支援平台會退回 no-op 實作。
final appLockServiceProvider = Provider<AppLockService>((Ref ref) {
  if (!ref.watch(supportedPlatformProvider)) {
    return const UnsupportedAppLockService();
  }
  return LocalAppLockService();
});

/// Google Drive 備份服務。
final driveBackupServiceProvider = Provider<DriveBackupService>((Ref ref) {
  return GoogleDriveBackupService();
});

/// 加密索引資料庫管理器。
final indexDatabaseManagerProvider = Provider<IndexDatabaseManager>((Ref ref) {
  return IndexDatabaseManager(ref.watch(vaultPathStrategyProvider));
});

/// Vault repository，負責主要的讀寫與 session 整合。
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

/// Vault 備份封存 I/O。
final vaultArchiveIoProvider = Provider<VaultArchiveIo>((Ref ref) {
  return VaultArchiveIo(
    pathStrategy: ref.watch(vaultPathStrategyProvider),
    repository: ref.watch(vaultRepositoryProvider),
    frontMatterCodec: ref.watch(frontMatterCodecProvider),
    indexDatabaseManager: ref.watch(indexDatabaseManagerProvider),
    editorDraftStore: ref.watch(editorDraftStoreProvider),
  );
});

/// 外部目錄選擇與持久化。
final externalDirectoryStoreProvider = Provider<ExternalDirectoryStore>((
  Ref ref,
) {
  return ExternalDirectoryStore(ref.watch(vaultPathStrategyProvider));
});

/// Editor 草稿持久化儲存。
final editorDraftStoreProvider = Provider<EditorDraftStore>((Ref ref) {
  return EditorDraftStore(
    pathStrategy: ref.watch(vaultPathStrategyProvider),
    cryptoService: ref.watch(cryptoServiceProvider),
  );
});

/// Vault 備份、匯入匯出與雲端傳輸協調服務。
final vaultTransferServiceProvider = Provider<VaultTransferService>((Ref ref) {
  return VaultTransferService(
    archiveIo: ref.watch(vaultArchiveIoProvider),
    driveBackupService: ref.watch(driveBackupServiceProvider),
    vaultRepository: ref.watch(vaultRepositoryProvider),
    externalDirectoryStore: ref.watch(externalDirectoryStoreProvider),
    pathStrategy: ref.watch(vaultPathStrategyProvider),
  );
});
