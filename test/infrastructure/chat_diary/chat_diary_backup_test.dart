import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/diary/diary_draft.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';
import 'package:quill_diary/infrastructure/chat_diary/chat_diary_store.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';

import '../../helpers/ai/ai_test_helpers.dart';
import '../../helpers/vault/manifest_write_test_crypto_service.dart';
import '../../helpers/vault/vault_test_harness.dart';

void main() {
  test('永久刪除無法讀取的日記也移除相鄰聊天與恢復檔', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final entryId = await harness.saveSimpleEntry(setup);
    final store = ChatDiaryStore(
      paths: harness.pathStrategy,
      crypto: LocalCryptoService(),
      repository: harness.repository,
      editorDraftStore: EditorDraftStore(
        pathStrategy: harness.pathStrategy,
        cryptoService: LocalCryptoService(),
      ),
    );
    final chat = testChatDiarySession(vaultId: setup.session.vaultId)
      ..generatedEntryId = entryId;
    await store.save(chat, setup.session);
    await store.complete(chat.id, entryId, setup.session);
    final entryPath = await harness.pathStrategy.entryAbsolutePath(
      date: const DateOnly('2026-05-24'),
      entryId: entryId,
    );
    final chatPath = VaultPathStrategy.chatFileBesideEntry(entryPath);
    for (final suffix in ['.previous', '.tmp']) {
      await File(chatPath).copy('$chatPath$suffix');
    }
    await File(entryPath).writeAsBytes([0, 1, 2]);
    final report = await harness.repository.inspectVaultWithReport(
      setup.session,
    );
    await harness.repository.permanentlyDeleteAbnormalFindings(
      setup.session,
      findings: report.findings,
    );
    expect(File(entryPath).existsSync(), isFalse);
    for (final suffix in ['', '.previous', '.tmp']) {
      expect(File('$chatPath$suffix').existsSync(), isFalse);
    }
  });

  for (final variant in ['相同聊天', '只有副本有聊天', '聊天衝突', '聊天無法解密', '目的地已有不同的暫存聊天']) {
    test('清理重複日記時$variant會保留正確內容並同步處理聊天檔', () async {
      final harness = await VaultTestHarness.create();
      addTearDown(harness.dispose);
      final setup = await harness.repository.setupRecoveryKey();
      final entryId = await harness.saveSimpleEntry(setup);
      final store = ChatDiaryStore(
        paths: harness.pathStrategy,
        crypto: LocalCryptoService(),
        repository: harness.repository,
        editorDraftStore: EditorDraftStore(
          pathStrategy: harness.pathStrategy,
          cryptoService: LocalCryptoService(),
        ),
      );
      final chat = testChatDiarySession(vaultId: setup.session.vaultId)
        ..generatedEntryId = entryId;
      await store.save(chat, setup.session);
      await store.complete(chat.id, entryId, setup.session);
      final entryPath = await harness.pathStrategy.entryAbsolutePath(
        date: const DateOnly('2026-05-24'),
        entryId: entryId,
      );
      final chatPath = VaultPathStrategy.chatFileBesideEntry(entryPath);
      final original = await File(chatPath).readAsBytes();
      final copyPath = p.join(
        (await harness.pathStrategy.vaultRootDirectory()).path,
        'entries',
        'copies',
        '$entryId.md.enc',
      );
      final copyChat = VaultPathStrategy.chatFileBesideEntry(copyPath);
      await File(copyPath).parent.create(recursive: true);
      await File(entryPath).copy(copyPath);
      List<int>? temporaryChat;
      if (variant == '聊天衝突') {
        final other = (await store.loadForEntry(entryId, setup.session))!
          ..openingMessage = '不同的聊天紀錄';
        await store.save(other, setup.session);
        await File(chatPath).copy(copyChat);
        await File(chatPath).writeAsBytes(original);
      } else if (variant == '只有副本有聊天') {
        await File(chatPath).rename(copyChat);
      } else if (variant == '聊天無法解密') {
        await File(chatPath).writeAsBytes([0, 1, 2]);
        await File(copyChat).writeAsBytes([3, 4, 5]);
      } else if (variant == '目的地已有不同的暫存聊天') {
        final other = (await store.loadForEntry(entryId, setup.session))!
          ..openingMessage = '仍需保留的暫存聊天';
        await store.save(other, setup.session);
        temporaryChat = await File(chatPath).readAsBytes();
        await File(chatPath).rename('$chatPath.tmp');
        await File(copyChat).writeAsBytes(original);
      } else {
        await File(chatPath).copy(copyChat);
      }
      final report = await harness.repository.repairVaultWithReport(
        setup.session,
      );
      final conflicting = variant == '聊天衝突' || variant == '聊天無法解密';
      expect(File(copyPath).existsSync(), conflicting);
      expect(File(copyChat).existsSync(), conflicting);
      expect(report.hasUnresolvedIssues, conflicting);
      if (temporaryChat != null) {
        expect(File('$chatPath.tmp').existsSync(), isTrue);
        expect(await File('$chatPath.tmp').readAsBytes(), temporaryChat);
      }
      expect(
        await File(chatPath).readAsBytes(),
        variant == '聊天無法解密' ? [0, 1, 2] : original,
      );
      if (variant == '聊天無法解密') {
        expect(await File(copyChat).readAsBytes(), [3, 4, 5]);
      } else {
        expect((await store.loadForEntry(entryId, setup.session))!.id, chat.id);
      }
    });
  }

  for (final clearComposer in [false, true]) {
    test('${clearComposer ? '清空內容' : '刪除聊天'}一併移除附圖、編輯草稿、恢復檔與解密暫存', () async {
      final harness = await VaultTestHarness.create();
      addTearDown(harness.dispose);
      final setup = await harness.repository.setupRecoveryKey();
      final draftStore = EditorDraftStore(
        pathStrategy: harness.pathStrategy,
        cryptoService: LocalCryptoService(),
      );
      final store = ChatDiaryStore(
        paths: harness.pathStrategy,
        crypto: LocalCryptoService(),
        repository: harness.repository,
        editorDraftStore: draftStore,
      );
      final chat = testChatDiarySession(vaultId: setup.session.vaultId)
        ..composerText = '待刪除的聊天';
      final retainedChat = testChatDiarySession(vaultId: setup.session.vaultId)
        ..composerText = '繼續保留的聊天';
      await store.save(chat, setup.session);
      await store.save(retainedChat, setup.session);
      final image = ChatDiaryImage(
        id: generateAssetId(),
        mimeType: 'image/png',
        filename: 'image.png',
      );
      await store.saveImage(chat.id, image, testAiPng, setup.session);
      final draftKey = ChatDiarySession.draftKeyFor(chat.id);
      final relativePath = await draftStore.stagePendingBytes(
        draftKey,
        testAiPng,
        'image.png',
        setup.session,
      );
      final previewPath = await draftStore.materializePendingFileForPreview(
        draftKey,
        relativePath,
        setup.session,
      );
      final directory = await store.draftDirectory(chat.id);
      for (final suffix in ['.previous', '.tmp']) {
        await File(p.join(directory.path, 'session.json.enc'))
            .copy(p.join(directory.path, 'session.json.enc$suffix'));
      }
      final editorFile = File(
        await harness.pathStrategy.editorDraftFilePath(draftKey),
      );
      await editorFile.writeAsBytes([1, 2, 3]);
      if (clearComposer) {
        chat.composerText = '';
        await store.save(chat, setup.session);
      } else {
        await store.delete(chat.id, session: setup.session);
      }
      expect(directory.existsSync(), isFalse);
      expect(File(previewPath).parent.existsSync(), isFalse);
      expect(await store.load(chat.id, setup.session), isNull);
      expect(
        (await store.load(retainedChat.id, setup.session))!.composerText,
        '繼續保留的聊天',
      );
    });
  }

  test('未完成聊天的圖片檔案不在時回傳空值', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final store = ChatDiaryStore(
      paths: harness.pathStrategy,
      crypto: LocalCryptoService(),
      repository: harness.repository,
      editorDraftStore: EditorDraftStore(
        pathStrategy: harness.pathStrategy,
        cryptoService: LocalCryptoService(),
      ),
    );
    final image = ChatDiaryImage(
      id: generateAssetId(),
      mimeType: 'image/png',
      filename: 'image.png',
    );
    final chat = testChatDiarySession(vaultId: setup.session.vaultId)
      ..images.add(image);
    expect(await store.readImage(chat, image.id, setup.session), isNull);
  });

  test('切換服務後遠端圖片清理保留各自連線，晚到的上傳沿用請求快照', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final crypto = LocalCryptoService();
    final store = ChatDiaryStore(
      paths: harness.pathStrategy,
      crypto: crypto,
      repository: harness.repository,
      editorDraftStore: EditorDraftStore(
        pathStrategy: harness.pathStrategy,
        cryptoService: LocalCryptoService(),
      ),
    );
    final chat = testChatDiarySession(vaultId: setup.session.vaultId);
    const old = AiConnectionConfig(
      provider: AiProvider.openai,
      model: 'old-model',
    );
    const current = AiConnectionConfig(
      provider: AiProvider.claude,
      model: 'new-model',
    );
    chat.connectionConfig = current;
    const file = AiRemoteFile(id: 'same-synthetic-id', uri: '');
    await store.trackRemoteFile(
      chat,
      file,
      setup.session,
      connectionConfig: old,
    );
    await store.trackRemoteFile(
      chat,
      file,
      setup.session,
      connectionConfig: current,
    );
    final root = Directory(
      '${(await harness.pathStrategy.vaultRootDirectory()).path}/chat_diary_remote_cleanup',
    );
    final records = await root
        .list()
        .where((f) => f is File && f.path.endsWith('.enc'))
        .cast<File>()
        .toList();
    expect(records, hasLength(2));
    final providers = <String>{};
    for (final record in records) {
      final parsed = crypto.parseFileBytes(await record.readAsBytes());
      final bytes = await crypto.decryptBytes(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: DecryptionContext(
          vaultId: setup.session.vaultId,
          trustedDevice: setup.session.trustedDevice,
          recoveryWrapKey: setup.session.recoveryWrapKey,
          deviceSlotId: setup.session.deviceSlotId,
        ),
      );
      final data = jsonDecode(utf8.decode(bytes)) as Map;
      providers.add((data['config'] as Map)['provider'] as String);
      expect((data['files'] as List).single['id'], 'same-synthetic-id');
    }
    expect(providers, {'openai', 'claude'});
  });
  test('清理跳過未完成聊天，重試時保留網路等待期間新增的檔案紀錄', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final gate = Completer<void>();
    final deleting = Completer<void>();
    final deleted = <String>[];
    var failNewFile = true;
    final store = ChatDiaryStore(
      paths: harness.pathStrategy,
      crypto: LocalCryptoService(),
      repository: harness.repository,
      editorDraftStore: EditorDraftStore(
        pathStrategy: harness.pathStrategy,
        cryptoService: LocalCryptoService(),
      ),
      clientFactory: (connectionConfig, key) =>
          FakeAiClient(connectionConfig)
            ..onDeleteFile = (file) async {
              if (deleted.isEmpty) {
                deleting.complete();
                await gate.future;
              }
              if (file.id == 'new' && failNewFile) {
                failNewFile = false;
                throw const AiFailure(AiErrorCode.network);
              }
              deleted.add(file.id);
            },
    );
    final chat = testChatDiarySession(vaultId: setup.session.vaultId)
      ..composerText = '進行中的對話';
    await store.save(chat, setup.session);
    const connectionConfig = AiConnectionConfig(
      provider: AiProvider.openai,
      model: 'model',
    );
    const oldFile = AiRemoteFile(id: 'old', uri: '');
    const newFile = AiRemoteFile(id: 'new', uri: '');
    await store.trackRemoteFile(
      chat,
      oldFile,
      setup.session,
      connectionConfig: connectionConfig,
    );
    expect(
      await store.cleanupRemoteFiles(setup.session, (_) async => 'key'),
      isTrue,
    );
    expect(deleted, isEmpty);
    await store.delete(chat.id);
    final cleaning = store.cleanupRemoteFiles(
      setup.session,
      (_) async => 'key',
    );
    await deleting.future;
    await store.trackRemoteFile(
      chat,
      newFile,
      setup.session,
      connectionConfig: connectionConfig,
    );
    gate.complete();
    expect(await cleaning, isTrue);
    expect(deleted, ['old']);
    expect(
      await store.cleanupRemoteFiles(setup.session, (_) async => 'key'),
      isFalse,
    );
    expect(deleted, ['old']);
    expect(
      await store.cleanupRemoteFiles(setup.session, (_) async => 'key'),
      isTrue,
    );
    expect(deleted, ['old', 'new']);
    final cleanupRoot = Directory(
      p.join(
        (await harness.pathStrategy.vaultRootDirectory()).path,
        'chat_diary_remote_cleanup',
      ),
    );
    expect(cleanupRoot.listSync(recursive: true).whereType<File>(), isEmpty);
  });

  test('只有有內容的聊天列入草稿清單，載入指定聊天不改變其服務與內容', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final store = ChatDiaryStore(
      paths: harness.pathStrategy,
      crypto: LocalCryptoService(),
      repository: harness.repository,
      editorDraftStore: EditorDraftStore(
        pathStrategy: harness.pathStrategy,
        cryptoService: LocalCryptoService(),
      ),
    );
    const connectionConfig = AiConnectionConfig(
      provider: AiProvider.custom,
      customProtocol: AiApiProtocol.ollamaChat,
      model: 'first-model',
      baseUrl: 'http://127.0.0.1:11434',
    );
    final chats = [
      for (var i = 0; i < 3; i++)
        testChatDiarySession(vaultId: setup.session.vaultId)
          ..connectionConfig = connectionConfig,
    ];
    for (final chat in chats) {
      await store.save(chat, setup.session);
      expect((await store.draftDirectory(chat.id)).existsSync(), isFalse);
    }
    expect(chats.map((chat) => chat.id).toSet(), hasLength(3));
    expect(await store.list(setup.session), isEmpty);
    chats.first.composerText = '只屬於第一份的文字';
    await store.save(chats.first, setup.session);
    expect(
      ((await store.load(chats.first.id, setup.session))!).composerText,
      '只屬於第一份的文字',
    );
    expect(await store.load(chats.last.id, setup.session), isNull);
    expect((await store.list(setup.session)).single.id, chats.first.id);
  });

  test('不存在的草稿回傳空值，損壞草稿保留原檔並拋出錯誤', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final store = ChatDiaryStore(
      paths: harness.pathStrategy,
      crypto: LocalCryptoService(),
      repository: harness.repository,
      editorDraftStore: EditorDraftStore(
        pathStrategy: harness.pathStrategy,
        cryptoService: LocalCryptoService(),
      ),
    );
    final chat = testChatDiarySession(vaultId: setup.session.vaultId);
    expect(await store.load(chat.id, setup.session), isNull);
    expect((await store.draftDirectory(chat.id)).existsSync(), isFalse);
    chat.composerText = '必須保留的草稿';
    await store.save(chat, setup.session);
    final file = File(
      p.join((await store.draftDirectory(chat.id)).path, 'session.json.enc'),
    );
    await file.writeAsBytes([0, 1, 2]);
    await expectLater(
      store.load(chat.id, setup.session),
      throwsFormatException,
    );
    expect(await file.readAsBytes(), [0, 1, 2]);
  });

  test('完整備份還原保留聊天與圖片並排除未完成聊天', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final entryId = await harness.saveSimpleEntry(setup);
    final store = ChatDiaryStore(
      paths: harness.pathStrategy,
      crypto: LocalCryptoService(),
      repository: harness.repository,
      editorDraftStore: EditorDraftStore(
        pathStrategy: harness.pathStrategy,
        cryptoService: LocalCryptoService(),
      ),
    );
    final kept = testChatDiarySession(vaultId: setup.session.vaultId);
    final image = ChatDiaryImage(
      id: generateAssetId(),
      mimeType: 'image/png',
      filename: 'image.png',
    );
    kept.images.add(image);
    kept.appendMessage(
      ChatDiaryMessage(
        id: generateEntryId(),
        isUser: true,
        text: '保留原文',
        outboundText: '代號',
        imageIds: [image.id],
      ),
    );
    final oldMessageId = kept.messages.first.id;
    final otherImage = ChatDiaryImage(
      id: generateAssetId(),
      mimeType: 'image/png',
      filename: 'image.png',
    );
    kept.images.add(otherImage);
    kept.appendMessage(
      ChatDiaryMessage(
        id: generateEntryId(),
        isUser: true,
        text: '另一個分支',
        outboundText: '另一個分支',
        imageIds: [otherImage.id],
        systemPromptSnapshot: '分支提示詞快照',
      ),
    );
    await store.save(kept, setup.session);
    await store.saveImage(kept.id, image, testAiPng, setup.session);
    await store.saveImage(kept.id, otherImage, testAiPng, setup.session);
    final entry = await harness.repository.loadEntry(setup.session, entryId);
    await harness.repository.saveEntry(
      setup.session,
      entry!.copyWith(attachmentIds: [otherImage.id]),
      pendingAttachments: [
        PendingAttachment(
          assetId: otherImage.id,
          bytes: testAiPng,
          mimeType: otherImage.mimeType,
          originalFilename: otherImage.filename,
        ),
      ],
    );
    await store.complete(kept.id, entryId, setup.session);
    final unfinished = testChatDiarySession(vaultId: setup.session.vaultId)
      ..composerText = '不進備份的草稿';
    await store.save(unfinished, setup.session);
    final chatPath = await harness.pathStrategy.entryChatAbsolutePath(
      date: entry.date,
      entryId: entryId,
    );
    await File(chatPath).rename('$chatPath.previous');
    final archive = harness.createTransferIo();
    final backup = File('${harness.tempDir.path}/chat.zip');
    await archive.backup.writeBackupZip(backup);
    final names = ZipDecoder()
        .decodeBytes(await backup.readAsBytes())
        .files
        .map((f) => f.name)
        .toList();
    expect(
      names.any(
        (n) => n.contains('entries/') && n.endsWith('$entryId.chat.json.enc'),
      ),
      isTrue,
    );
    expect(names.any((n) => n.contains('.chat-images/')), isFalse);
    expect(names.any((n) => n.contains('chat_diary_drafts')), isFalse);
    expect(names.any((n) => n.contains('chat_diary_remote_cleanup')), isFalse);
    final edited = await store.loadForEntry(entryId, setup.session);
    edited!.activeMessages.single.text = '備份後才改寫';
    await store.save(edited, setup.session);
    await harness.repository.closeUnlockedResources();
    await archive.backup.restoreBackupZip(backup);
    final restoredSession = await harness.repository.unlockWithRecoveryKey(
      setup.recoveryKey,
    );
    final restored = await store.loadForEntry(entryId, restoredSession);
    expect(restored, isNotNull);
    expect(restored!.messages, hasLength(2));
    expect(restored.activeMessages.single.text, '另一個分支');
    expect(restored.activeMessages.single.systemPromptSnapshot, '分支提示詞快照');
    restored.selectMessage(oldMessageId);
    expect(restored.activeMessages.single.text, '保留原文');
    expect(
      await store.readImage(restored, otherImage.id, restoredSession),
      testAiPng,
    );
    expect(await store.readImage(restored, image.id, restoredSession), isNull);
    expect(await store.list(restoredSession), isEmpty);
  });

  test('金鑰輪替同時涵蓋未完成聊天與其編輯草稿路徑', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final store = ChatDiaryStore(
      paths: harness.pathStrategy,
      crypto: LocalCryptoService(),
      repository: harness.repository,
      editorDraftStore: EditorDraftStore(
        pathStrategy: harness.pathStrategy,
        cryptoService: LocalCryptoService(),
      ),
    );
    final chat = testChatDiarySession(vaultId: setup.session.vaultId)
      ..composerText = '輪替後仍能續寫';
    await store.save(chat, setup.session);
    final draftStore = EditorDraftStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: LocalCryptoService(),
    );
    final key = ChatDiarySession.draftKeyFor(chat.id);
    final relative = await draftStore.stagePendingBytes(
      key,
      testAiPng,
      'image.png',
      setup.session,
    );
    final assetId = generateAssetId();
    await draftStore.write(
      key,
      EditorDraftRecord(
        dateValue: chat.date,
        entryHour: 12,
        entryMinute: 0,
        tags: [],
        markdownBody: '還未存成日記的草稿',
        attachmentIds: [assetId],
        pendingAttachments: [
          EditorDraftPendingAttachment(
            assetId: assetId,
            relativePath: relative,
            mimeType: 'image/png',
            originalFilename: 'image.png',
          ),
        ],
        provisionalEntryId: generateEntryId(),
        createdAt: chat.createdAt,
        updatedAt: chat.createdAt,
      ),
      setup.session,
    );
    final rotated = await harness.repository.rotateRecoveryKey(setup.session);
    expect(
      ((await store.load(chat.id, rotated.session))!).composerText,
      '輪替後仍能續寫',
    );
    expect(
      (await draftStore.read(key, rotated.session))!.markdownBody,
      '還未存成日記的草稿',
    );
    final preview = await draftStore.materializePendingFileForPreview(
      key,
      relative,
      rotated.session,
    );
    expect(await File(preview).readAsBytes(), testAiPng);
    await draftStore.clearMaterializedPendingFiles(key);
    final path = await harness.pathStrategy.editorDraftDirectory(
      ChatDiarySession.draftKeyFor(chat.id),
    );
    expect(path.path, contains('chat_diary_drafts'));
  });

  test('日記成功但聊天收尾中斷時，下次開清單寫到日記旁邊', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final entryId = await harness.saveSimpleEntry(setup);
    final store = ChatDiaryStore(
      paths: harness.pathStrategy,
      crypto: LocalCryptoService(),
      repository: harness.repository,
      editorDraftStore: EditorDraftStore(
        pathStrategy: harness.pathStrategy,
        cryptoService: LocalCryptoService(),
      ),
    );
    final kept = testChatDiarySession(vaultId: setup.session.vaultId)
      ..generatedEntryId = entryId;
    final pending = testChatDiarySession(vaultId: setup.session.vaultId)
      ..composerText = '尚未完成的輸入';
    await store.save(kept, setup.session);
    await store.save(pending, setup.session);
    final list = await store.list(setup.session);
    expect(list.map((chat) => chat.id), [pending.id]);
    final attached = await store.loadForEntry(entryId, setup.session);
    expect(attached!.id, kept.id);
    expect(attached.finished, isTrue);
    await store.complete(kept.id, entryId, setup.session);
    expect((await store.loadForEntry(entryId, setup.session))!.id, kept.id);
    expect(
      await harness.repository.loadEntry(setup.session, entryId),
      isNotNull,
    );
  });

  test('日記移除附件後聊天圖片回傳已刪除，改日期與輪替保留聊天 JSON', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final entryId = await harness.saveSimpleEntry(setup);
    final store = ChatDiaryStore(
      paths: harness.pathStrategy,
      crypto: LocalCryptoService(),
      repository: harness.repository,
      editorDraftStore: EditorDraftStore(
        pathStrategy: harness.pathStrategy,
        cryptoService: LocalCryptoService(),
      ),
    );
    final chat = testChatDiarySession(vaultId: setup.session.vaultId);
    final image = ChatDiaryImage(
      id: generateAssetId(),
      mimeType: 'image/png',
      filename: 'image.png',
    );
    chat.images.add(image);
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: '照片',
        outboundText: '照片',
        imageIds: [image.id],
      ),
    );
    await store.save(chat, setup.session);
    await store.saveImage(chat.id, image, testAiPng, setup.session);
    final entry = (await harness.repository.loadEntry(setup.session, entryId))!;
    await harness.repository.saveEntry(
      setup.session,
      entry.copyWith(attachmentIds: [image.id]),
      pendingAttachments: [
        PendingAttachment(
          assetId: image.id,
          bytes: testAiPng,
          mimeType: image.mimeType,
          originalFilename: image.filename,
        ),
      ],
    );
    await store.complete(chat.id, entryId, setup.session);
    await harness.repository.saveEntry(
      setup.session,
      entry.copyWith(date: const DateOnly('2026-09-12')),
    );
    final restored = (await store.loadForEntry(entryId, setup.session))!;
    expect(await store.readImage(restored, image.id, setup.session), isNull);
    final completedChatPath = await harness.pathStrategy.entryChatAbsolutePath(
      date: const DateOnly('2026-09-12'),
      entryId: entryId,
    );
    await File(completedChatPath).rename('$completedChatPath.previous');
    final rotated = await harness.repository.rotateRecoveryKey(setup.session);
    expect(await store.loadForEntry(entryId, rotated.session), isNotNull);
    expect(await store.readImage(restored, image.id, rotated.session), isNull);
    await expectLater(store.save(chat, setup.session), throwsA(anything));
    await harness.repository.deleteEntry(rotated.session, entryId);
    expect(await store.loadForEntry(entryId, rotated.session), isNull);
  });

  for (final repair in [false, true]) {
    test('${repair ? '修復搬移' : '日記改日期'}在 manifest 寫入失敗時保留來源聊天 JSON', () async {
      final crypto = ManifestWriteTestCryptoService();
      final harness = await VaultTestHarness.create(cryptoService: crypto);
      addTearDown(harness.dispose);
      final setup = await harness.repository.setupRecoveryKey();
      final entryId = await harness.saveSimpleEntry(setup);
      final store = ChatDiaryStore(
        paths: harness.pathStrategy,
        crypto: crypto,
        repository: harness.repository,
        editorDraftStore: EditorDraftStore(
          pathStrategy: harness.pathStrategy,
          cryptoService: LocalCryptoService(),
        ),
      );
      final chat = testChatDiarySession(vaultId: setup.session.vaultId)
        ..generatedEntryId = entryId;
      await store.save(chat, setup.session);
      await store.complete(chat.id, entryId, setup.session);
      final entry = (await harness.repository.loadEntry(
        setup.session,
        entryId,
      ))!;
      var source = await harness.pathStrategy.entryAbsolutePath(
        date: entry.date,
        entryId: entryId,
      );
      if (repair) {
        final wrong = p.join(
          (await harness.pathStrategy.vaultRootDirectory()).path,
          'entries',
          '2099',
          '01',
          '$entryId.md.enc',
        );
        await File(wrong).parent.create(recursive: true);
        await File(source).rename(wrong);
        await File(VaultPathStrategy.chatFileBesideEntry(source))
            .rename(VaultPathStrategy.chatFileBesideEntry(wrong));
        source = wrong;
      }
      crypto.failManifestWrites = true;
      await expectLater(
        repair
            ? harness.repository.repairVaultWithReport(setup.session)
            : harness.repository.saveEntry(
                setup.session,
                entry.copyWith(date: const DateOnly('2026-10-01')),
              ),
        throwsStateError,
      );
      expect(File(source).existsSync(), isTrue);
      expect(
        await harness.repository.readDecryptedAssetBytes(
          setup.session,
          VaultPathStrategy.chatFileBesideEntry(source),
        ),
        isNotNull,
      );
    });
  }

  test('日記改日期會搬走聊天 JSON，刪除日記會刪掉它', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final entryId = await harness.saveSimpleEntry(setup);
    final store = ChatDiaryStore(
      paths: harness.pathStrategy,
      crypto: LocalCryptoService(),
      repository: harness.repository,
      editorDraftStore: EditorDraftStore(
        pathStrategy: harness.pathStrategy,
        cryptoService: LocalCryptoService(),
      ),
    );
    final chat = testChatDiarySession(vaultId: setup.session.vaultId)
      ..generatedEntryId = entryId;
    await store.save(chat, setup.session);
    await store.complete(chat.id, entryId, setup.session);
    const originalDate = DateOnly('2026-05-24');
    final before = File(
      await harness.pathStrategy.entryChatAbsolutePath(
        date: originalDate,
        entryId: entryId,
      ),
    );
    expect(before.existsSync(), isTrue);
    final entry = await harness.repository.loadEntry(setup.session, entryId);
    await harness.repository.saveEntry(
      setup.session,
      entry!.copyWith(date: const DateOnly('2026-08-02')),
    );
    expect(before.existsSync(), isFalse);
    final after = File(
      await harness.pathStrategy.entryChatAbsolutePath(
        date: const DateOnly('2026-08-02'),
        entryId: entryId,
      ),
    );
    expect(after.existsSync(), isTrue);
    expect((await store.loadForEntry(entryId, setup.session))!.id, chat.id);
    await harness.repository.deleteEntry(setup.session, entryId);
    expect(after.existsSync(), isFalse);
  });
}
