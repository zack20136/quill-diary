import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/crypto/crypto_service.dart';
import '../../infrastructure/database/index_database_manager.dart';
import '../../infrastructure/drive/drive_backup_service.dart';
import '../../infrastructure/markdown/front_matter_codec.dart';
import '../../infrastructure/security/app_lock_service.dart';
import '../../infrastructure/security/device_key_manager.dart';
import '../../infrastructure/storage/editor_draft_store.dart';
import '../../infrastructure/storage/external_directory_store.dart';
import '../../infrastructure/storage/vault_archive_io.dart';
import '../../infrastructure/storage/vault_path_strategy.dart';
import '../../infrastructure/storage/vault_repository.dart';
import '../../infrastructure/storage/vault_transfer_service.dart';

/// 目前執行環境是否可執行僅限 Android 的 vault 功能。
final supportedPlatformProvider = Provider<bool>((Ref ref) {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
});

/// 解析 vault 與索引儲存使用的所有本機路徑。
final vaultPathStrategyProvider = Provider<VaultPathStrategy>((Ref ref) {
  return const VaultPathStrategy();
});

/// 編解碼日記條目的 Markdown 前置資訊。
final frontMatterCodecProvider = Provider<FrontMatterCodec>((Ref ref) {
  return const FrontMatterCodec();
});

/// 用於可信裝置包裝的 Android 裝置金鑰橋接層。
final deviceKeyManagerProvider = Provider<DeviceKeyManager>((Ref ref) {
  if (!ref.watch(supportedPlatformProvider)) {
    return const UnsupportedDeviceKeyManager();
  }
  return AndroidDeviceKeyManager();
});

/// LDJ2 加解密作業的底層加密服務。
final cryptoServiceProvider = Provider<CryptoService>((Ref ref) {
  return LocalCryptoService();
});

/// 儲存在加密 vault 之外的 App 鎖定狀態。
final appLockServiceProvider = Provider<AppLockService>((Ref ref) {
  if (!ref.watch(supportedPlatformProvider)) {
    return const UnsupportedAppLockService();
  }
  return LocalAppLockService();
});

/// 以 Google Drive 為後端的遠端備份整合。
final driveBackupServiceProvider = Provider<DriveBackupService>((Ref ref) {
  return GoogleDriveBackupService();
});

/// 依 session 協調加密索引資料庫的開啟與關閉。
final indexDatabaseManagerProvider = Provider<IndexDatabaseManager>((Ref ref) {
  return IndexDatabaseManager(ref.watch(vaultPathStrategyProvider));
});

/// 協調 vault I/O、session 復原與索引同步的主要儲存庫。
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

/// 建立在 vault 儲存庫之上的 ZIP 備份／封存 I/O。
final vaultArchiveIoProvider = Provider<VaultArchiveIo>((Ref ref) {
  return VaultArchiveIo(
    pathStrategy: ref.watch(vaultPathStrategyProvider),
    repository: ref.watch(vaultRepositoryProvider),
    frontMatterCodec: ref.watch(frontMatterCodecProvider),
    indexDatabaseManager: ref.watch(indexDatabaseManagerProvider),
  );
});

/// 記住上次選擇的外部資料夾（備份交付與可攜式匯入／匯出共用）。
final externalDirectoryStoreProvider = Provider<ExternalDirectoryStore>((Ref ref) {
  return ExternalDirectoryStore(ref.watch(vaultPathStrategyProvider));
});

/// 在 vault 索引之外持久化加密的本機編輯器草稿。
final editorDraftStoreProvider = Provider<EditorDraftStore>((Ref ref) {
  return EditorDraftStore(
    pathStrategy: ref.watch(vaultPathStrategyProvider),
    cryptoService: ref.watch(cryptoServiceProvider),
  );
});

/// 檔案選擇器與 Drive 流程的高階備份還原協調器。
final vaultTransferServiceProvider = Provider<VaultTransferService>((Ref ref) {
  return VaultTransferService(
    archiveIo: ref.watch(vaultArchiveIoProvider),
    driveBackupService: ref.watch(driveBackupServiceProvider),
    vaultRepository: ref.watch(vaultRepositoryProvider),
    externalDirectoryStore: ref.watch(externalDirectoryStoreProvider),
    pathStrategy: ref.watch(vaultPathStrategyProvider),
  );
});

