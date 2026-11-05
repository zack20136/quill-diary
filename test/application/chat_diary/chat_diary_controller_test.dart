import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_controller.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_generations.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/editor/editor_flow_controller.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/ai/ai_model_thinking_override.dart';
import 'package:quill_diary/domain/ai/ai_stored_settings.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_generation.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/diary/editor_draft.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../../helpers/ai/ai_test_helpers.dart';
import '../../helpers/shared/test_l10n.dart';
import '../../helpers/vault/vault_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late VaultTestHarness harness;
  late ProviderContainer container;
  late FailingChatDiaryStore store;
  late OverviewAiSettingsStore settings;
  late FakeAiClient client;
  late ChatDiaryController controller;
  late ProviderSubscription<ChatDiaryController> subscription;
  late ChatDiarySession chat;
  late RecoverySetupResult setup;
  late UserPreferences preferences;
  late GatedEditorDraftStore gatedDrafts;
  late List<String> clientKeys;
  late List<AiConnectionConfig> clientConfigs;
  late List<FakeAiClient> queuedClients;

  setUp(() async {
    harness = await VaultTestHarness.create();
    setup = await harness.repository.setupRecoveryKey();
    gatedDrafts = GatedEditorDraftStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: LocalCryptoService(),
    );
    store = FailingChatDiaryStore(
      paths: harness.pathStrategy,
      crypto: LocalCryptoService(),
      repository: harness.repository,
      editorDraftStore: gatedDrafts,
    );
    chat = testChatDiarySession(vaultId: setup.session.vaultId);
    settings = OverviewAiSettingsStore()
      ..settings = AiConnectionSettings(
        activeConnectionId: chat.connectionConfig.connectionId,
        connections: {
          chat.connectionConfig.connectionId: chat.connectionConfig,
        },
      );
    client = FakeAiClient(chat.connectionConfig);
    clientKeys = [];
    clientConfigs = [];
    queuedClients = [];
    preferences = UserPreferences(
      storageFile: File('${harness.tempDir.path}/preferences.json'),
    );
    container = ProviderContainer(
      overrides: [
        vaultPathStrategyProvider.overrideWithValue(harness.pathStrategy),
        vaultRepositoryProvider.overrideWithValue(harness.repository),
        chatDiaryStoreProvider.overrideWithValue(store),
        editorDraftStoreProvider.overrideWithValue(gatedDrafts),
        aiSettingsStoreProvider.overrideWithValue(settings),
        aiClientFactoryProvider.overrideWithValue((connectionConfig, key) {
          clientKeys.add(key);
          clientConfigs.add(connectionConfig);
          return queuedClients.isEmpty ? client : queuedClients.removeAt(0);
        }),
        userPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    subscription = container.listen(
      chatDiaryControllerProvider(chat.id),
      (_, _) {},
    );
    container.read(appSessionProvider.notifier).activateSession(setup.session);
    controller = container.read(chatDiaryControllerProvider(chat.id));
    await controller.start(chat.id, setup.session, openingMessage: '');
    chat = controller.chat!;
  });
  tearDown(() async {
    container.dispose();
    await store.flush();
    await harness.dispose();
  });

  test('生成離頁後持續工作、暫緩自動鎖定，完成後保留草稿且不重送', () async {
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: '今天去散步',
        outboundText: '今天去散步',
      ),
    );
    final stream = StreamController<String>();
    final started = Completer<void>();
    client.response = () {
      started.complete();
      return stream.stream;
    };
    final phases = <ChatDiaryGenerationPhase>[];
    final watching = container.listen(chatDiaryGenerationsProvider, (_, jobs) {
      phases.add(jobs[(chat.vaultId, chat.id)]!.phase);
    });
    final generating = controller.generate(testZhL10n);
    await started.future;
    expect(phases.last, ChatDiaryGenerationPhase.waiting);
    await container.read(appSessionProvider.notifier).expireFromInactivity();
    expect(container.read(appSessionProvider).isUnlocked, isTrue);
    subscription.close();
    await container.pump();
    expect(controller.busy, isTrue);
    expect(
      await controller.load(chat.id, setup.session),
      ChatDiaryLoadResult.loaded,
    );
    expect(
      await controller.generate(testZhL10n),
      ChatDiaryGenerationResult.notGenerated,
    );
    stream.add('# 今天\n\n散步時心情很好。');
    await stream.close();
    expect(await generating, ChatDiaryGenerationResult.generated);
    expect(phases, [
      ChatDiaryGenerationPhase.preparing,
      ChatDiaryGenerationPhase.waiting,
      ChatDiaryGenerationPhase.writing,
      ChatDiaryGenerationPhase.saving,
      ChatDiaryGenerationPhase.completed,
    ]);
    expect(client.calls, hasLength(1));
    expect(
      (await store.load(chat.id, setup.session))!.generatedEntryId,
      isNotNull,
    );
    watching.close();
  });

  test('生成期間手動鎖定立即停止，晚到結果不會發布完成或建立草稿', () async {
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: '合成片段',
        outboundText: '合成片段',
      ),
    );
    final stream = StreamController<String>();
    final started = Completer<void>();
    client.response = () {
      started.complete();
      return stream.stream;
    };
    final generating = controller.generate(testZhL10n);
    await started.future;
    await container.read(appSessionProvider.notifier).lock();
    expect(controller.chat, isNull);
    expect(client.closed, isTrue);
    expect(
      container
          .read(chatDiaryGenerationsProvider)[(chat.vaultId, chat.id)]!
          .phase,
      ChatDiaryGenerationPhase.cancelled,
    );
    stream.add('# 晚到\n\n不應保存');
    await stream.close();
    expect(await generating, ChatDiaryGenerationResult.notGenerated);
    expect(
      (await store.load(chat.id, setup.session))!.generatedEntryId,
      isNull,
    );
  });

  test('兩個聊天獨立生成，一個完成後另一個仍暫緩鎖定，停止只取消指定工作', () async {
    final secondId = generateChatDiaryId();
    final secondSubscription = container.listen(
      chatDiaryControllerProvider(secondId),
      (_, _) {},
    );
    final second = secondSubscription.read();
    await second.start(secondId, setup.session, openingMessage: '');
    for (final current in [controller, second]) {
      current.chat!.appendMessage(
        ChatDiaryMessage(
          id: 'user',
          isUser: true,
          text: '各自的片段',
          outboundText: '各自的片段',
        ),
      );
    }
    final streams = [StreamController<String>(), StreamController<String>()];
    final started = [Completer<void>(), Completer<void>()];
    final otherClient = FakeAiClient(chat.connectionConfig);
    for (var index = 0; index < 2; index++) {
      [client, otherClient][index].response = () {
        started[index].complete();
        return streams[index].stream;
      };
    }
    queuedClients.addAll([client, otherClient]);
    final firstGeneration = controller.generate(testZhL10n);
    await started.first.future;
    final secondGeneration = second.generate(testZhL10n);
    await started.last.future;
    streams.first.add('# 第一篇\n\n完成');
    await streams.first.close();
    expect(await firstGeneration, ChatDiaryGenerationResult.generated);
    expect(controller.canGenerate, isTrue);
    await container.read(appSessionProvider.notifier).expireFromInactivity();
    expect(container.read(appSessionProvider).isUnlocked, isTrue);
    second.stop();
    streams.last.add('晚到內容');
    await streams.last.close();
    expect(await secondGeneration, ChatDiaryGenerationResult.notGenerated);
    expect(
      container
          .read(chatDiaryGenerationsProvider)[(chat.vaultId, chat.id)]!
          .phase,
      ChatDiaryGenerationPhase.completed,
    );
    expect(
      container
          .read(chatDiaryGenerationsProvider)[(chat.vaultId, secondId)]!
          .phase,
      ChatDiaryGenerationPhase.cancelled,
    );
    secondSubscription.close();
  });

  test('等待草稿保存時離開，不交接編輯器也不鎖住後續聊天', () async {
    controller.updateComposer('尚未離開前的輸入', []);
    final saved = Completer<void>();
    store.saveGate = saved.future;
    store.saveStarted = Completer<void>();
    var current = true;
    final handOff = controller.handOffToEditor(canOpen: () => current);
    await store.saveStarted!.future;
    current = false;
    saved.complete();
    expect(await handOff, isFalse);
    expect(controller.canSend, isTrue);
    expect(controller.chat!.composerText, '尚未離開前的輸入');
  });

  test('生成錯誤不會遮住後續獨立的保存錯誤', () async {
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: '合成片段',
        outboundText: '合成片段',
      ),
    );
    client.failure = const AiFailure(AiErrorCode.tls);
    await controller.generate(testZhL10n);
    expect(controller.errorFromGeneration, isTrue);
    store.failSaves = true;
    await controller.persist();
    expect(controller.error, AiErrorCode.storage);
    expect(controller.errorFromGeneration, isFalse);
  });

  for (final fails in [false, true]) {
    test('無畫面監聽仍完成${fails ? '失敗' : '成功'}回覆，再釋放聊天', () async {
      final stream = StreamController<String>();
      final started = Completer<void>();
      client.response = () {
        started.complete();
        return stream.stream;
      };
      controller.updateComposer('合成測試內容', []);
      final sending = controller.send();
      await started.future;
      subscription.close();
      await container.pump();
      expect(container.exists(chatDiaryControllerProvider(chat.id)), isTrue);
      expect(client.closed, isFalse);
      expect(
        await controller.load(chat.id, setup.session),
        ChatDiaryLoadResult.loaded,
      );
      expect(controller.busy, isTrue);
      if (fails) {
        stream.addError(const AiFailure(AiErrorCode.network));
      } else {
        stream.add('完整的合成回覆');
      }
      await stream.close();
      await sending;
      await container.pump();
      expect(container.exists(chatDiaryControllerProvider(chat.id)), isFalse);
      expect(client.calls, hasLength(1));
      final stored = (await store.load(chat.id, setup.session))!;
      expect(
        stored.messages.last.status,
        fails ? ChatDiaryMessageStatus.failed : ChatDiaryMessageStatus.complete,
      );
      expect(stored.messages.last.text, fails ? '' : '完整的合成回覆');
    });
  }

  test('串流結束後仍保留聊天，等最終保存完成才釋放', () async {
    final stream = StreamController<String>();
    final started = Completer<void>();
    client.response = () {
      started.complete();
      return stream.stream;
    };
    controller.updateComposer('等候保存', []);
    final sending = controller.send();
    await started.future;
    final saved = Completer<void>();
    store.saveGate = saved.future;
    store.saveStarted = Completer<void>();
    subscription.close();
    stream.add('保存後才能釋放');
    await stream.close();
    await store.saveStarted!.future;
    await container.pump();
    expect(controller.busy, isTrue);
    expect(container.exists(chatDiaryControllerProvider(chat.id)), isTrue);
    store.saveGate = null;
    store.saveStarted = null;
    saved.complete();
    await sending;
    await container.pump();
    expect(container.exists(chatDiaryControllerProvider(chat.id)), isFalse);
    expect(
      (await store.load(chat.id, setup.session))!.messages.last.status,
      ChatDiaryMessageStatus.complete,
    );
  });

  test('離頁後日記庫鎖定仍取消請求，晚到內容不會恢復聊天', () async {
    final stream = StreamController<String>();
    final started = Completer<void>();
    client.response = () {
      started.complete();
      return stream.stream;
    };
    controller.updateComposer('鎖定前的合成內容', []);
    final sending = controller.send();
    await started.future;
    subscription.close();
    await container.read(appSessionProvider.notifier).lock();
    expect(controller.chat, isNull);
    expect(client.closed, isTrue);
    stream.add('鎖定後的晚到內容');
    await stream.close();
    await sending;
    final stored = (await store.load(chat.id, setup.session))!;
    expect(stored.messages.last.status, ChatDiaryMessageStatus.interrupted);
    expect(stored.messages.last.text, isEmpty);
  });

  test('刪除執行中的回覆後，晚到內容不會重建草稿且請求完成取消', () async {
    final stream = StreamController<String>();
    final started = Completer<void>();
    client.response = () {
      started.complete();
      return stream.stream;
    };
    controller.updateComposer('刪除前的合成內容', []);
    final sending = controller.send();
    await started.future;
    subscription.close();
    await controller.delete(chat.id, setup.session);
    stream.add('不應留下的內容');
    await stream.close();
    await sending.timeout(const Duration(seconds: 3));
    expect(await store.load(chat.id, setup.session), isNull);
    expect(controller.chat, isNull);
  });

  test('離頁後生成完成仍保存日記草稿與來源，再釋放聊天', () async {
    controller.updateComposer('生成用的合成內容', []);
    await controller.send();
    final stream = StreamController<String>();
    final started = Completer<void>();
    client.response = () {
      started.complete();
      return stream.stream;
    };
    final generation = controller.generate(testZhL10n);
    await started.future;
    subscription.close();
    await container.pump();
    expect(container.exists(chatDiaryControllerProvider(chat.id)), isTrue);
    stream.add('# 合成日記\n\n保留這段內容');
    await stream.close();
    expect(await generation, ChatDiaryGenerationResult.generated);
    await container.pump();
    expect(container.exists(chatDiaryControllerProvider(chat.id)), isFalse);
    final stored = (await store.load(chat.id, setup.session))!;
    expect(stored.generatedEntryId, isNotNull);
    expect(stored.generatedFromMessageId, stored.activeMessages.last.id);
    expect(
      (await gatedDrafts.read(
        ChatDiarySession.draftKeyFor(chat.id),
        setup.session,
      ))!.markdownBody,
      '保留這段內容',
    );
  });

  test('不同聊天同時回覆時，各自保存與釋放且不會取消另一個請求', () async {
    final secondChat = testChatDiarySession(
      vaultId: setup.session.vaultId,
      hidePersonNames: false,
    )..composerText = '第二段合成內容';
    await store.save(secondChat, setup.session);
    final secondSubscription = container.listen(
      chatDiaryControllerProvider(secondChat.id),
      (_, _) {},
    );
    final second = container.read(chatDiaryControllerProvider(secondChat.id));
    await second.load(secondChat.id, setup.session);
    final secondClient = FakeAiClient(secondChat.connectionConfig);
    queuedClients.addAll([client, secondClient]);
    final firstStream = StreamController<String>();
    final secondStream = StreamController<String>();
    final firstStarted = Completer<void>();
    final secondStarted = Completer<void>();
    client.response = () {
      firstStarted.complete();
      return firstStream.stream;
    };
    secondClient.response = () {
      secondStarted.complete();
      return secondStream.stream;
    };
    controller.updateComposer('第一段合成內容', []);
    final firstSending = controller.send();
    await firstStarted.future;
    second.updateComposer('第二段合成內容', []);
    final secondSending = second.send();
    await secondStarted.future;
    subscription.close();
    secondSubscription.close();
    firstStream.add('第一個獨立回覆');
    await firstStream.close();
    await firstSending;
    await container.pump();
    expect(container.exists(chatDiaryControllerProvider(chat.id)), isFalse);
    expect(second.busy, isTrue);
    expect(secondClient.closed, isFalse);
    secondStream.add('第二個獨立回覆');
    await secondStream.close();
    await secondSending;
    await container.pump();
    expect(
      container.exists(chatDiaryControllerProvider(secondChat.id)),
      isFalse,
    );
    expect(
      (await store.load(chat.id, setup.session))!.messages.last.text,
      '第一個獨立回覆',
    );
    expect(
      (await store.load(secondChat.id, setup.session))!.messages.last.text,
      '第二個獨立回覆',
    );
  });

  test('空白聊天室只留在記憶體，鎖定與重新開啟不建立草稿檔', () async {
    final chatId = chat.id;
    expect((await store.draftDirectory(chatId)).existsSync(), isFalse);
    await controller.persist();
    expect((await store.draftDirectory(chatId)).existsSync(), isFalse);
    controller.lock();
    await store.flush();
    expect(
      await controller.start(chatId, setup.session, openingMessage: '開始聊天'),
      ChatDiaryLoadResult.loaded,
    );
    expect(controller.chat!.id, chatId);
    expect((await store.draftDirectory(chatId)).existsSync(), isFalse);
  });

  test('新聊天室載入中離開，晚到設定不建立草稿或恢復內容', () async {
    final reading = Completer<void>();
    settings.readGate = reading.future;
    final chatId = generateChatDiaryId();
    final loading = controller.start(
      chatId,
      setup.session,
      openingMessage: '開始聊天',
    );
    controller.stop();
    reading.complete();
    expect(await loading, ChatDiaryLoadResult.cancelled);
    expect(controller.chat, isNull);
    expect((await store.draftDirectory(chatId)).existsSync(), isFalse);
  });

  test('取消傳送預覽後，晚到設定不修改後續輸入或回傳舊預覽', () async {
    controller.updateComposer('預覽中的內容', []);
    final reading = Completer<void>();
    settings.readGate = reading.future;
    settings.readStarted = Completer<void>();
    final preview = controller.previewRequest();
    await settings.readStarted!.future;
    controller.stop();
    controller.updateComposer('後續的新內容', []);
    reading.complete();
    expect(await preview, isNull);
    expect(controller.chat!.composerText, '後續的新內容');
    expect(controller.error, isNull);
  });

  test('返回編輯器的載入已取消，晚到草稿結果不清除後續狀態', () async {
    final entryId = generateEntryId();
    controller.chat!.generatedEntryId = entryId;
    await controller.persist();
    final reading = Completer<void>();
    gatedDrafts.readGate = reading.future;
    gatedDrafts.readStarted = Completer<void>();
    final resuming = controller.resumeAfterEditor(chat.id, setup.session);
    await gatedDrafts.readStarted!.future;
    controller.stop();
    controller.updateComposer('後續輸入', []);
    reading.complete();
    expect(await resuming, ChatDiaryLoadResult.cancelled);
    expect(controller.chat!.generatedEntryId, entryId);
    expect(controller.chat!.composerText, '後續輸入');
  });

  for (final clearInput in [false, true]) {
    test('離頁時${clearInput ? '清除空白聊天檔案' : '立即保存尚未自動儲存的輸入'}', () async {
      controller.updateComposer('原本的輸入', []);
      await controller.persist();
      final latest = clearInput ? '  ' : '最後一刻的輸入';
      controller.updateComposer(latest, []);
      container.invalidate(chatDiaryControllerProvider(chat.id));
      await store.flush();
      if (clearInput) {
        expect((await store.draftDirectory(chat.id)).existsSync(), isFalse);
        expect(await store.list(setup.session), isEmpty);
      } else {
        expect(
          ((await store.load(chat.id, setup.session))!).composerText,
          latest,
        );
      }
    });
  }

  test('送出前隱藏人物與反白內容且原文只留在加密聊天', () async {
    await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '王小明'),
    );
    const text = '和王小明在秘密地址聊天，電話0912345678';
    final start = text.indexOf('秘密地址');
    controller.updateComposer(text, [PrivateTextRange(start, start + 4)]);
    await controller.send();
    final outgoing = client.calls.single.messages.single.text;
    expect(outgoing, isNot(contains('王小明')));
    expect(outgoing, isNot(contains('秘密地址')));
    expect(outgoing, contains('0912345678'));
    final stored = (await store.load(chat.id, setup.session))!;
    expect(stored.messages.first.text, text);
    final file = File(
      '${(await store.draftDirectory(chat.id)).path}/session.json.enc',
    );
    expect(
      utf8.decode(await file.readAsBytes(), allowMalformed: true),
      isNot(contains('秘密地址')),
    );
  });
  test('已送出的訊息不因後來新增人物而改寫', () async {
    controller.updateComposer('小華先出現', []);
    await controller.send();
    expect(client.calls.single.messages.single.text, '小華先出現');
    await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小華'),
    );
    controller.updateComposer('後來才認識小華', []);
    await controller.send();
    expect(client.calls.last.messages.first.text, '小華先出現');
    expect(controller.chat!.messages.first.personRanges, isEmpty);
    expect(client.calls.last.messages.last.text, isNot(contains('小華')));
  });
  test('下一次請求使用新語系與完整自訂提示詞', () async {
    controller.updateComposer('第一則', []);
    await controller.send();
    expect(client.calls.last.prompt, contains('預設使用繁體中文'));
    await preferences.setAppLocale(AppLanguage.en);
    controller.updateComposer('第二則', []);
    await controller.send();
    expect(
      client.calls.last.prompt,
      contains('By default use natural English'),
    );
    settings.chatDiaryPrompts = const AiPromptOverrides(
      conversationOverride: '只有這一段自訂提示詞',
    );
    controller.updateComposer('第三則', []);
    await controller.send();
    expect(client.calls.last.prompt, '只有這一段自訂提示詞');
  });
  test('反白只隱藏標記區間，較早訊息保留原文，提示詞仍隱藏同一段', () async {
    settings.chatDiaryPrompts = const AiPromptOverrides(
      conversationOverride: '我的住址是秘密地址',
      generationOverride: '整理秘密地址的故事',
    );
    controller.updateComposer('先前提過秘密地址', []);
    await controller.send();
    controller.updateComposer('秘密地址再提一次秘密地址', [const PrivateTextRange(0, 4)]);
    final beforeSend = (await controller.previewRequest())!;
    final pendingTurns = beforeSend.turns.where((turn) => turn.isUser).toList();
    expect(pendingTurns.first.text, '先前提過秘密地址');
    expect(pendingTurns.last.text, '⟦S01⟧再提一次秘密地址');
    expect(beforeSend.systemPrompt, isNot(contains('秘密地址')));
    await controller.send();
    final sent = client.calls.last.messages;
    expect(sent.first.text, '先前提過秘密地址');
    expect(sent.last.text, '⟦S01⟧再提一次秘密地址');
    expect(client.calls.last.prompt, isNot(contains('秘密地址')));
    final preview = (await controller.previewRequest())!;
    final userTurns = preview.turns.where((turn) => turn.isUser).toList();
    expect(userTurns.first.text, '先前提過秘密地址');
    expect(userTurns.last.text, '⟦S01⟧再提一次秘密地址');
    expect(preview.systemPrompt, isNot(contains('秘密地址')));
    client.output = '# 記錄\n\n一段回憶';
    await controller.generate(testZhL10n);
    expect(client.calls.last.prompt, isNot(contains('秘密地址')));
  });
  test('已送出訊息只依反白區間重算，不沿用多替換的外送文字', () async {
    const original = '秘密 再提一次秘密';
    chat.tokenBySourceKey['private:秘密'] = '⟦S01⟧';
    chat.originalTextByToken['⟦S01⟧'] = '秘密';
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: original,
        outboundText: '⟦S01⟧ 再提一次⟦S01⟧',
        privateRanges: [const PrivateTextRange(0, 2)],
        privateTokenIds: {'⟦S01⟧'},
      ),
    );
    final preview = (await controller.previewRequest())!;
    expect(preview.turns.single.text, '⟦S01⟧ 再提一次秘密');
    expect(chat.messages.single.outboundText, '⟦S01⟧ 再提一次秘密');
    controller.updateComposer('下一則', []);
    await controller.send();
    expect(client.calls.last.messages.first.text, '⟦S01⟧ 再提一次秘密');
  });
  test('預覽後未送出的私密文字不進入日記補記', () async {
    controller.updateComposer('已經說過的事情', []);
    await controller.send();
    controller.updateComposer('不能加入的私密文字', [const PrivateTextRange(0, 9)]);
    await controller.previewRequest();
    client.output = '# 日記\n\n已經說過的事情';
    await controller.generate(testZhL10n);
    final draft = await container
        .read(editorDraftStoreProvider)
        .read(ChatDiarySession.draftKeyFor(chat.id), setup.session);
    expect(draft!.markdownBody, isNot(contains('不能加入')));
    expect(draft.markdownBody, isNot(contains('私密補記')));
  });

  test('生成預覽與實際提示詞、對話 JSON 及圖片相同，不含待送內容', () async {
    settings.chatDiaryPrompts = const AiPromptOverrides(
      conversationOverride: '需求對話提示詞',
      generationOverride: '生成提示詞與秘密',
    );
    await controller.addImage(testAiPng);
    final sentImage = chat.pendingImageIds.single;
    controller.updateComposer('秘密與散步', [const PrivateTextRange(0, 2)]);
    await controller.send();
    await controller.addImage(testAiPng);
    final unsentImage = chat.pendingImageIds.single;
    controller.updateComposer('未送出的私密內容', [const PrivateTextRange(0, 3)]);
    final conversation = (await controller.previewRequest())!;
    expect(conversation.turns.last.pending, isTrue);
    final generation = (await controller.previewRequest(generate: true))!;
    expect(generation.systemPrompt, '生成提示詞與⟦S01⟧');
    expect(generation.turns.single.pending, isFalse);
    expect(generation.turns.single.imageIds, [sentImage]);
    expect(generation.turns.single.text, isNot(contains('未送出')));
    expect(generation.turns.single.text, isNot(contains('秘密')));
    client.output = '# 記錄\n\n今天去散步。';
    await controller.generate(testZhL10n);
    expect(client.calls.last.prompt, generation.systemPrompt);
    expect(
      client.calls.last.messages.single.text,
      generation.turns.single.text,
    );
    expect(client.calls.last.messages.single.images.map((image) => image.id), [
      sentImage,
    ]);
    expect(chat.pendingImageIds, [unsentImage]);
  });
  test('API Key 替換於下一次請求使用，進行中的提示詞維持快照', () async {
    final started = Completer<void>();
    final finish = Completer<void>();
    settings.keys[chat.connectionConfig.credentialId] = 'first-key';
    settings.chatDiaryPrompts = const AiPromptOverrides(
      conversationOverride: '原始完整提示詞',
    );
    client.response = () async* {
      started.complete();
      yield '部分';
      await finish.future;
      yield '回覆';
    };
    controller.updateComposer('開始記錄', []);
    final sending = controller.send();
    await started.future;
    settings.keys[chat.connectionConfig.credentialId] = 'rotated-key';
    settings.settings = const AiConnectionSettings(
      activeConnectionId: 'openai',
    );
    settings.chatDiaryPrompts = const AiPromptOverrides(
      conversationOverride: '更新後完整提示詞',
    );
    finish.complete();
    await sending;
    expect(client.calls.single.prompt, '原始完整提示詞');
    client.response = null;
    controller.updateComposer('再補一段', []);
    await controller.send();
    expect(clientKeys, ['first-key', 'rotated-key']);
    expect(client.calls.last.prompt, '更新後完整提示詞');
    expect(
      controller.chat!.connectionConfig.protocol,
      AiApiProtocol.ollamaChat,
    );
  });
  test('已送出的圖片自動交接到獨立編輯草稿並加入私密補記', () async {
    await controller.addImage(testAiPng);
    controller.updateComposer('今天去了秘密地點', [const PrivateTextRange(4, 8)]);
    await controller.send();
    expect(client.calls.single.messages.single.images, hasLength(1));
    expect(client.calls.single.messages.single.images.single.bytes, testAiPng);
    client.output = '# 今天的小事\n\n今天留下了一段回憶。';
    expect(
      await controller.generate(testZhL10n),
      ChatDiaryGenerationResult.generated,
    );
    final draftStore = container.read(editorDraftStoreProvider);
    final draft = await draftStore.read(
      ChatDiarySession.draftKeyFor(chat.id),
      setup.session,
    );
    expect(draft!.title, '今天的小事');
    expect(draft.attachmentIds, hasLength(1));
    expect(draft.markdownBody, contains('私密補記'));
    expect(draft.markdownBody, contains('秘密地點'));
    final path = await draftStore.materializePendingFileForPreview(
      ChatDiarySession.draftKeyFor(chat.id),
      draft.pendingAttachments.single.relativePath,
      setup.session,
    );
    expect(await File(path).readAsBytes(), testAiPng);
    expect(await draftStore.read('__new__', setup.session), isNull);
  });
  test('空白生成保留人工草稿、附件與生成快照，仍可接續聊天', () async {
    await controller.addImage(testAiPng);
    controller.updateComposer('今天去了秘密地點', [const PrivateTextRange(4, 8)]);
    await controller.send();
    client.output = '# 原草稿\n\n想保留的內容';
    expect(
      await controller.generate(testZhL10n),
      ChatDiaryGenerationResult.generated,
    );
    await controller.resumeAfterEditor(chat.id, setup.session);
    final key = ChatDiarySession.draftKeyFor(chat.id);
    final previous = (await gatedDrafts.read(key, setup.session))!;
    final edited = EditorDraftRecord.fromJson({
      ...previous.toJson(),
      'markdown_body': '人工修改的內容',
    });
    await gatedDrafts.write(key, edited, setup.session);
    final signature = controller.chat!.generatedDraftSignature;
    final source = controller.chat!.generatedFromMessageId;
    final prompt = controller.chat!.generationPromptSnapshot;
    for (final output in ['', ' \n\t ']) {
      client.output = output;
      expect(
        await controller.generate(testZhL10n),
        ChatDiaryGenerationResult.empty,
      );
      expect(
        (await gatedDrafts.read(key, setup.session))!.toJson(),
        edited.toJson(),
      );
      expect(controller.chat!.generatedDraftSignature, signature);
      expect(controller.chat!.generatedFromMessageId, source);
      expect(controller.chat!.generationPromptSnapshot, prompt);
      expect(controller.error, isNull);
      expect(controller.unexpectedError, isFalse);
      expect(controller.busy, isFalse);
      expect(controller.canGenerate, isTrue);
    }
    controller.updateComposer('繼續補充', []);
    client.output = '接著聊';
    await controller.send();
    expect(controller.chat!.activeMessages.last.text, '接著聊');
  });

  for (final example in [
    (name: '生活段落', body: '昨天去了酒精路跑，超好笑的。'),
    (name: '純待辦', body: '明天要記得：\n\n- [ ] 買鉛筆\n- [ ] 買雨衣\n- [ ] 領日幣'),
    (name: '待辦與願望', body: '- [ ] 買雨衣\n\n希望這個月能把日文五十音背完。'),
  ]) {
    test('生成${example.name}時保留 Markdown 並交接標題與內文', () async {
      controller.updateComposer(example.body, []);
      await controller.send();
      client.output = '# 最近的紀錄\n\n${example.body}';
      expect(
        await controller.generate(testZhL10n),
        ChatDiaryGenerationResult.generated,
      );
      final draft = (await gatedDrafts.read(
        ChatDiarySession.draftKeyFor(chat.id),
        setup.session,
      ))!;
      expect(draft.title, '最近的紀錄');
      expect(draft.markdownBody, example.body);
      final history =
          jsonDecode(client.calls.last.messages.single.text) as List;
      expect(history.map((message) => message['role']), ['user', 'assistant']);
      expect(history.first['text'], example.body);
      expect(history.last['text'], '回覆');
    });
  }

  test('思考強度改變後重建客戶端，舊回覆保留原設定', () async {
    controller.updateComposer('第一段', []);
    await controller.send();
    final original = controller.chat!.activeMessages.last;
    final before = controller.chat!.connectionConfig;
    controller.chat!.connectionConfig = setThinkingLevel(
      before,
      before.model,
      AiThinkingLevel.high,
    );
    controller.updateComposer('第二段', []);
    await controller.send();
    expect(clientConfigs, hasLength(2));
    expect(resolvedThinkingLevel(clientConfigs.first), AiThinkingLevel.off);
    expect(resolvedThinkingLevel(clientConfigs.last), AiThinkingLevel.high);
    expect(original.connectionSnapshot!.thinkingLevels, isEmpty);
    expect(
      controller.chat!.activeMessages.last.connectionSnapshot!.thinkingLevels,
      {before.model: AiThinkingLevel.high},
    );
  });

  test('同網址同模型切換帳號會更換金鑰與連線，舊回覆保留原帳號', () async {
    final a = chat.connectionConfig.copyWith(
      customConnectionId: 'aic_a',
      displayName: '工作',
      addedModels: [chat.connectionConfig.model],
      enabledModels: [chat.connectionConfig.model],
    );
    final b = a.copyWith(customConnectionId: 'aic_b', displayName: '個人');
    settings.settings = AiConnectionSettings(
      activeConnectionId: a.connectionId,
      connections: {a.connectionId: a, b.connectionId: b},
    );
    settings.keys[a.credentialId] = 'key-a';
    settings.keys[b.credentialId] = 'key-b';
    await controller.applySettings(a, false);
    controller.updateComposer('第一組帳號', []);
    await controller.send();
    final original = controller.chat!.activeMessages.last;
    await controller.selectModel(ChatModelOption(connectionConfig: b));
    controller.updateComposer('第二組帳號', []);
    await controller.send();
    expect(clientKeys, ['key-a', 'key-b']);
    expect(clientConfigs.map((c) => c.connectionId), ['aic_a', 'aic_b']);
    expect(original.connectionSnapshot!.connectionId, a.connectionId);
    expect(
      controller.chat!.activeMessages.last.connectionSnapshot!.connectionId,
      b.connectionId,
    );
    expect(settings.settings.activeConnectionId, b.connectionId);
  });

  test('模型選擇等候設定時取消，不套用晚到連線或更新預設', () async {
    final original = controller.chat!.connectionConfig;
    final next = addModel(
      original.copyWith(customConnectionId: 'aic_other', displayName: '另一組'),
      original.model,
    );
    settings.settings = AiConnectionSettings(
      activeConnectionId: original.connectionId,
      connections: {original.connectionId: original, next.connectionId: next},
    );
    final reading = Completer<void>();
    settings.readGate = reading.future;
    settings.readStarted = Completer<void>();
    final selecting = controller.selectModel(
      ChatModelOption(connectionConfig: next),
    );
    await settings.readStarted!.future;
    controller.stop();
    reading.complete();
    await selecting;
    expect(
      controller.chat!.connectionConfig.connectionId,
      original.connectionId,
    );
    expect(settings.settings.activeConnectionId, original.connectionId);
  });

  test('相同強度更改 Thinking 參數會重建，只有 JSON 鍵順序不同不重建', () async {
    controller.updateComposer('原設定', []);
    await controller.send();
    final original = controller.chat!.activeMessages.last;
    final config = controller.chat!.connectionConfig;
    AiConnectionConfig withFields(Map<String, Object?> fields) =>
        config.copyWith(
          thinkingOverrides: {
            config.model: AiModelThinkingOverride(
              defaultLevel: AiThinkingLevel.off,
              levels: {AiThinkingLevel.off: fields},
            ),
          },
        );
    await controller.applySettings(
      withFields({
        'think': false,
        'custom': {'budget': 1024},
      }),
      false,
    );
    controller.updateComposer('自訂設定', []);
    await controller.send();
    expect(clientConfigs, hasLength(2));
    expect(original.connectionSnapshot!.thinkingOverrides, isEmpty);
    await controller.applySettings(
      withFields({
        'custom': {'budget': 1024},
        'think': false,
      }),
      false,
    );
    controller.updateComposer('相同參數', []);
    await controller.send();
    expect(clientConfigs, hasLength(2));
  });

  test('多輪上下文重複圖片不讓日記重複附圖', () async {
    await controller.addImage(testAiPng);
    controller.updateComposer('第一張照片', []);
    await controller.send();
    controller.updateComposer('補充說明', []);
    await controller.send();
    client.output = '沒有標題的自訂格式日記';
    expect(
      await controller.generate(testZhL10n),
      ChatDiaryGenerationResult.generated,
    );
    final draft = await container
        .read(editorDraftStoreProvider)
        .read(ChatDiarySession.draftKeyFor(chat.id), setup.session);
    expect(draft!.title, isNull);
    expect(draft.markdownBody, '沒有標題的自訂格式日記');
    expect(draft.attachmentIds, hasLength(1));
  });
  test('聊天保存失敗時不連線，復原後可重試且不重複使用者訊息', () async {
    store.failSaves = true;
    controller.updateComposer('不能遺失的內容', []);
    await controller.send();
    expect(client.calls, isEmpty);
    expect(controller.error, AiErrorCode.storage);
    expect(controller.chat!.messages.first.text, '不能遺失的內容');
    store.failSaves = false;
    await controller.regenerateReply(controller.chat!.activeMessages.last.id);
    expect(client.calls.single.messages.single.text, '不能遺失的內容');
    expect(
      ((await store.load(
        chat.id,
        setup.session,
      ))!).messages.where((m) => m.isUser),
      hasLength(1),
    );
  });
  test('去除中繼資料的副本送給模型，正式日記保存原圖且不依賴聊天附件', () async {
    final original = pngWithPrivateMetadata();
    await controller.addImage(original);
    controller.updateComposer('照片', []);
    await controller.send();
    expect(client.calls.single.messages.single.images.single.bytes, testAiPng);
    client.output = '# 照片\n\n留下一張照片';
    await controller.generate(testZhL10n);
    final draftStore = container.read(editorDraftStoreProvider);
    final draft = await draftStore.read(
      ChatDiarySession.draftKeyFor(chat.id),
      setup.session,
    );
    final path = await draftStore.materializePendingFileForPreview(
      ChatDiarySession.draftKeyFor(chat.id),
      draft!.pendingAttachments.single.relativePath,
      setup.session,
    );
    expect(await File(path).readAsBytes(), original);
    final flow = container.read(editorFlowControllerProvider);
    final restored = await flow.restoreDraftIfNeeded(
      draftKey: ChatDiarySession.draftKeyFor(chat.id),
      session: setup.session,
      existingEntry: null,
      decideRestore: (_) async => true,
    );
    final saved = (await flow.saveEntry(
      EditorSaveRequest(
        draftKey: ChatDiarySession.draftKeyFor(chat.id),
        session: setup.session,
        existingEntry: null,
        titleRaw: draft.title ?? '',
        dateValue: draft.dateValue,
        entryTime: (hour: 12, minute: 0),
        tagsRaw: '',
        markdownBodyRaw: draft.markdownBody,
        attachmentIds: draft.attachmentIds,
        pendingAttachments: restored.pendingAttachments,
        provisionalEntryId: draft.provisionalEntryId,
        switchToPreview: true,
      ),
    )).savedEntry;
    await store.complete(chat.id, saved.id, setup.session);
    final attachments = await harness.repository.loadAttachments(saved.id);
    final encryptedPath = await flow.assetEncryptedPath(
      savedAttachmentDateValue: saved.date.value,
      attachment: attachments.single,
    );
    expect(
      await harness.repository.readDecryptedAssetBytes(
        setup.session,
        encryptedPath,
      ),
      original,
    );
    await store.delete(chat.id, session: setup.session, entryId: saved.id);
    expect(
      await harness.repository.loadEntry(setup.session, saved.id),
      isNotNull,
    );
    expect(
      await harness.repository.readDecryptedAssetBytes(
        setup.session,
        encryptedPath,
      ),
      original,
    );
    expect((await store.draftDirectory(chat.id)).existsSync(), isFalse);
  });
  test('取消附圖後晚到的儲存不會加入圖片或解除新請求的忙碌狀態', () async {
    final imageGate = Completer<void>();
    store.imageStarted = Completer<void>();
    store.imageGate = imageGate.future;
    final adding = controller.addImage(testAiPng);
    await store.imageStarted!.future;
    controller.stop();
    final stream = StreamController<String>();
    final replying = Completer<void>();
    client.response = () {
      replying.complete();
      return stream.stream;
    };
    controller.updateComposer('新的請求', []);
    final sending = controller.send();
    await replying.future;
    imageGate.complete();
    await adding;
    expect(controller.chat!.images, isEmpty);
    expect(controller.chat!.pendingImageIds, isEmpty);
    final imageDirectory = Directory(
      '${(await store.draftDirectory(chat.id)).path}/images',
    );
    expect(imageDirectory.existsSync(), isFalse);
    expect(controller.busy, isTrue);
    stream.add('新的回覆');
    await stream.close();
    await sending;
  });

  test('取消生成中的草稿提交後，新生成依序寫入且舊結果不會交接', () async {
    controller.updateComposer('今天的片段', []);
    await controller.send();
    final gate = Completer<void>();
    gatedDrafts.writeStarted = Completer<void>();
    gatedDrafts.writeGate = gate.future;
    client.output = '# 舊結果\n\n已取消的內容';
    final oldGeneration = controller.generate(testZhL10n);
    await gatedDrafts.writeStarted!.future;
    controller.stop();
    gatedDrafts.writeStarted = null;
    gatedDrafts.writeGate = null;
    client.output = '# 新結果\n\n新生成的內容';
    final newGeneration = controller.generate(testZhL10n);
    gate.complete();
    expect(await oldGeneration, ChatDiaryGenerationResult.notGenerated);
    expect(await newGeneration, ChatDiaryGenerationResult.generated);
    final record = await gatedDrafts.read(
      ChatDiarySession.draftKeyFor(chat.id),
      setup.session,
    );
    expect(record!.title, '新結果');
    expect(record.markdownBody, '新生成的內容');
  });

  test('取消生成且未再次生成時保留原草稿、附件及內容指紋', () async {
    await controller.addImage(testAiPng);
    controller.updateComposer('有照片的片段', []);
    await controller.send();
    client.output = '# 原草稿\n\n需要保留的內容';
    expect(
      await controller.generate(testZhL10n),
      ChatDiaryGenerationResult.generated,
    );
    await controller.resumeAfterEditor(chat.id, setup.session);
    final key = ChatDiarySession.draftKeyFor(chat.id);
    final previous = (await gatedDrafts.read(key, setup.session))!;
    final edited = EditorDraftRecord.fromJson({
      ...previous.toJson(),
      'markdown_body': '已經手動修改的內容',
    });
    await gatedDrafts.write(key, edited, setup.session);
    final signature = controller.chat!.generatedDraftSignature;
    final pending = await harness.pathStrategy.editorDraftPendingDirectory(key);
    final files = pending.listSync().map((file) => file.path).toSet();
    final gate = Completer<void>();
    gatedDrafts.writeStarted = Completer<void>();
    gatedDrafts.writeGate = gate.future;
    client.output = '# 取消的生成\n\n不能覆寫';
    final generation = controller.generate(testZhL10n);
    await gatedDrafts.writeStarted!.future;
    controller.stop();
    gate.complete();
    expect(await generation, ChatDiaryGenerationResult.notGenerated);
    await store.flush();
    expect(
      (await gatedDrafts.read(key, setup.session))!.toJson(),
      edited.toJson(),
    );
    expect(pending.listSync().map((file) => file.path).toSet(), files);
    expect(controller.chat!.generatedDraftSignature, signature);
    expect(
      (await store.load(chat.id, setup.session))!.generatedDraftSignature,
      signature,
    );
    final editor = await harness.pathStrategy.editorDraftDirectory(key);
    expect(
      editor.listSync().where(
        (file) => file.path.endsWith('.tmp') || file.path.endsWith('.previous'),
      ),
      isEmpty,
    );
  });

  test('生成逐張交接圖片，後續圖片遺失時清除本次暫存並保留原草稿', () async {
    await controller.addImage(testAiPng);
    await controller.addImage(testAiPng);
    final secondImage = controller.chat!.pendingImageIds.last;
    controller.updateComposer('兩張照片', []);
    await controller.send();
    expect(
      await controller.generate(testZhL10n),
      ChatDiaryGenerationResult.generated,
    );
    await controller.resumeAfterEditor(chat.id, setup.session);
    final key = ChatDiarySession.draftKeyFor(chat.id);
    final previous = (await gatedDrafts.read(key, setup.session))!;
    final pending = await harness.pathStrategy.editorDraftPendingDirectory(key);
    final files = pending.listSync().map((file) => file.path).toSet();
    final gate = Completer<void>();
    gatedDrafts.stageStarted = Completer<void>();
    gatedDrafts.stageGate = gate.future;
    client.output = '# 新日記\n\n不能取代原草稿';
    final generation = controller.generate(testZhL10n);
    await gatedDrafts.stageStarted!.future;
    await File(
      '${(await store.draftDirectory(chat.id)).path}/images/$secondImage.enc',
    ).delete();
    gatedDrafts.stageStarted = null;
    gatedDrafts.stageGate = null;
    gate.complete();
    expect(await generation, ChatDiaryGenerationResult.notGenerated);
    expect(controller.error, AiErrorCode.image);
    expect(
      (await gatedDrafts.read(key, setup.session))!.toJson(),
      previous.toJson(),
    );
    expect(pending.listSync().map((file) => file.path).toSet(), files);
  });

  test('取消訊息編輯只移除新附圖，保留原訊息與未送出附件', () async {
    await controller.addImage(testAiPng);
    final originalImage = controller.chat!.pendingImageIds.single;
    controller.updateComposer('原訊息', []);
    await controller.send();
    final user = controller.chat!.activeMessages.first;
    await controller.addImage(testAiPng);
    final unsentImage = controller.chat!.pendingImageIds.single;
    controller.beginEditing(user.id);
    await controller.addImage(testAiPng);
    final addedImage = controller.chat!.pendingImageIds.last;
    final images = Directory(
      '${(await store.draftDirectory(chat.id)).path}/images',
    );
    final addedFile = File('${images.path}/$addedImage.enc');
    await addedFile.copy('${addedFile.path}.previous');
    await addedFile.copy('${addedFile.path}.tmp');
    controller.cancelEditing();
    await store.flush();
    expect(controller.chat!.pendingImageIds, [unsentImage]);
    expect(controller.chat!.images.map((image) => image.id), [
      originalImage,
      unsentImage,
    ]);
    expect(
      images.listSync().map((file) => file.uri.pathSegments.last).toSet(),
      {'$originalImage.enc', '$unsentImage.enc'},
    );
    expect(
      (await store.load(
        chat.id,
        setup.session,
      ))!.images.map((image) => image.id),
      [originalImage, unsentImage],
    );
  });

  test('刪除失敗保留聊天與輸入，重試成功後才清空狀態', () async {
    controller.updateComposer('不能遺失的輸入', []);
    store.failDeletes = true;
    await expectLater(
      controller.delete(chat.id, setup.session),
      throwsStateError,
    );
    expect(controller.chat!.composerText, '不能遺失的輸入');
    expect(controller.canSend, isTrue);
    expect(controller.busy, isFalse);
    store.failDeletes = false;
    await controller.delete(chat.id, setup.session);
    expect(controller.chat, isNull);
    expect(await store.list(setup.session), isEmpty);
  });

  test('鎖定後晚到的串流不能恢復敏感畫面或變成完整回覆', () async {
    final stream = StreamController<String>();
    client.response = () => stream.stream;
    controller.updateComposer('私人內容', []);
    final sending = controller.send();
    while (client.calls.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    stream.add('部分回覆');
    await Future<void>.delayed(Duration.zero);
    controller.lock();
    stream.add('不該出現');
    await stream.close();
    await sending;
    expect(controller.chat, isNull);
    expect(client.closed, isTrue);
    final stored = (await store.load(chat.id, setup.session))!;
    expect(stored.messages.last.status, ChatDiaryMessageStatus.interrupted);
    expect(stored.messages.last.text, isNot(contains('不該出現')));
  });
  test('歡迎訊息只保存於本機，續聊不重加且不進入聊天或生成請求', () async {
    await controller.start(
      chat.id,
      setup.session,
      openingMessage: testZhL10n.chatDiaryWelcomeMessage,
    );
    expect(client.calls, isEmpty);
    expect((await store.draftDirectory(chat.id)).existsSync(), isFalse);
    controller.updateComposer('真的想記住的事情', []);
    await controller.send();
    expect(client.calls.single.messages.single.text, '真的想記住的事情');
    await controller.load(chat.id, setup.session, openingMessage: '另一種語言的開場');
    expect(controller.chat!.openingMessage, testZhL10n.chatDiaryWelcomeMessage);
    client.output = '# 記錄\n\n真的想記住的事情';
    await controller.generate(testZhL10n);
    expect(
      client.calls.last.messages.single.text,
      isNot(contains(testZhL10n.chatDiaryWelcomeMessage)),
    );
    expect(await controller.hasEditedDiaryDraft(), isFalse);
    final draftStore = container.read(editorDraftStoreProvider);
    final key = ChatDiarySession.draftKeyFor(chat.id);
    final record = (await draftStore.read(key, setup.session))!;
    await draftStore.write(
      key,
      EditorDraftRecord.fromJson({
        ...record.toJson(),
        'markdown_body': '人工修改的內文',
      }),
      setup.session,
    );
    expect(await controller.hasEditedDiaryDraft(), isTrue);
  });

  test('移除尚未被引用的待送圖片時刪除紀錄與檔案', () async {
    controller.updateComposer('留下這段文字', []);
    await controller.addImage(testAiPng);
    final id = controller.chat!.pendingImageIds.single;
    final directory = await store.draftDirectory(chat.id);
    final file = File(
      '${directory.path}${Platform.pathSeparator}images${Platform.pathSeparator}$id.enc',
    );
    expect(file.existsSync(), isTrue);
    controller.removePendingImage(id);
    await store.flush();
    expect(controller.chat!.pendingImageIds, isEmpty);
    expect(controller.chat!.images, isEmpty);
    expect(file.existsSync(), isFalse);
    expect(directory.existsSync(), isTrue);
  });

  test('編輯重送保留未送輸入，分支之外的文字圖片與私密補記不進入生成', () async {
    await controller.addImage(testAiPng);
    final oldImage = controller.chat!.pendingImageIds.single;
    controller.updateComposer('舊分支的秘密地點', [const PrivateTextRange(0, 8)]);
    await controller.send();
    final oldUser = controller.chat!.activeMessages.first;
    final oldToken = oldUser.privateTokenIds.single;
    controller.updateComposer('舊分支的後續', []);
    await controller.send();
    final oldLeaf = controller.chat!.activeMessages.last.id;
    await controller.addImage(testAiPng);
    final unsentImage = controller.chat!.pendingImageIds.single;
    controller.updateComposer('還沒送出的文字', [const PrivateTextRange(0, 7)]);
    controller.beginEditing(oldUser.id);
    expect(controller.chat!.composerRanges.single.end, 8);
    expect(controller.chat!.pendingImageIds, [oldImage]);
    await controller.persist();
    await controller.load(chat.id, setup.session);
    expect(controller.chat!.editingMessageId, oldUser.id);
    expect(controller.chat!.editBackup!.text, '還沒送出的文字');
    controller.cancelEditing();
    expect(controller.chat!.composerText, '還沒送出的文字');
    expect(controller.chat!.pendingImageIds, [unsentImage]);
    controller.beginEditing(oldUser.id);
    controller.removePendingImage(oldImage);
    expect(
      controller.chat!.images.map((image) => image.id),
      contains(oldImage),
    );
    await controller.addImage(testAiPng);
    final newImage = controller.chat!.pendingImageIds.single;
    controller.updateComposer('新分支私密', [const PrivateTextRange(0, 5)]);
    await controller.send();
    expect(controller.chat!.messages, hasLength(6));
    expect(controller.chat!.activeMessages, hasLength(2));
    expect(controller.chat!.composerText, '還沒送出的文字');
    expect(controller.chat!.pendingImageIds, [unsentImage]);
    expect(client.calls.last.messages.single.text, isNot(contains(oldToken)));
    expect(client.calls.last.messages.single.images.single.id, newImage);
    expect(
      (await controller.previewRequest())!.turns
          .map((turn) => turn.text)
          .join(),
      isNot(contains('舊分支')),
    );
    client.output = '# 分支日記\n\n一段記錄';
    await controller.generate(testZhL10n);
    final key = ChatDiarySession.draftKeyFor(chat.id);
    var draft = await container
        .read(editorDraftStoreProvider)
        .read(key, setup.session);
    expect(draft!.markdownBody, contains('新分支私密'));
    expect(draft.markdownBody, isNot(contains('舊分支')));
    expect(draft.markdownBody, isNot(contains('還沒送出')));
    expect(draft.attachmentIds, [newImage]);
    await controller.load(chat.id, setup.session);
    expect(controller.chat!.isDraftOutdated, isFalse);
    final calls = client.calls.length;
    controller.selectVersion(oldUser.id);
    expect(client.calls.length, calls);
    expect(controller.chat!.activeMessages.last.id, oldLeaf);
    expect(controller.chat!.isDraftOutdated, isTrue);
    await controller.generate(testZhL10n);
    draft = await container
        .read(editorDraftStoreProvider)
        .read(key, setup.session);
    expect(draft!.attachmentIds, [oldImage]);
    expect(draft.markdownBody, contains('舊分支的秘密地點'));
    expect(draft.markdownBody, isNot(contains('新分支私密')));
  });

  test('成功失敗及中斷回覆皆保留版本，串流與編輯期間不切換分支', () async {
    controller.updateComposer('第一則', []);
    await controller.send();
    final original = controller.chat!.activeMessages.last;
    client.response = () => Stream.error(const AiFailure(AiErrorCode.network));
    await controller.regenerateReply(original.id);
    final failed = controller.chat!.activeMessages.last;
    expect(failed.status, ChatDiaryMessageStatus.failed);
    expect(failed.errorCode, 'network');
    expect(original.status, ChatDiaryMessageStatus.complete);
    final stream = StreamController<String>();
    client.response = () => stream.stream;
    final sending = controller.regenerateReply(failed.id);
    while (client.calls.length < 3) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final current = controller.chat!.activeMessages.last;
    controller.selectVersion(original.id);
    expect(controller.chat!.activeMessages.last, current);
    controller.stop();
    await stream.close();
    await sending;
    expect(current.status, ChatDiaryMessageStatus.interrupted);
    client.response = null;
    await controller.regenerateReply(current.id);
    expect(
      controller.chat!.messageVersions[(current.parentId, current.isUser)],
      hasLength(4),
    );
    final user = controller.chat!.activeMessages.first;
    controller.beginEditing(user.id);
    controller.selectVersion(original.id);
    expect(controller.chat!.activeMessages.last.id, isNot(original.id));
    controller.cancelEditing();
    controller.selectVersion(original.id);
    expect(controller.chat!.activeMessages.last, original);
  });

  test('生成失敗不會被先前相同原因的回覆錯誤遮掉', () async {
    client.failure = const AiFailure(AiErrorCode.network);
    controller.updateComposer('可以生成的片段', []);
    await controller.send();
    expect(controller.errorMessageId, controller.chat!.activeMessages.last.id);
    expect(
      await controller.generate(testZhL10n),
      ChatDiaryGenerationResult.notGenerated,
    );
    expect(controller.error, AiErrorCode.network);
    expect(controller.errorMessageId, isNull);
  });

  test('送出遇到未知錯誤時不標成回應不完整', () async {
    client.response = () => throw StateError('未知');
    controller.updateComposer('一段話', []);
    await controller.send();
    final failed = controller.chat!.activeMessages.last;
    expect(failed.status, ChatDiaryMessageStatus.failed);
    expect(failed.errorCode, isNull);
    expect(controller.unexpectedError, isTrue);
    expect(controller.error, isNull);
  });

  test('生成遇到未知錯誤時不標成儲存失敗', () async {
    controller.updateComposer('一段話', []);
    await controller.send();
    client.response = () => throw StateError('未知');
    expect(
      await controller.generate(testZhL10n),
      ChatDiaryGenerationResult.notGenerated,
    );
    expect(controller.error, isNull);
    expect(controller.unexpectedError, isTrue);
  });

  test('串流途中套用設定會停止舊請求，晚到的內容不能改寫回覆', () async {
    final stream = StreamController<String>();
    client.response = () => stream.stream;
    controller.updateComposer('合成片段', []);
    final sending = controller.send();
    while (client.calls.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final oldConfig = controller.chat!.connectionConfig;
    const newConfig = AiConnectionConfig(
      provider: AiProvider.custom,
      model: 'new-model',
      baseUrl: 'https://new.example/v1',
    );
    await controller.applySettings(newConfig, false);
    stream.add('不能追加的舊回覆');
    await stream.close();
    await sending;
    final message = controller.chat!.activeMessages.last;
    expect(message.status, ChatDiaryMessageStatus.interrupted);
    expect(message.text, isNot(contains('不能追加')));
    expect(message.connectionSnapshot!.toJson(), oldConfig.toJson());
    expect(controller.chat!.connectionConfig.model, 'new-model');
    expect(client.calls, hasLength(1));
  });

  test('聊天室改模型後，下一則新聊天沿用剛選的模型', () async {
    settings.settings = AiConnectionSettings(
      activeConnectionId: 'custom',
      connections: {
        'custom': addModel(
          settings.settings.connectionFor('custom'),
          'other-model',
        ),
      },
    );
    controller.updateComposer('第一段合成內容', []);
    await controller.send();
    await controller.selectModel(
      ChatModelOption(
        connectionConfig: settings.settings
            .connectionFor('custom')
            .copyWith(model: 'other-model'),
      ),
    );
    expect(controller.chat!.connectionConfig.model, 'other-model');
    expect(settings.settings.activeConfig.provider, AiProvider.custom);
    expect(settings.settings.activeConfig.model, 'other-model');
    controller.updateComposer('第二段合成內容', []);
    await controller.send();
    expect(clientConfigs, hasLength(2));
    expect(clientConfigs.last.model, 'other-model');
    final String secondId = generateChatDiaryId();
    container.listen(chatDiaryControllerProvider(secondId), (_, _) {});
    final ChatDiaryController second = container.read(
      chatDiaryControllerProvider(secondId),
    );
    await second.start(secondId, setup.session, openingMessage: '');
    expect(second.chat!.connectionConfig.model, 'other-model');
    expect(controller.chat!.connectionConfig.model, 'other-model');
  });

  test('聊天室套用新連線與隱私設定，舊回覆保留當時快照且下次使用新模型金鑰', () async {
    controller.updateComposer('第一段合成內容', []);
    await controller.send();
    final oldConfig = controller.chat!.connectionConfig;
    final previous = controller.chat!.activeMessages.last;
    const connectionConfig = AiConnectionConfig(
      provider: AiProvider.custom,
      customProtocol: AiApiProtocol.claudeMessages,
      baseUrl: 'https://new.example/v1',
      model: 'new-model',
    );
    settings.keys[connectionConfig.credentialId] = 'new-synthetic-key';
    await controller.applySettings(connectionConfig, false);
    expect(controller.chat!.connectionConfig.model, 'new-model');
    expect(controller.chat!.hidePersonNames, isFalse);
    expect(previous.connectionSnapshot!.toJson(), oldConfig.toJson());
    final saved = (await store.load(chat.id, setup.session))!;
    expect(saved.connectionConfig.protocol, AiApiProtocol.claudeMessages);
    expect(saved.hidePersonNames, isFalse);
    controller.updateComposer('下一段合成內容', []);
    await controller.send();
    expect(clientConfigs.last.toJson(), connectionConfig.toJson());
    expect(clientKeys.last, 'new-synthetic-key');
    expect(
      controller.chat!.activeMessages.last.connectionSnapshot!.model,
      'new-model',
    );
  });

  test('完成聊天寫在日記旁邊，刪除聊天不刪日記', () async {
    controller.updateComposer('一段回憶', []);
    await controller.send();
    final oldReply = controller.chat!.activeMessages.last.id;
    await controller.regenerateReply(oldReply);
    final entryId = await harness.saveSimpleEntry(setup);
    await store.complete(chat.id, entryId, setup.session);
    final archived = await store.loadForEntry(entryId, setup.session);
    expect(archived, isNotNull);
    expect(archived!.finished, isTrue);
    expect(archived.generatedEntryId, entryId);
    await controller.loadForEntry(entryId, setup.session);
    final calls = client.calls.length;
    controller.beginEditing(archived.activeMessages.first.id);
    await controller.regenerateReply(oldReply);
    controller.updateComposer('不能修改', []);
    expect(controller.chat!.editingMessageId, isNull);
    expect(controller.canSend, isFalse);
    controller.selectVersion(oldReply);
    expect(controller.chat!.activeMessages.last.id, oldReply);
    expect(client.calls.length, calls);
    await store.flush();
    expect(
      (await store.loadForEntry(
        entryId,
        setup.session,
      ))!.activeMessages.last.id,
      oldReply,
    );
    expect((await store.draftDirectory(chat.id)).existsSync(), isFalse);
    final chatFile = File(
      await harness.pathStrategy.entryChatAbsolutePath(
        date: const DateOnly('2026-05-24'),
        entryId: entryId,
      ),
    );
    for (final suffix in ['.previous', '.tmp']) {
      await chatFile.copy('${chatFile.path}$suffix');
    }
    await store.delete(chat.id, session: setup.session, entryId: entryId);
    for (final suffix in ['', '.previous', '.tmp']) {
      expect(File('${chatFile.path}$suffix').existsSync(), isFalse);
    }

    expect(
      await harness.repository.loadEntry(setup.session, entryId),
      isNotNull,
    );
    expect(
      File(
        await harness.pathStrategy.entryChatAbsolutePath(
          date: const DateOnly('2026-05-24'),
          entryId: entryId,
        ),
      ).existsSync(),
      isFalse,
    );
  });
}
