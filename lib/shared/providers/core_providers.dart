import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/diary/create_entry_use_case.dart';
import '../../application/recovery/setup_recovery_key_use_case.dart';
import '../../application/recovery/unlock_with_recovery_key_use_case.dart';
import '../../application/search/search_entries_use_case.dart';
import '../../application/security/unlock_app_use_case.dart';
import '../../infrastructure/crypto/crypto_service.dart';
import '../../infrastructure/database/index_database.dart';
import '../../infrastructure/drive/drive_backup_service.dart';
import '../../infrastructure/markdown/front_matter_codec.dart';
import '../../infrastructure/security/app_lock_service.dart';
import '../../infrastructure/security/device_key_manager.dart';
import '../../infrastructure/storage/vault_archive_io.dart';
import '../../infrastructure/storage/vault_path_strategy.dart';
import '../../infrastructure/storage/vault_repository.dart';
import '../../infrastructure/storage/vault_transfer_service.dart';

final supportedPlatformProvider = Provider<bool>((Ref ref) {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
});

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
  return LocalCryptoService(
    deviceKeyManager: ref.watch(deviceKeyManagerProvider),
  );
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

final indexDatabaseProvider = Provider<IndexDatabase>((Ref ref) {
  return IndexDatabase(ref.watch(vaultPathStrategyProvider));
});

final vaultRepositoryProvider = Provider<VaultRepository>((Ref ref) {
  return VaultRepository(
    pathStrategy: ref.watch(vaultPathStrategyProvider),
    frontMatterCodec: ref.watch(frontMatterCodecProvider),
    cryptoService: ref.watch(cryptoServiceProvider),
    indexDatabase: ref.watch(indexDatabaseProvider),
    deviceKeyManager: ref.watch(deviceKeyManagerProvider),
  );
});

final vaultArchiveIoProvider = Provider<VaultArchiveIo>((Ref ref) {
  return VaultArchiveIo(
    pathStrategy: ref.watch(vaultPathStrategyProvider),
    repository: ref.watch(vaultRepositoryProvider),
    frontMatterCodec: ref.watch(frontMatterCodecProvider),
    indexDatabase: ref.watch(indexDatabaseProvider),
  );
});

final vaultTransferServiceProvider = Provider<VaultTransferService>((Ref ref) {
  return VaultTransferService(
    archiveIo: ref.watch(vaultArchiveIoProvider),
    driveBackupService: ref.watch(driveBackupServiceProvider),
  );
});

final createEntryUseCaseProvider = Provider<CreateEntryUseCase>((Ref ref) {
  return CreateEntryUseCase(ref.watch(vaultRepositoryProvider));
});

final searchEntriesUseCaseProvider = Provider<SearchEntriesUseCase>((Ref ref) {
  return SearchEntriesUseCase(ref.watch(indexDatabaseProvider));
});

final setupRecoveryKeyUseCaseProvider = Provider<SetupRecoveryKeyUseCase>((Ref ref) {
  return SetupRecoveryKeyUseCase(ref.watch(vaultRepositoryProvider));
});

final unlockWithRecoveryKeyUseCaseProvider =
    Provider<UnlockWithRecoveryKeyUseCase>((Ref ref) {
  return UnlockWithRecoveryKeyUseCase(ref.watch(vaultRepositoryProvider));
});

final unlockAppUseCaseProvider = Provider<UnlockAppUseCase>((Ref ref) {
  return UnlockAppUseCase(ref.watch(appLockServiceProvider));
});
