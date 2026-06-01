import 'dart:io';

import 'package:quill_lock_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_lock_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_lock_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_repository.dart';

import 'fake_app_lock_service.dart';
import 'fake_device_key_manager.dart';
import 'test_vault_path_strategy.dart';

class VaultTestHarness {
  VaultTestHarness._();

  late Directory tempDir;
  late TestVaultPathStrategy pathStrategy;
  late RecordingDeviceKeyManager deviceKeyManager;
  late FakeAppLockService appLockService;
  late VaultRepository repository;

  static Future<VaultTestHarness> create({
    RecordingDeviceKeyManager? deviceKeyManager,
    FakeAppLockService? appLockService,
  }) async {
    final VaultTestHarness harness = VaultTestHarness._();
    harness.tempDir = await Directory.systemTemp.createTemp('qld_vault_test_');
    harness.pathStrategy = TestVaultPathStrategy(harness.tempDir);
    harness.deviceKeyManager = deviceKeyManager ?? RecordingDeviceKeyManager();
    harness.appLockService = appLockService ?? FakeAppLockService();
    harness.repository = VaultRepository(
      pathStrategy: harness.pathStrategy,
      frontMatterCodec: const FrontMatterCodec(),
      cryptoService: LocalCryptoService(deviceKeyManager: harness.deviceKeyManager),
      indexDatabaseManager: IndexDatabaseManager(harness.pathStrategy),
      deviceKeyManager: harness.deviceKeyManager,
      appLockService: harness.appLockService,
    );
    await harness.repository.initialize();
    return harness;
  }

  Future<void> dispose() async {
    await repository.closeUnlockedResources();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  }
}
