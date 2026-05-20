import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/crypto/crypto_service.dart';
import '../../infrastructure/database/index_database_manager.dart';
import '../../infrastructure/drive/drive_backup_service.dart';
import '../../infrastructure/markdown/front_matter_codec.dart';
import '../../infrastructure/security/app_lock_service.dart';
import '../../infrastructure/security/device_key_manager.dart';
import '../../infrastructure/storage/vault_archive_io.dart';
import '../../infrastructure/storage/vault_path_strategy.dart';
import '../../infrastructure/storage/vault_repository.dart';
import '../../infrastructure/storage/vault_transfer_service.dart';

/// Whether the current runtime can execute Android-only vault features.
final supportedPlatformProvider = Provider<bool>((Ref ref) {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
});

/// Resolves all on-device paths used by the vault and index storage.
final vaultPathStrategyProvider = Provider<VaultPathStrategy>((Ref ref) {
  return const VaultPathStrategy();
});

/// Encodes and decodes Markdown front matter for diary entries.
final frontMatterCodecProvider = Provider<FrontMatterCodec>((Ref ref) {
  return const FrontMatterCodec();
});

/// Android device-key bridge used for trusted-device wrapping.
final deviceKeyManagerProvider = Provider<DeviceKeyManager>((Ref ref) {
  if (!ref.watch(supportedPlatformProvider)) {
    return const UnsupportedDeviceKeyManager();
  }
  return AndroidDeviceKeyManager();
});

/// Low-level crypto service for LDJ2 encrypt/decrypt operations.
final cryptoServiceProvider = Provider<CryptoService>((Ref ref) {
  return LocalCryptoService(
    deviceKeyManager: ref.watch(deviceKeyManagerProvider),
  );
});

/// App-lock state persisted outside the encrypted vault.
final appLockServiceProvider = Provider<AppLockService>((Ref ref) {
  if (!ref.watch(supportedPlatformProvider)) {
    return const UnsupportedAppLockService();
  }
  return LocalAppLockService();
});

/// Remote backup integration backed by Google Drive.
final driveBackupServiceProvider = Provider<DriveBackupService>((Ref ref) {
  return GoogleDriveBackupService();
});

/// Coordinates opening and closing the encrypted index database per session.
final indexDatabaseManagerProvider = Provider<IndexDatabaseManager>((Ref ref) {
  return IndexDatabaseManager(ref.watch(vaultPathStrategyProvider));
});

/// Primary repository that coordinates vault I/O, session recovery, and index sync.
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

/// ZIP-based backup/archive I/O built on top of the vault repository.
final vaultArchiveIoProvider = Provider<VaultArchiveIo>((Ref ref) {
  return VaultArchiveIo(
    pathStrategy: ref.watch(vaultPathStrategyProvider),
    repository: ref.watch(vaultRepositoryProvider),
    frontMatterCodec: ref.watch(frontMatterCodecProvider),
    indexDatabaseManager: ref.watch(indexDatabaseManagerProvider),
  );
});

/// High-level backup and restore coordinator for file picker and Drive flows.
final vaultTransferServiceProvider = Provider<VaultTransferService>((Ref ref) {
  return VaultTransferService(
    archiveIo: ref.watch(vaultArchiveIoProvider),
    driveBackupService: ref.watch(driveBackupServiceProvider),
    vaultRepository: ref.watch(vaultRepositoryProvider),
  );
});

