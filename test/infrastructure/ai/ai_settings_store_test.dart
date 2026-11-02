import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_model_thinking_override.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_settings.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/ai/ai_settings_store.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/portable/vault_backup_io.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/shared/app_identifiers.dart';
import 'package:quill_diary/shared/data_versions.dart';

import '../../helpers/vault/vault_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const first = AiConnectionConfig(
    provider: AiProvider.custom,
    baseUrl: 'https://first.example/v1',
    model: 'model',
  );
  const other = AiConnectionConfig(
    provider: AiProvider.custom,
    baseUrl: 'https://other.example/v1',
    model: 'model',
  );

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('同網址不同連線的金鑰隔離，改名不影響舊快照取用', () async {
    final store = AiSettingsStore.detached();
    final a = first.copyWith(customConnectionId: 'aic_a', displayName: '工作');
    final b = first.copyWith(customConnectionId: 'aic_b', displayName: '個人');
    await store.saveApiKey(a, 'key-a');
    await store.saveApiKey(b, 'key-b');
    await store.saveApiKey(first, 'legacy-key');
    expect(await store.readApiKey(a.copyWith(displayName: '改名')), 'key-a');
    expect(await store.readApiKey(b), 'key-b');
    expect(await store.readApiKey(first), 'legacy-key');
    expect(await store.readApiKey(a.copyWith(baseUrl: other.baseUrl)), isEmpty);
    await store.saveApiKey(a, '');
    expect(await store.readApiKey(a), isEmpty);
    expect(await store.readApiKey(b), 'key-b');
    expect(await store.readApiKey(first), 'legacy-key');
  });

  test('Custom 金鑰依目的網址保存，清空只移除該目的地金鑰', () async {
    final store = AiSettingsStore.detached();
    await store.saveApiKey(first, 'first-synthetic-key');
    expect(await store.readApiKey(other), isEmpty);
    await store.saveApiKey(other, 'other-synthetic-key');
    await store.saveApiKey(first, '  ');
    expect(await store.readApiKey(first), isEmpty);
    expect(await store.readApiKey(other), 'other-synthetic-key');
    expect(
      await store.readApiKey(
        const AiConnectionConfig(
          provider: AiProvider.custom,
          baseUrl: 'https://OTHER.example/v1/',
        ),
      ),
      'other-synthetic-key',
    );
  });

  test('設定寫入加密檔且不含 API 金鑰，舊安全儲存設定會搬進 vault', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final storage = FlutterSecureStorage(
      aOptions: AndroidOptions(
        storageNamespace: AppIdentifiers.aiSecureStorageNamespace,
      ),
    );
    const connection = AiConnectionConfig(
      provider: AiProvider.openai,
      model: 'moved-model',
    );
    await storage.write(
      key: 'settings',
      value: jsonEncode(
        const AiConnectionSettings(
          activeConnectionId: 'openai',
          connections: {'openai': connection},
        ).toJson(),
      ),
    );
    await storage.write(
      key: 'chat_diary_settings',
      value: jsonEncode(
        const ChatDiarySettings(
          prompts: ChatDiaryPromptSettings(conversationOverride: '舊提示詞'),
        ).toJson(),
      ),
    );
    final store = AiSettingsStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: LocalCryptoService(),
      repository: harness.repository,
      keyStorage: storage,
    );
    await store.saveApiKey(connection, 'synthetic-secret-key');
    final stored = await store.read(setup.session);
    expect(stored.connection.activeConfig.model, 'moved-model');
    expect(stored.chatDiary.prompts.conversationOverride, '舊提示詞');
    expect(await storage.read(key: 'settings'), isNull);
    expect(await storage.read(key: 'chat_diary_settings'), isNull);
    expect(await storage.read(key: 'key_openai'), 'synthetic-secret-key');
    final plain = await _readSettingsPlaintext(harness, setup.session);
    expect(plain, isNot(contains('synthetic-secret-key')));
    expect(plain, contains('舊提示詞'));
  });

  test('已有 vault 檔時，殘留的舊安全儲存設定不得覆寫', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final storage = FlutterSecureStorage(
      aOptions: AndroidOptions(
        storageNamespace: AppIdentifiers.aiSecureStorageNamespace,
      ),
    );
    final store = AiSettingsStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: LocalCryptoService(),
      repository: harness.repository,
      keyStorage: storage,
    );
    await store.save(
      setup.session,
      connection: const AiConnectionSettings(
        activeConnectionId: 'gemini',
        connections: {
          'gemini': AiConnectionConfig(
            provider: AiProvider.gemini,
            model: 'vault-model',
          ),
        },
      ),
      chatDiary: const ChatDiarySettings(
        prompts: ChatDiaryPromptSettings(generationOverride: '日記庫提示詞'),
      ),
    );
    await storage.write(
      key: 'settings',
      value: jsonEncode(
        const AiConnectionSettings(activeConnectionId: 'claude').toJson(),
      ),
    );
    await storage.write(
      key: 'chat_diary_settings',
      value: jsonEncode(
        const ChatDiarySettings(
          prompts: ChatDiaryPromptSettings(generationOverride: '不該採用'),
        ).toJson(),
      ),
    );
    final reread = AiSettingsStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: LocalCryptoService(),
      repository: harness.repository,
      keyStorage: storage,
    );
    final stored = await reread.read(setup.session);
    expect(stored.connection.activeConfig.model, 'vault-model');
    expect(stored.chatDiary.prompts.generationOverride, '日記庫提示詞');
    expect(await storage.read(key: 'settings'), isNull);
    expect(await storage.read(key: 'chat_diary_settings'), isNull);
  });

  for (final outdatedCatalog in [false, true]) {
    test('版本不變且${outdatedCatalog ? '舊' : '最新'}目錄時依舊欄位移轉，第二次不重寫加密檔', () async {
      final harness = await VaultTestHarness.create();
      addTearDown(harness.dispose);
      final setup = await harness.repository.setupRecoveryKey();
      final metadata = (await harness.repository.readRecoveryMetadata())!;
      final store = AiSettingsStore(
        pathStrategy: harness.pathStrategy,
        cryptoService: LocalCryptoService(),
        repository: harness.repository,
      );
      final now = DateTime(2026, 10, 30);
      final encrypted = await LocalCryptoService().encryptBytes(
        documentId: AiSettingsStore.documentId,
        vaultId: setup.session.vaultId,
        plaintextBytes: Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'version': 1,
              'connection': {
                'provider': 'openai',
                'configs': {
                  'openai': outdatedCatalog
                      ? {
                          'provider': 'openai',
                          'default_model': 'gpt-5.6-sol',
                          'enabled_models': ['gpt-5.6-sol'],
                          'added_models': <String>[],
                          'known_builtin_models': [
                            'gpt-5.6-sol',
                            'gpt-6.1-terra',
                          ],
                          'thinking_levels': {'gpt-5.6-sol': 'high'},
                        }
                      : adoptCatalogModels(defaultConnection(AiProvider.openai))
                            .toStoredJson(),
                  'xai': {
                    'provider': 'xai',
                    'default_model': 'grok-4.3',
                    'enabled_models': ['grok-4.3'],
                    'added_models': <String>[],
                    'known_builtin_models': builtinModelsFor(AiProvider.xai),
                    'thinking_levels': {'grok-4.3': 'high'},
                  },
                },
              },
              'chat_diary': const ChatDiarySettings(
                prompts: ChatDiaryPromptSettings(generationOverride: '保留自訂提示詞'),
              ).toJson(),
            }),
          ),
        ),
        contentType: 'application/json',
        recoveryWrapKey: requireRecoveryWrapKey(setup.session),
        recoverySlotKdf: metadata.kdf,
        createdAt: now,
        updatedAt: now,
      );
      final file = File(await harness.pathStrategy.aiSettingsPath());
      await file.writeAsBytes(encrypted.toFileBytes());
      final stored = await store.read(setup.session);
      final decoded = jsonDecode(
        await _readSettingsPlaintext(harness, setup.session),
      ) as Map;
      expect(decoded['version'], DataVersions.aiSettings);
      expect(decoded['version'], 1);
      expect((decoded['connection'] as Map)['active_connection_id'], 'openai');
      expect((decoded['connection'] as Map)['connections'], isA<Map>());
      expect(stored.connection.activeConfig.model, 'gpt-6.1-terra');
      expect(stored.connection.activeConfig.thinkingLevels, isEmpty);
      expect(
        resolvedThinkingLevel(stored.connection.connectionFor('xai')),
        AiThinkingLevel.high,
      );
      expect(stored.chatDiary.prompts.generationOverride, '保留自訂提示詞');
      final saved = await file.readAsBytes();
      final plain = await _readSettingsPlaintext(harness, setup.session);
      expect(plain, isNot(contains('gpt-5.6-sol')));
      expect(plain, contains('thinking_levels'));
      await store.read(setup.session);
      expect(await file.readAsBytes(), saved);
    });
  }

  test('完整備份包含 AI 設定，還原後仍讀得到且不含金鑰', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final storage = FlutterSecureStorage(
      aOptions: AndroidOptions(
        storageNamespace: AppIdentifiers.aiSecureStorageNamespace,
      ),
    );
    final store = AiSettingsStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: LocalCryptoService(),
      repository: harness.repository,
      keyStorage: storage,
    );
    const connection = AiConnectionConfig(
      provider: AiProvider.custom,
      baseUrl: 'https://backup.example/v1',
      model: 'backup-model',
    );
    final second = connection.copyWith(
      customConnectionId: 'aic_backup',
      displayName: '備份第二組',
      thinkingOverrides: {
        'backup-model': AiModelThinkingOverride(
          defaultLevel: AiThinkingLevel.low,
          levels: {
            AiThinkingLevel.low: {'think': 'low'},
            AiThinkingLevel.high: {'think': 'high'},
          },
        ),
      },
    );
    await store.save(
      setup.session,
      connection: AiConnectionSettings(
        activeConnectionId: 'custom',
        connections: {'custom': connection, second.connectionId: second},
      ),
      chatDiary: const ChatDiarySettings(
        prompts: ChatDiaryPromptSettings(conversationOverride: '備份提示詞'),
        hidePersonNames: false,
      ),
    );
    await store.saveApiKey(connection, 'backup-synthetic-key');
    await store.saveApiKey(second, 'backup-second-key');
    final archive = harness.createTransferIo();
    final backup = File(p.join(harness.tempDir.path, 'ai_settings.zip'));
    await archive.backup.writeBackupZip(backup);
    final names = ZipDecoder()
        .decodeBytes(await backup.readAsBytes())
        .files
        .map((file) => file.name);
    expect(names, contains('ai_settings.json.enc'));
    expect(
      utf8.decode(await backup.readAsBytes(), allowMalformed: true),
      isNot(contains('backup-synthetic-key')),
    );
    await File(await harness.pathStrategy.aiSettingsPath()).delete();
    await archive.backup.restoreBackupZip(backup);
    final restored = await AiSettingsStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: LocalCryptoService(),
      repository: harness.repository,
      keyStorage: storage,
    ).read(setup.session);
    expect(
      restored.connection.activeConfig.baseUrl,
      'https://backup.example/v1',
    );
    expect(
      restored.connection.connectionFor(second.connectionId).displayName,
      second.displayName,
    );
    expect(
      thinkingRequestFields(
        restored.connection.connectionFor(second.connectionId),
      ),
      {'think': 'low'},
    );
    expect(
      await _readSettingsPlaintext(harness, setup.session),
      isNot(contains('backup-second-key')),
    );
    expect(restored.chatDiary.prompts.conversationOverride, '備份提示詞');
    expect(restored.chatDiary.hidePersonNames, isFalse);
    expect(
      await storage.read(key: _customKey(connection)),
      'backup-synthetic-key',
    );
    expect(
      await _readSettingsPlaintext(harness, setup.session),
      isNot(contains('backup-synthetic-key')),
    );
  });

  test('打包前會把尚未打開過的舊設定寫進備份', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final storage = FlutterSecureStorage(
      aOptions: AndroidOptions(
        storageNamespace: AppIdentifiers.aiSecureStorageNamespace,
      ),
    );
    await storage.write(
      key: 'settings',
      value: jsonEncode(
        const AiConnectionSettings(
          activeConnectionId: 'openai',
          connections: {
            'openai': AiConnectionConfig(
              provider: AiProvider.openai,
              model: 'packed-before-open',
            ),
          },
        ).toJson(),
      ),
    );
    await storage.write(
      key: 'chat_diary_settings',
      value: jsonEncode(
        const ChatDiarySettings(
          prompts: ChatDiaryPromptSettings(conversationOverride: '打包前提示詞'),
        ).toJson(),
      ),
    );
    final store = AiSettingsStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: LocalCryptoService(),
      repository: harness.repository,
      keyStorage: storage,
    );
    final backup = File(p.join(harness.tempDir.path, 'migrate_on_pack.zip'));
    await VaultBackupIo(
      pathStrategy: harness.pathStrategy,
      repository: harness.repository,
      indexDatabaseManager: IndexDatabaseManager(harness.pathStrategy),
      editorDraftStore: EditorDraftStore(
        pathStrategy: harness.pathStrategy,
        cryptoService: LocalCryptoService(),
      ),
      prepareVault: () => store.ensureStored(setup.session),
    ).writeBackupZip(backup);
    final names = ZipDecoder()
        .decodeBytes(await backup.readAsBytes())
        .files
        .map((file) => file.name);
    expect(names, contains('ai_settings.json.enc'));
    expect(await storage.read(key: 'settings'), isNull);
    expect(
      await _readSettingsPlaintext(harness, setup.session),
      contains('打包前提示詞'),
    );
    expect(
      await _readSettingsPlaintext(harness, setup.session),
      contains('packed-before-open'),
    );
  });
}

String _customKey(AiConnectionConfig connection) =>
    'connection_key_${base64Url.encode(utf8.encode(connection.credentialId))}';

Future<String> _readSettingsPlaintext(
  VaultTestHarness harness,
  UnlockedVaultSession session,
) async {
  final crypto = LocalCryptoService();
  final parsed = crypto.parseFileBytes(
    await File(await harness.pathStrategy.aiSettingsPath()).readAsBytes(),
  );
  final plain = await crypto.decryptBytes(
    headerBytes: parsed.headerBytes,
    ciphertextBytes: parsed.ciphertextBytes,
    context: vaultDecryptionContext(session),
  );
  return utf8.decode(plain);
}
