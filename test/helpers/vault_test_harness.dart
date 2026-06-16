import 'dart:io';

import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

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
      cryptoService: LocalCryptoService(),
      indexDatabaseManager: IndexDatabaseManager(harness.pathStrategy),
      deviceKeyManager: harness.deviceKeyManager,
      appLockService: harness.appLockService,
      userPreferences: UserPreferences(
        storageFile: File('${harness.tempDir.path}\\app_preferences.json'),
      ),
    );
    await harness.repository.initialize();
    return harness;
  }

  VaultArchiveIo createArchiveIo({
    EasyDiaryBackupImporterFactory? easyDiaryBackupImporterFactory,
  }) {
    return VaultArchiveIo(
      pathStrategy: pathStrategy,
      repository: repository,
      frontMatterCodec: const FrontMatterCodec(),
      indexDatabaseManager: IndexDatabaseManager(pathStrategy),
      easyDiaryBackupImporterFactory: easyDiaryBackupImporterFactory,
    );
  }

  /// 建立一筆最簡日記並回傳 entry id。
  Future<String> saveSimpleEntry(
    RecoverySetupResult setup, {
    String? id,
    String title = 'Test Entry',
    String date = '2026-05-24',
    String markdownBody = 'body',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) async {
    final String entryId = id ?? generateEntryId();
    final DateTime timestamp = createdAt ?? DateTime.parse('${date}T10:00:00Z');
    await repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: entryId,
        vaultId: setup.session.vaultId,
        title: title,
        date: DateOnly(date),
        createdAt: timestamp,
        updatedAt: updatedAt ?? timestamp,
        markdownBody: markdownBody,
      ),
    );
    return entryId;
  }

  Future<void> dispose() async {
    await repository.closeUnlockedResources();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  }
}
