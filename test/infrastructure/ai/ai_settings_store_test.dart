import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/ai/ai_model_thinking_override.dart';
import 'package:quill_diary/domain/ai/ai_stored_settings.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/ai/ai_settings_store.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
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

  test('唯讀檢查不恢復副本、不採用目錄；內容變更時拒絕舊指紋替換', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final store = AiSettingsStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: LocalCryptoService(),
      repository: harness.repository,
    );
    final file = await _writeSettingsPayload(harness, setup.session, {
      ...const AiStoredSettings().toJson(),
      'version': 1,
    });
    final bytes = await file.readAsBytes();
    await file.rename('${file.path}.previous');
    final before = await store.inspect(setup.session);
    expect(before.status, AiSettingsStatus.unreadable);
    expect(file.existsSync(), isFalse);
    expect(await File('${file.path}.previous').readAsBytes(), bytes);
    await File('${file.path}.tmp').writeAsBytes([7]);
    await expectLater(
      store.replaceUnreadableWithDefaults(setup.session, expected: before),
      throwsA(isA<AiFailure>()),
    );
    expect(file.existsSync(), isFalse);
    final current = await store.inspect(setup.session);
    await store.replaceUnreadableWithDefaults(setup.session, expected: current);
    expect((await store.inspect(setup.session)).status, AiSettingsStatus.ready);
    expect(File('${file.path}.previous').existsSync(), isFalse);
    expect(File('${file.path}.tmp').existsSync(), isFalse);
  });

  test('替換不可讀設定寫入失敗保留原內容，可重新檢查後重試', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final store = AiSettingsStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: LocalCryptoService(),
      repository: harness.repository,
    );
    final file = await _writeSettingsPayload(harness, setup.session, {
      ...const AiStoredSettings().toJson(),
      'version': 1,
    });
    final bytes = await file.readAsBytes();
    final blocked = Directory('${file.path}.tmp');
    await blocked.create();
    await expectLater(
      store.replaceUnreadableWithDefaults(
        setup.session,
        expected: await store.inspect(setup.session),
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await file.readAsBytes(), bytes);
    await blocked.delete();
    await store.replaceUnreadableWithDefaults(
      setup.session,
      expected: await store.inspect(setup.session),
    );
    expect(
      (await store.read(setup.session)).toJson(),
      const AiStoredSettings().toJson(),
    );
  });

  test('舊版與未知未來版本不自動改寫，明確重建設定後保留日記、金鑰與清理佇列', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final entryId = await harness.saveSimpleEntry(setup, markdownBody: '正式日記');
    final store = AiSettingsStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: LocalCryptoService(),
      repository: harness.repository,
    );
    await store.saveApiKey(first, '保留的測試金鑰');
    final queue = File(
      p.join(
        (await harness.pathStrategy.vaultRootDirectory()).path,
        'chat_diary_remote_cleanup',
        'pending.json.enc',
      ),
    );
    await queue.parent.create(recursive: true);
    await queue.writeAsBytes([1, 2, 3]);
    for (final version in [1, DataVersions.aiSettings + 1]) {
      final file = await _writeSettingsPayload(harness, setup.session, {
        ...const AiStoredSettings().toJson(),
        'version': version,
      });
      final bytes = await file.readAsBytes();
      await expectLater(store.read(setup.session), throwsA(isA<AiFailure>()));
      await expectLater(
        store.save(setup.session, const AiStoredSettings()),
        throwsA(isA<AiFailure>()),
      );
      expect(await file.readAsBytes(), bytes);
      await store.replaceUnreadableWithDefaults(
        setup.session,
        expected: await store.inspect(setup.session),
      );
      expect(
        (await store.read(setup.session)).toJson(),
        const AiStoredSettings().toJson(),
      );
      expect(
        (await harness.repository.loadEntry(
          setup.session,
          entryId,
        ))!.markdownBody,
        '正式日記',
      );
      expect(await store.readApiKey(first), '保留的測試金鑰');
      expect(await queue.readAsBytes(), [1, 2, 3]);
    }
  });

  test('排隊時凍結設定快照，更新預設連線與其他設定在同一序列合併', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final store = AiSettingsStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: LocalCryptoService(),
      repository: harness.repository,
    );
    final gate = Completer<void>();
    final blocked = harness.repository.runVaultMutation(() => gate.future);
    final enabled = ['model'];
    final a = first.copyWith(
      addedModels: ['model'],
      enabledModels: enabled,
      customConnectionId: 'aic_first',
    );
    final saving = store.save(
      setup.session,
      AiStoredSettings(
        connection: AiConnectionSettings(connections: {a.connectionId: a}),
        chatDiaryPrompts: const ChatDiaryPromptSettings(
          guidanceOverride: '保留引導',
        ),
      ),
    );
    enabled.add('排隊後才新增');
    final b = other.copyWith(customConnectionId: 'aic_second');
    final updating = store.updateActiveConnection(setup.session, b);
    gate.complete();
    await blocked;
    await saving;
    await updating;
    final result = await store.read(setup.session);
    expect(result.connection.activeConnectionId, b.connectionId);
    expect(
      result.connection.connections.keys,
      containsAll([a.connectionId, b.connectionId]),
    );
    expect(result.connection.connectionFor(a.connectionId).enabledModels, [
      'model',
    ]);
    expect(result.chatDiaryPrompts.guidanceOverride, '保留引導');
  });

  test('切換 AI 功能只改開關，保留連線、人物隱藏與提示詞', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final store = AiSettingsStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: LocalCryptoService(),
      repository: harness.repository,
    );
    expect((await store.read(setup.session)).aiEnabled, isTrue);
    await store.save(
      setup.session,
      AiStoredSettings(
        connection: AiConnectionSettings(
          connections: {first.connectionId: first},
        ),
        hidePersonNames: false,
        chatDiaryPrompts: const ChatDiaryPromptSettings(
          guidanceOverride: '保留引導',
        ),
      ),
    );

    await store.updateAiEnabled(setup.session, false);

    final result = await store.read(setup.session);
    expect(result.aiEnabled, isFalse);
    expect(result.hidePersonNames, isFalse);
    expect(result.chatDiaryPrompts.guidanceOverride, '保留引導');
    expect(result.connection.connections.keys, contains(first.connectionId));
  });

  test('模型目錄更新由儲存入口明確回寫一次，重新讀取不再改寫', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final store = AiSettingsStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: LocalCryptoService(),
      repository: harness.repository,
    );
    final config = defaultConnection(AiProvider.openai).copyWith(
      model: 'removed-model',
      enabledModels: ['removed-model'],
      knownBuiltinModels: ['removed-model'],
    );
    final file = await _writeSettingsPayload(
      harness,
      setup.session,
      AiStoredSettings(
        connection: AiConnectionSettings(connections: {'openai': config}),
      ).toJson(),
    );
    final original = await file.readAsBytes();
    final result = await store.read(setup.session);
    expect(
      result.connection.activeConfig.model,
      defaultConnection(AiProvider.openai).model,
    );
    final updated = await file.readAsBytes();
    expect(updated, isNot(original));
    await store.read(setup.session);
    expect(await file.readAsBytes(), updated);
  });

  test('只恢復通過身分與格式驗證的副本，壞主檔與錯誤身分保留現場', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final store = AiSettingsStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: LocalCryptoService(),
      repository: harness.repository,
    );
    await store.save(
      setup.session,
      const AiStoredSettings(hidePersonNames: false),
    );
    final file = File(await harness.pathStrategy.aiSettingsPath());
    final valid = await file.readAsBytes();
    await file.rename('${file.path}.previous');
    await File('${file.path}.tmp').writeAsBytes([1]);
    expect((await store.read(setup.session)).hidePersonNames, isFalse);
    await File('${file.path}.previous').writeAsBytes(valid);
    await file.writeAsBytes([2]);
    await expectLater(store.read(setup.session), throwsA(isA<Object>()));
    expect(await file.readAsBytes(), [2]);
    expect(await File('${file.path}.previous').readAsBytes(), valid);
    await store.replaceUnreadableWithDefaults(
      setup.session,
      expected: await store.inspect(setup.session),
    );
    final swapped = await _writeSettingsPayload(
      harness,
      setup.session,
      const AiStoredSettings().toJson(),
      identity: 'other-settings',
    );
    final bytes = await swapped.readAsBytes();
    await expectLater(store.read(setup.session), throwsA(isA<AiFailure>()));
    expect(await swapped.readAsBytes(), bytes);
  });

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
      AiStoredSettings(
        connection: AiConnectionSettings(
          activeConnectionId: 'custom',
          connections: {'custom': connection, second.connectionId: second},
        ),
        hidePersonNames: false,
        chatDiaryPrompts: const ChatDiaryPromptSettings(
          personalityOverride: '備份提示詞',
          guidanceOverride: '備份引導',
          generationOverride: '備份生成',
        ),
        organizationPrompts: const DiaryOrganizationPromptSettings(
          generationOverride: '整理覆寫',
        ),
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
    expect(restored.chatDiaryPrompts.personalityOverride, '備份提示詞');
    expect(restored.chatDiaryPrompts.guidanceOverride, '備份引導');
    expect(restored.chatDiaryPrompts.generationOverride, '備份生成');
    expect(restored.organizationPrompts.generationOverride, '整理覆寫');
    expect(restored.organizationPrompts.conversationOverride, isNull);
    expect(
      jsonDecode(
        await _readSettingsPlaintext(harness, setup.session),
      )['version'],
      DataVersions.aiSettings,
    );
    expect(restored.hidePersonNames, isFalse);
    expect(
      await storage.read(key: _customKey(connection)),
      'backup-synthetic-key',
    );
    expect(
      await _readSettingsPlaintext(harness, setup.session),
      isNot(contains('backup-synthetic-key')),
    );
  });
}

Future<File> _writeSettingsPayload(
  VaultTestHarness harness,
  UnlockedVaultSession session,
  Map<String, Object?> json, {
  String identity = AiSettingsStore.documentId,
}) async {
  final metadata = (await harness.repository.readRecoveryMetadata())!;
  final encrypted = await LocalCryptoService().encryptBytes(
    documentId: identity,
    vaultId: session.vaultId,
    plaintextBytes: utf8.encode(jsonEncode(json)),
    contentType: 'application/json',
    recoveryWrapKey: requireRecoveryWrapKey(session),
    recoverySlotKdf: metadata.kdf,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  final file = File(await harness.pathStrategy.aiSettingsPath());
  await file.writeAsBytes(encrypted.toFileBytes());
  return file;
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
