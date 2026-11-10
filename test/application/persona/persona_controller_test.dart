import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/persona/persona_controller.dart';
import 'package:quill_diary/application/persona/persona_providers.dart';
import 'package:quill_diary/application/persona/persona_request_payload.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_stored_settings.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/domain/persona/persona_privacy.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/l10n/app_localizations_en.dart';

import '../../helpers/ai/ai_test_helpers.dart';
import '../../helpers/persona/gated_persona_store.dart';
import '../../helpers/persona/persona_fixtures.dart';
import '../../helpers/shared/test_l10n.dart';
import '../../helpers/vault/vault_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late VaultTestHarness harness;
  late RecoverySetupResult setup;
  late ProviderContainer container;
  late PersonaController controller;
  late GatedPersonaStore store;
  late FakeAiClient client;
  late OverviewAiSettingsStore settings;
  late Person person;
  late String entryId;
  setUp(() async {
    harness = await VaultTestHarness.create();
    setup = await harness.repository.setupRecoveryKey();
    person = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小明'),
    );
    entryId = await harness.saveSimpleEntry(setup, markdownBody: '我和小明去海邊。');
    final config = testChatDiarySession().connectionConfig;
    settings = OverviewAiSettingsStore()
      ..settings = AiConnectionSettings(
        activeConnectionId: config.connectionId,
        connections: {config.connectionId: config},
      );
    client = FakeAiClient(config)
      ..output = jsonEncode({'memory': '一起去海邊', 'tone': '簡短自然'});
    store = GatedPersonaStore(
      paths: harness.pathStrategy,
      crypto: LocalCryptoService(),
      repository: harness.repository,
    );
    container = ProviderContainer(
      overrides: [
        vaultPathStrategyProvider.overrideWithValue(harness.pathStrategy),
        vaultRepositoryProvider.overrideWithValue(harness.repository),
        personaStoreProvider.overrideWithValue(store),
        aiSettingsStoreProvider.overrideWithValue(settings),
        aiClientFactoryProvider.overrideWithValue((_, _) => client),
        userPreferencesProvider.overrideWithValue(
          UserPreferences(
            storageFile: File('${harness.tempDir.path}/preferences.json'),
          ),
        ),
      ],
    );
    container.read(appSessionProvider.notifier).activateSession(setup.session);
    await container.read(effectiveAppSessionProvider.future);
    container.listen(personaControllerProvider(person.id), (_, _) {});
    controller = container.read(personaControllerProvider(person.id));
    await controller.load();
    await controller.begin(PersonaUpdateTarget.both);
    await controller.selectDiary(entryId, true);
  });
  tearDown(() async {
    container.dispose();
    await harness.dispose();
  });

  Future<void> create() async {
    await controller.prepare(testL10n);
    await controller.generate();
    await controller.save();
  }

  void replacePreview({
    String? instructions,
    String? extractionInstructions,
    Map<String, String>? baseline,
  }) {
    final current = controller.preview!;
    controller.preview = PersonaGenerationContext(
      personaId: current.personaId,
      target: current.target,
      baseUpdatedAt: current.baseUpdatedAt,
      session: current.session,
      connection: current.connection,
      instructions: instructions ?? current.instructions,
      extractionInstructions:
          extractionInstructions ?? current.extractionInstructions,
      registry: current.registry,
      blocks: current.blocks,
      baseline: baseline ?? current.baseline,
      subject: current.subject,
      selectionSignature: current.selectionSignature,
    );
  }

  test('跳脫材料與多輪摘要的每次外送都符合請求上限', () async {
    await harness.saveSimpleEntry(
      setup,
      id: entryId,
      markdownBody: '"\\\n文' * 5000,
    );
    await controller.selectDiary(entryId, false);
    await controller.selectDiary(entryId, true);
    await controller.prepare(testL10n);
    expect(controller.preview!.requiresBatching, isTrue);
    var summaryRounds = 0;
    client.response = () async* {
      final data = jsonDecode(client.calls.last.messages.single.text) as Map;
      if (data.containsKey('fragment')) {
        final fragment = data['fragment'];
        if (fragment is Map) {
          yield '"' * 2600;
        } else {
          summaryRounds++;
          yield '精簡證據';
        }
      } else {
        yield jsonEncode({'memory': '新的記憶', 'tone': '自然'});
      }
    };
    await controller.generate();
    expect(controller.failed, isFalse);
    expect(summaryRounds, greaterThan(0));
    expect(controller.draft!.candidate, isNotNull);
    for (final call in client.calls) {
      expect(
        personaRequestLength(call.prompt, call.messages.single.text),
        lessThanOrEqualTo(PersonaLimits.requestCodeUnits),
      );
    }
  });

  test('確認頁與實際生成都將主題及 JSON 欄位算入長度，剛好上限可送出', () async {
    await controller.prepare(testL10n);
    final current = controller.preview!;
    final data = personaGenerationData(
      subject: current.subject,
      baseline: current.baseline,
      materials: current.requestMaterials,
    );
    replacePreview(
      instructions: '指' * (PersonaLimits.requestCodeUnits - data.length),
    );
    expect(controller.preview!.requiresBatching, isFalse);
    await controller.generate();
    expect(controller.failed, isFalse);
    expect(client.calls, hasLength(1));
    expect(
      personaRequestLength(
        client.calls.single.prompt,
        client.calls.single.messages.single.text,
      ),
      PersonaLimits.requestCodeUnits,
    );
  });

  for (final fixedCards in [false, true]) {
    test('${fixedCards ? '既有卡片' : '固定指令'}超限時不送出請求，保留材料與草稿', () async {
      await controller.prepare(testL10n);
      if (fixedCards) {
        replacePreview(
          baseline: {'memory': '"' * PersonaLimits.requestCodeUnits},
        );
      } else {
        replacePreview(instructions: '指' * PersonaLimits.requestCodeUnits);
      }
      await controller.generate();
      expect(controller.failed, isTrue);
      expect(client.calls, isEmpty);
      expect(controller.draft!.diaries.single.entryId, entryId);
      expect(
        (await store.load(person.id, setup.session))!.draft!.candidate,
        isNull,
      );
    });
  }

  test('載入途中鎖定可立即重新載入，舊載入結束不解除新載入狀態', () async {
    controller.lock();
    final oldRelease = Completer<void>();
    final oldStarted = Completer<void>();
    store.loadGate = oldRelease.future;
    store.loadStarted = oldStarted;
    final oldLoading = controller.load();
    await oldStarted.future;
    controller.lock();
    expect(controller.loading, isFalse);
    expect(controller.session, isNull);

    final newRelease = Completer<void>();
    final newStarted = Completer<void>();
    store.loadGate = newRelease.future;
    store.loadStarted = newStarted;
    final newLoading = controller.load();
    await newStarted.future;
    oldRelease.complete();
    await oldLoading;
    expect(controller.loading, isTrue);
    expect(controller.record, isNull);
    newRelease.complete();
    await newLoading;
    expect(controller.loading, isFalse);
    expect(controller.record, isNotNull);
    store.loadGate = null;
    store.loadStarted = null;
  });

  test('等待工作階段期間鎖定或釋放，不會重新啟動載入', () async {
    controller.lock();
    final loading = controller.load();
    controller.lock();
    await loading;
    expect(controller.session, isNull);
    expect(controller.loading, isFalse);
    final disposedLoading = controller.load();
    container.invalidate(personaControllerProvider(person.id));
    await disposedLoading;
    expect(controller.session, isNull);
  });

  for (final dispose in [false, true]) {
    test('${dispose ? '釋放控制器' : '鎖定'}立即保存未滿延遲時間的最後一次編輯', () async {
      await create();
      await controller.begin(PersonaUpdateTarget.memory, edit: true);
      controller.editCandidate(PersonaCardKind.memory, '最後一次本機修改');
      if (dispose) {
        container.invalidate(personaControllerProvider(person.id));
      } else {
        controller.lock();
      }
      final saved = (await store.load(person.id, setup.session))!;
      expect(saved.draft!.candidate![PersonaCardKind.memory]!.text, '最後一次本機修改');
      expect(controller.record, isNull);
    });
  }

  test('實際工作階段鎖定並關閉資源後，最後一次編輯仍可解密讀取', () async {
    await create();
    await controller.begin(PersonaUpdateTarget.memory, edit: true);
    controller.editCandidate(PersonaCardKind.memory, '工作階段關閉前的修改');
    await container.read(appSessionProvider.notifier).lock();
    final saved = (await store.load(person.id, setup.session))!;
    expect(saved.draft!.candidate![PersonaCardKind.memory]!.text, '工作階段關閉前的修改');
    expect(controller.session, isNull);
    expect(controller.record, isNull);
  });

  test('停止生成不會取消排隊中的一般草稿保存', () async {
    await create();
    await controller.begin(PersonaUpdateTarget.memory, edit: true);
    controller.editCandidate(PersonaCardKind.memory, '保留的本機修改');
    final saving = controller.persist();
    controller.stop();
    await saving;
    expect(
      (await store.load(
        person.id,
        setup.session,
      ))!.draft!.candidate![PersonaCardKind.memory]!.text,
      '保留的本機修改',
    );
  });

  test('自動儲存排隊途中再次編輯並鎖定，舊保存完成不會清掉新修改', () async {
    await create();
    await controller.begin(PersonaUpdateTarget.memory, edit: true);
    final entered = Completer<void>();
    final release = Completer<void>();
    final blocking = harness.repository.runVaultMutation(() async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    controller.editCandidate(PersonaCardKind.memory, '較早的修改');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    controller.editCandidate(PersonaCardKind.memory, '較晚的修改');
    controller.lock();
    release.complete();
    await blocking;
    final saved = (await store.load(person.id, setup.session))!;
    expect(saved.draft!.candidate![PersonaCardKind.memory]!.text, '較晚的修改');
    expect(controller.failed, isFalse);
  });

  for (final deleting in [false, true]) {
    test('${deleting ? '刪除分身' : '捨棄更新'}取消排隊中的一般保存，晚到內容不會恢復草稿', () async {
      await create();
      await controller.begin(PersonaUpdateTarget.memory, edit: true);
      controller.editCandidate(PersonaCardKind.memory, '即將捨棄的修改');
      final release = Completer<void>();
      final entered = Completer<void>();
      final blocking = harness.repository.runVaultMutation(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final saving = expectLater(controller.persist(), throwsFormatException);
      final closing = deleting
          ? controller.delete()
          : controller.discardUpdate();
      release.complete();
      await blocking;
      await saving;
      await closing;
      final saved = await store.load(person.id, setup.session);
      if (deleting) {
        expect(saved, isNull);
      } else {
        expect(saved!.draft, isNull);
      }
    });
  }

  test('匯入已提交但回傳前鎖定，不會用舊快照還原失效的材料指標', () async {
    final imported = parsePersonaLineChat(
      '2026/11/06\n12:00\t小明\t原本材料',
      vaultId: setup.session.vaultId,
      personId: person.id,
      personaId: controller.record!.personaId,
    );
    await controller.attachImport(imported);
    final oldContentId = controller.draft!.chats.single.contentId;
    controller.draft!.hidePersonNames = false;
    controller.resetToMaterials();
    final revised = parsePersonaLineChat(
      '2026/11/06\n12:00\t小明\t更新材料',
      vaultId: imported.vaultId,
      personId: imported.personId,
      personaId: imported.personaId,
    );
    final update = PersonaChatImport.fromJson({
      ...revised.toJson(),
      'import_id': imported.importId,
    });
    final committed = Completer<void>();
    final release = Completer<void>();
    store.importCommitted = committed;
    store.importCommittedGate = release.future;
    final updating = expectLater(
      controller.updateImport(update),
      throwsFormatException,
    );
    await committed.future;
    controller.lock();
    release.complete();
    await updating;
    final saved = (await store.load(person.id, setup.session))!;
    final source = saved.draft!.chats.single;
    expect(source.contentId, isNot(oldContentId));
    expect(saved.draft!.hidePersonNames, isFalse);
    final restored = await store.readImport(
      person.id,
      saved.personaId,
      source,
      setup.session,
    );
    expect(restored.messages.single.text, '更新材料');
  });

  test('鎖定收尾寫入失敗保留有效檔案，晚到錯誤不更新新工作階段', () async {
    await create();
    await controller.begin(PersonaUpdateTarget.memory, edit: true);
    final previous = (await store.load(person.id, setup.session))!.toJson();
    final temporary = Directory(
      '${(await store.directory(person.id)).path}/state.json.enc.tmp',
    );
    await temporary.create();
    controller.editCandidate(PersonaCardKind.memory, '無法寫入的修改');
    controller.lock();
    await controller.load();
    final saved = (await store.load(person.id, setup.session))!;
    expect(saved.toJson(), previous);
    expect(controller.failed, isFalse);
    expect(controller.record, isNotNull);
    await temporary.delete();
  });

  test('模型尚未填寫仍可確認與保存材料，生成不建立客戶端', () async {
    settings.settings = const AiConnectionSettings(
      activeConnectionId: 'custom',
      connections: {'custom': AiConnectionConfig(provider: AiProvider.custom)},
    );
    await controller.prepare(testL10n);
    expect(controller.draft!.step, PersonaStep.confirmation);
    expect(controller.preview!.blocks, isNotEmpty);
    expect((await store.load(person.id, setup.session))!.draft, isNotNull);
    await controller.generate();
    expect(controller.failed, isTrue);
    expect(client.calls, isEmpty);
    expect(controller.draft!.diaries.single.entryId, entryId);
  });

  test('關閉 AI 保留確認材料，重新開啟前不送出分身請求', () async {
    await controller.prepare(testL10n);
    final preview = controller.preview;
    await container.read(aiEnabledProvider.notifier).setEnabled(false);
    await controller.generate();
    expect(controller.preview, same(preview));
    expect(controller.draft!.diaries.single.entryId, entryId);
    expect(client.calls, isEmpty);
    await container.read(aiEnabledProvider.notifier).setEnabled(true);
    expect(client.calls, isEmpty);
  });

  for (final l10n in [testL10n, AppLocalizationsEn()]) {
    test('${l10n.localeName} 生成與分批指示使用實際隱藏標記，回覆保留標記時拒收候選', () async {
      controller.draft!.diaries.single.hiddenRanges = [
        const PrivateTextRange(0, 2),
      ];
      await controller.prepare(l10n);
      final preview = controller.preview!;
      expect(preview.blocks.single.text, startsWith(personaHiddenText));
      expect(preview.instructions, contains(personaHiddenText));
      expect(preview.extractionInstructions, contains(personaHiddenText));
      client.output = jsonEncode({
        'memory': '旅行$personaHiddenText',
        'tone': '自然',
      });

      await controller.generate();

      expect(client.calls.single.prompt, preview.instructions);
      expect(
        client.calls.single.messages.single.text,
        contains(personaHiddenText),
      );
      expect(controller.failed, isTrue);
      expect(controller.draft!.candidate, isNull);
      expect(
        (await store.load(person.id, setup.session))!.draft!.candidate,
        isNull,
      );

      client.output = jsonEncode({'memory': '去海邊', 'tone': '自然'});
      await controller.generate();
      expect(controller.failed, isFalse);
      expect(controller.draft!.candidate![PersonaCardKind.memory]!.text, '去海邊');
    });
  }

  test('只有聊天材料且官方連線沿用預設值時仍可確認送出', () async {
    settings.settings = const AiConnectionSettings();
    await controller.begin(PersonaUpdateTarget.both);
    final chat = parsePersonaLineChat(
      '2026/11/08\n09:12\t我\t早安\n09:14\t小明\t想去北海道',
      vaultId: setup.session.vaultId,
      personId: person.id,
      personaId: controller.record!.personaId,
    );
    chat.speakers[0].role = PersonaSpeakerRole.user;
    chat.speakers[1].role = PersonaSpeakerRole.personaSubject;
    await controller.attachImport(chat);

    await controller.prepare(testL10n);

    expect(controller.draft!.diaries, isEmpty);
    expect(controller.draft!.step, PersonaStep.confirmation);
    expect(controller.preview!.blocks, hasLength(2));
    expect(
      controller.preview!.connection.model,
      settings.settings.activeConfig.model,
    );
    expect(client.calls, isEmpty);
  });

  test('已移除的自訂連線不會改用其他模型送出', () async {
    settings.settings = const AiConnectionSettings();

    await expectLater(
      controller.prepare(testL10n),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          '錯誤原因',
          '原模型連線已移除',
        ),
      ),
    );

    expect(controller.preview, isNull);
    expect(client.calls, isEmpty);
  });

  test('修改聊天會清除舊候選並儲存原文與隱藏範圍，預覽只使用最新內容', () async {
    final chat = parsePersonaLineChat(
      '2026/11/08\n09:14\t小明\t想去北海道旅行',
      vaultId: setup.session.vaultId,
      personId: person.id,
      personaId: controller.record!.personaId,
    );
    chat.speakers.single.role = PersonaSpeakerRole.personaSubject;
    await controller.attachImport(chat);
    await controller.prepare(testL10n);
    await controller.generate();
    expect(controller.draft!.candidate, isNotNull);
    final message = chat.messages.single;
    controller.draft!.chats.single.hidden[message.id] = [
      const PrivateTextRange(0, 2),
    ];
    final updated = PersonaChatImport(
      vaultId: chat.vaultId,
      personId: chat.personId,
      personaId: chat.personaId,
      importId: chat.importId,
      importedAt: chat.importedAt,
      speakers: chat.speakers,
      messages: [
        PersonaImportMessage(
          id: message.id,
          speakerId: message.speakerId,
          text: '想去旅行',
          sentAtLocal: message.sentAtLocal,
        ),
      ],
    );

    await controller.updateImport(updated);

    expect(controller.preview, isNull);
    expect(controller.draft!.candidate, isNull);
    final saved = (await store.load(person.id, setup.session))!;
    expect(saved.draft!.step, PersonaStep.materials);
    expect(saved.draft!.chats.single.hidden[message.id]!.single.end, 2);
    final imported = await store.readImport(
      person.id,
      chat.personaId,
      controller.draft!.chats.single,
      setup.session,
    );
    expect(imported.messages.single.text, '想去旅行');
    await controller.prepare(testL10n);
    final block = controller.preview!.blocks.last;
    expect(block.text, '$personaHiddenText旅行');
    expect(
      jsonEncode(controller.preview!.requestMaterials),
      isNot(contains('北海道')),
    );
  });

  test('單次請求的材料與基準等於確認頁，生成只成為候選，只更新一項時不帶另一項', () async {
    await controller.prepare(testL10n);
    final preview = controller.preview!;
    expect(
      (jsonDecode(preview.selectionSignature) as Map).containsKey(
        'prompt_version',
      ),
      isFalse,
    );
    await controller.generate();
    expect(controller.failed, isFalse);
    expect(controller.record!.cards, isNull);
    expect(controller.draft!.step, PersonaStep.review);
    expect(client.calls.single.prompt, preview.instructions);
    final sent = jsonDecode(client.calls.single.messages.single.text) as Map;
    expect(
      sent['materials'],
      preview.blocks.map((b) => b.toRequestJson()).toList(),
    );
    expect(sent['current_cards'], preview.baseline);
    expect(sent['subject'], preview.subject);
    expect(preview.subject, isNot('小明'));
    await controller.save();
    final tone = controller.record!.cards![PersonaCardKind.tone]!.toJson();
    await controller.begin(PersonaUpdateTarget.memory);
    await controller.prepare(testL10n);
    expect(controller.preview!.baseline.keys, ['memory']);
    client.output = jsonEncode({'memory': '更新後的海邊記憶'});
    await controller.generate();
    await controller.save();
    expect(controller.record!.cards![PersonaCardKind.tone]!.toJson(), tone);
    final calls = client.calls.length;
    await controller.begin(PersonaUpdateTarget.memory, edit: true);
    expect(controller.entries, isEmpty);
    expect(controller.draft!.diaries, isEmpty);
    controller.editCandidate(PersonaCardKind.memory, '本機修改的記憶');
    await controller.save();
    expect(client.calls, hasLength(calls));
    expect(
      controller.record!.cards![PersonaCardKind.memory]!.selectedDiaryIds,
      [entryId],
    );
    expect(controller.record!.cards![PersonaCardKind.tone]!.toJson(), tone);
  });

  test('捨棄生成結果回到準備材料並清掉舊請求', () async {
    await controller.prepare(testL10n);
    await controller.generate();
    expect(controller.draft!.step, PersonaStep.review);
    expect(controller.preview, isNotNull);

    await controller.discardResult();

    expect(controller.draft!.candidate, isNull);
    expect(controller.draft!.step, PersonaStep.materials);
    expect(controller.preview, isNull);
    final saved = await store.load(person.id, setup.session);
    expect(saved!.draft!.candidate, isNull);
    expect(saved.draft!.step, PersonaStep.materials);
  });

  test('LINE 引用及其他人不作口吻證據，未知與系統訊息不外送', () async {
    final chat = parsePersonaLineChat(
      '2026/11/06（五）\n12:00\t小明\t自然的語氣\n> 引用別人的語氣\n12:01\t我\t我的語氣\n12:02\t第三人\t不應模仿\n12:03\t未知\t不該送出\n12:04\t已收回訊息',
      vaultId: setup.session.vaultId,
      personId: person.id,
      personaId: controller.record!.personaId,
    );
    chat.speakers[0].role = PersonaSpeakerRole.personaSubject;
    chat.speakers[1].role = PersonaSpeakerRole.user;
    chat.speakers[2].role = PersonaSpeakerRole.other;
    await controller.attachImport(chat);
    await controller.prepare(testL10n);
    final blocks = controller.preview!.blocks
        .where((b) => b.toRequestJson()['source'] == 'line')
        .map((b) => b.toRequestJson())
        .toList();
    expect(blocks, hasLength(3));
    expect(blocks.first['style_text'], isNot(contains('引用別人的語氣')));
    expect(blocks.first['text'], contains('引用別人的語氣'));
    expect(blocks.skip(1).every((b) => b['style_text'] == ''), isTrue);
    expect(
      controller.preview!.blocks.map((b) => b.text).join(),
      isNot(contains('不該送出')),
    );
  });

  test('手動移除人物參照時不保留多餘對照', () async {
    await create();
    await controller.begin(PersonaUpdateTarget.memory, edit: true);
    controller.draft!.candidate![PersonaCardKind.memory] = PersonaCandidate(
      text: '與⟦P01⟧散步',
      tokens: {'⟦P01⟧': person.id},
    );
    controller.editCandidate(PersonaCardKind.memory, '自己散步');
    await controller.save();
    final saved = (await store.load(person.id, setup.session))!;
    expect(saved.cards![PersonaCardKind.memory]!.tokens, isEmpty);
    expect(saved.cards![PersonaCardKind.memory]!.text, '自己散步');
  });

  test('模型缺少指定欄位或增加控制欄位時不保存候選', () async {
    await controller.prepare(testL10n);
    client.output = jsonEncode({'memory': '不完整', 'persona_id': '假識別'});
    await controller.generate();
    expect(controller.failed, isTrue);
    expect(controller.draft!.candidate, isNull);
    expect((await store.load(person.id, setup.session))!.cards, isNull);
    client.output = jsonEncode({'memory': '與 P01 去散步', 'tone': '簡短自然'});
    await controller.generate();
    expect(controller.failed, isTrue);
    expect(controller.draft!.candidate, isNull);
    client.output = jsonEncode({'memory': '重試後記憶', 'tone': '重試後語氣'});
    await controller.generate();
    expect(client.calls, hasLength(3));
    expect(controller.failed, isFalse);
    expect(controller.draft!.candidate![PersonaCardKind.memory]!.text, '重試後記憶');
  });

  for (final resumeReview in [false, true]) {
    test('重新載入${resumeReview ? '審閱結果保留候選' : '確認步驟返回準備材料'}，不自動外送', () async {
      controller.draft!.diaries.single.hiddenRanges = [
        const PrivateTextRange(0, 1),
      ];
      await controller.prepare(testL10n);
      if (resumeReview) await controller.generate();
      final saved = controller.draft!.toJson();
      final calls = client.calls.length;
      container.invalidate(personaControllerProvider(person.id));
      controller = container.read(personaControllerProvider(person.id));

      await controller.load();

      expect(controller.preview, isNull);
      expect(controller.draft!.toJson(), {
        ...saved,
        'step': resumeReview ? 'review' : 'materials',
      });
      expect(controller.entries.keys, [entryId]);
      expect(client.calls, hasLength(calls));
      if (!resumeReview) {
        await controller.prepare(testL10n);
        expect(controller.draft!.step, PersonaStep.confirmation);
        expect(controller.preview, isNotNull);
        expect(client.calls, hasLength(calls));
      }
    });
  }

  test('確認快照停止失效時直接回準備材料，保留材料與隱藏選擇', () async {
    await controller.prepare(testL10n);
    final saved = controller.draft!.toJson();

    controller.stop();

    expect(controller.preview, isNull);
    expect(controller.draft!.toJson(), {...saved, 'step': 'materials'});
    expect(controller.entries.keys, [entryId]);
    expect(client.calls, isEmpty);
  });

  test('鎖定後的晚到結果不寫回，匯入草稿仍可重新載入', () async {
    await controller.prepare(testL10n);
    final waiting = Completer<void>();
    final called = Completer<void>();
    client.response = () async* {
      called.complete();
      await waiting.future;
      yield jsonEncode({'memory': '晚到', 'tone': '晚到'});
    };
    final generating = controller.generate();
    await called.future;
    controller.lock();
    waiting.complete();
    await generating;
    final saved = await store.load(person.id, setup.session);
    expect(saved!.draft!.candidate, isNull);
    expect(saved.cards, isNull);
    expect(controller.record, isNull);
  });

  test('分批中間證據依序送往同一模型，摘要不寫入草稿', () async {
    await harness.saveSimpleEntry(
      setup,
      id: entryId,
      markdownBody: '海邊長材料' * 5000,
    );
    await controller.selectDiary(entryId, false);
    await controller.selectDiary(entryId, true);
    await controller.prepare(testL10n);
    client.response = () async* {
      if (client.calls.last.prompt.contains(
        testL10n.personaExtractionPrompt(personaHiddenText),
      )) {
        yield '精簡的中間證據';
      } else {
        yield jsonEncode({'memory': '長材料記憶', 'tone': '自然'});
      }
    };
    await controller.generate();
    expect(controller.failed, isFalse);
    expect(client.calls.length, greaterThan(1));
    expect(client.calls.last.messages.single.text, contains('精簡的中間證據'));
    for (final call in client.calls) {
      expect(
        (jsonDecode(call.messages.single.text) as Map)['subject'],
        controller.preview!.subject,
      );
    }
    final saved = await store.load(person.id, setup.session);
    expect(jsonEncode(saved!.toJson()), isNot(contains('精簡的中間證據')));
  });

  test('停止立即解除忙碌，新工作進行時舊結果不能修改候選或解除狀態', () async {
    await controller.prepare(testL10n);
    final oldReply = Completer<void>();
    final newReply = Completer<void>();
    final oldStarted = Completer<void>();
    final newStarted = Completer<void>();
    client.response = () async* {
      final first = client.calls.length == 1;
      (first ? oldStarted : newStarted).complete();
      await (first ? oldReply : newReply).future;
      yield jsonEncode({'memory': first ? '停止的舊記憶' : '有效的新記憶', 'tone': '自然'});
    };
    final oldWork = controller.generate();
    await oldStarted.future;
    controller.stop();
    expect(controller.busy, isFalse);
    await controller.prepare(testL10n);
    final newWork = controller.generate();
    await newStarted.future;
    oldReply.complete();
    await oldWork;
    expect(controller.busy, isTrue);
    expect(controller.draft!.candidate, isNull);
    newReply.complete();
    await newWork;
    expect(controller.busy, isFalse);
    expect(controller.failed, isFalse);
    expect(
      controller.draft!.candidate![PersonaCardKind.memory]!.text,
      '有效的新記憶',
    );
  });

  test('開始本機編輯寫入失敗時保留正式內容，解除阻礙後可重新開始', () async {
    await create();
    final published = controller.record!;
    final temporary = Directory(
      '${(await store.directory(person.id)).path}/state.json.enc.tmp',
    );
    await temporary.create();
    await expectLater(
      controller.begin(PersonaUpdateTarget.memory, edit: true),
      throwsA(isA<FileSystemException>()),
    );
    expect(controller.record, same(published));
    expect(controller.draft, isNull);
    await temporary.delete();
    await controller.begin(PersonaUpdateTarget.memory, edit: true);
    expect(controller.draft!.manualEdit, isTrue);
  });

  test('取消首次建立清除全部資料，再次建立會得到新生命週期', () async {
    final originalId = controller.record!.personaId;
    final imported = parsePersonaLineChat(
      '2026/11/06（五）\n12:00\t小明\t材料',
      vaultId: setup.session.vaultId,
      personId: person.id,
      personaId: originalId,
    );
    await controller.attachImport(imported);
    await controller.discardUpdate();
    expect(controller.record, isNull);
    expect(await store.load(person.id, setup.session), isNull);
    expect((await store.directory(person.id)).existsSync(), isFalse);
    await controller.begin(PersonaUpdateTarget.both);
    expect(controller.record!.personaId, isNot(originalId));
    expect(controller.draft!.chats, isEmpty);
  });

  test('正式儲存排隊期間停用候選修改與重複提交', () async {
    await controller.prepare(testL10n);
    await controller.generate();
    final original = controller.draft!.candidate![PersonaCardKind.memory]!.text;
    final entered = Completer<void>();
    final release = Completer<void>();
    final blocking = harness.repository.runVaultMutation(() async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    final saving = controller.save();
    try {
      expect(controller.busy, isTrue);
      controller.editCandidate(PersonaCardKind.memory, '等待期間的修改');
      await controller.save();
      expect(
        controller.draft!.candidate![PersonaCardKind.memory]!.text,
        original,
      );
    } finally {
      release.complete();
    }
    await blocking;
    await saving;

    expect(controller.busy, isFalse);
    expect(controller.record!.cards![PersonaCardKind.memory]!.text, original);
    expect(controller.draft, isNull);
  });

  test('取消更新寫入失敗時保留原草稿，清除阻礙後可再次取消', () async {
    await create();
    await controller.begin(PersonaUpdateTarget.memory, edit: true);
    controller.editCandidate(PersonaCardKind.memory, '尚未儲存的修改');
    await controller.persist();
    final current = controller.record!;
    final temporary = Directory(
      '${(await store.directory(person.id)).path}/state.json.enc.tmp',
    );
    await temporary.create();

    await expectLater(
      controller.discardUpdate(),
      throwsA(isA<FileSystemException>()),
    );

    expect(controller.busy, isFalse);
    expect(controller.record, same(current));
    expect(
      controller.draft!.candidate![PersonaCardKind.memory]!.text,
      '尚未儲存的修改',
    );
    expect((await store.load(person.id, setup.session))!.draft, isNotNull);
    await temporary.delete();
    await controller.discardUpdate();
    expect(controller.draft, isNull);
    expect((await store.load(person.id, setup.session))!.draft, isNull);
  });

  test('生成期間內容在別處提交，晚到候選不能覆寫新版', () async {
    await create();
    await controller.begin(PersonaUpdateTarget.memory);
    await controller.prepare(testL10n);
    final waiting = Completer<void>();
    final called = Completer<void>();
    client.response = () async* {
      called.complete();
      await waiting.future;
      yield jsonEncode({'memory': '舊工作結果'});
    };
    final generating = controller.generate();
    await called.future;
    final current = (await store.load(person.id, setup.session))!;
    current.draft!.candidate = {
      PersonaCardKind.memory: PersonaCandidate(text: '另一份已提交記憶'),
    };
    current.draft!.step = PersonaStep.review;
    await store.saveDraft(current, setup.session);
    await store.publish(person.id, current.personaId, setup.session);
    waiting.complete();
    await generating;
    expect(controller.failed, isTrue);
    final saved = (await store.load(person.id, setup.session))!;
    expect(saved.cards![PersonaCardKind.memory]!.text, '另一份已提交記憶');
    expect(saved.draft, isNull);
  });

  test('聊天預覽與外送使用人物記憶與聊天風格，訊息只留人物與分身識別，生成日記不附分身內容', () async {
    await create();
    final persona = controller.record!;
    final id = generateChatDiaryId();
    container.listen(chatDiaryControllerProvider(id), (_, _) {});
    final chat = container.read(chatDiaryControllerProvider(id));
    await chat.start(id, setup.session, openingMessage: '');
    await chat.selectPersona(persona);
    client.output = '朋友回覆';
    chat.updateComposer('今天很累', []);
    final preview = await chat.previewRequest();
    await chat.send();
    expect(client.calls.last.prompt, preview!.systemPrompt);
    expect(client.calls.last.prompt, contains('一起去海邊'));
    final message = chat.chat!.activeMessages.last;
    expect(
      message.persona!.toJson().containsKey('memory_revision_id'),
      isFalse,
    );
    expect(message.persona!.personId, persona.personId);
    expect(message.persona!.personaId, persona.personaId);
    expect(message.toJson().containsKey('system_prompt'), isFalse);
    final diary = await chat.previewRequest(generate: true);
    expect(diary!.systemPrompt, contains(testL10n.personaDiarySourcePrompt));
    expect(diary.systemPrompt, isNot(contains('一起去海邊')));
    expect(diary.turns.single.text, contains('ai_persona'));
    container.read(personaDeletionsProvider.notifier).mark(person.id);
    expect(chat.chat!.selectedPersona, isNull);
  });

  test('同場分身保留 assistant 角色與不同來源，重新回覆使用原人物而新聊天回到預設', () async {
    settings.chatDiaryPrompts = const ChatDiaryPromptSettings(
      personalityOverride: '預設專屬個性',
      guidanceOverride: '本次共通引導',
    );
    await create();
    final first = controller.record!;
    final otherPerson = await harness.repository.createPerson(
      setup.session,
      PersonDraft(name: '小華'),
    );
    final draft = personaDraftRecord(setup.session.vaultId, otherPerson.id);
    draft.draft!.candidate = personaCandidates(memory: '喜歡登山', tone: '活潑的語氣');
    draft.draft!.step = PersonaStep.review;
    await store.saveDraft(draft, setup.session, create: true);
    final second = await store.publish(
      otherPerson.id,
      draft.personaId,
      setup.session,
    );
    final id = generateChatDiaryId();
    container.listen(chatDiaryControllerProvider(id), (_, _) {});
    final chat = container.read(chatDiaryControllerProvider(id));
    await chat.start(id, setup.session, openingMessage: '');
    await chat.selectPersona(first);
    client.output = '第一位的回覆';
    chat.updateComposer('今天好累', []);
    await chat.send();
    final firstReplyId = chat.chat!.activeMessages.last.id;
    await chat.selectPersona(second);
    client.output = '第二位的回覆';
    chat.updateComposer('你呢', []);
    await chat.send();
    expect(client.calls.last.prompt, contains('喜歡登山'));
    expect(client.calls.last.prompt, isNot(contains('一起去海邊')));
    expect(client.calls.last.prompt, contains('本次共通引導'));
    expect(client.calls.last.prompt, isNot(contains('預設專屬個性')));
    await chat.selectPersona(first);
    chat.updateComposer('一起討論吧', []);
    await chat.send();
    final messages = client.calls.last.messages;
    expect(messages.map((m) => m.isUser), [true, false, true, false, true]);
    final speakers = messages
        .where((m) => !m.isUser)
        .map((m) => (jsonDecode(m.text) as Map)['speaker'] as Map)
        .toList();
    expect(speakers.every((s) => s['kind'] == 'ai_persona'), isTrue);
    expect(speakers[0]['person'], isNot(speakers[1]['person']));
    await chat.selectPersona(second);
    await chat.regenerateReply(firstReplyId);
    expect(client.calls.last.prompt, contains('一起去海邊'));
    expect(client.calls.last.prompt, isNot(contains('喜歡登山')));
    expect(chat.chat!.activeMessages.last.persona!.personaId, first.personaId);
    expect(chat.chat!.selectedPersona!.personaId, second.personaId);
    final newId = generateChatDiaryId();
    container.listen(chatDiaryControllerProvider(newId), (_, _) {});
    final newChat = container.read(chatDiaryControllerProvider(newId));
    await newChat.start(newId, setup.session, openingMessage: '');
    expect(newChat.chat!.selectedPersona, isNull);
    newChat.updateComposer('預設夥伴也用同一份引導', []);
    await newChat.send();
    expect(client.calls.last.prompt, contains('預設專屬個性'));
    expect(client.calls.last.prompt, contains('本次共通引導'));
    expect(client.calls.last.prompt, isNot(contains('一起去海邊')));
    expect(client.calls.last.prompt, isNot(contains('喜歡登山')));
  });

  test('關閉隱藏姓名後，主題與材料含真實姓名', () async {
    controller.draft!.hidePersonNames = false;
    await controller.prepare(testL10n);
    expect(controller.preview!.subject, '小明');
    expect(
      controller.preview!.blocks.map((block) => block.text).join(),
      contains('小明'),
    );
  });

  test('整段被隱藏的日記不能當材料', () {
    final body = controller.entries[entryId]!.markdownBody;
    controller.draft!.diaries.single.hiddenRanges = [
      PrivateTextRange(0, body.length),
    ];
    expect(controller.hasMaterials, isFalse);
  });

  test('再次勾選已選日記不會清掉候選', () async {
    await controller.prepare(testL10n);
    await controller.generate();
    expect(controller.draft!.candidate, isNotNull);
    await controller.selectDiary(entryId, true);
    expect(controller.draft!.candidate, isNotNull);
    expect(controller.draft!.step, PersonaStep.review);
  });

  test('刪除成功後清理旗標跟著儲存層清掉', () async {
    await create();
    store.pendingCleanup.add(person.id);
    controller.cleanupPending = true;
    await controller.delete();
    expect(store.pendingCleanup, isNot(contains(person.id)));
    expect(controller.cleanupPending, isFalse);
    expect(controller.record, isNull);
  });

  test('選取另一個讀取失敗的分身時保留目前夥伴', () async {
    await create();
    final persona = controller.record!;
    final id = generateChatDiaryId();
    container.listen(chatDiaryControllerProvider(id), (_, _) {});
    final chat = container.read(chatDiaryControllerProvider(id));
    await chat.start(id, setup.session, openingMessage: '');
    await chat.selectPersona(persona);
    final otherId = generatePersonId();
    final directory = await store.directory(otherId);
    await directory.create(recursive: true);
    await File('${directory.path}/state.json.enc.tmp').writeAsBytes([1]);
    await chat.selectPersona(
      PersonaRecord(
        vaultId: setup.session.vaultId,
        personId: otherId,
        personaId: generatePersonaId(),
        cards: persona.cards,
      ),
    );
    expect(chat.chat!.selectedPersona!.personaId, persona.personaId);
    expect(chat.personaUnavailable, isFalse);
  });
}
