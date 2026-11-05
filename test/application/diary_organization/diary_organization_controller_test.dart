import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/diary_organization/diary_organization_controller.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/ai/ai_stored_settings.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/diary_organization/diary_organization.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';

import '../../helpers/diary_organization/failing_organization_store.dart';
import '../../helpers/diary_organization/organization_test_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OrganizationTestScope scope;
  setUp(() async {
    scope = await OrganizationTestScope.create();
  });
  tearDown(() async {
    await scope.dispose();
  });

  Future<void> send(String message) async {
    if (scope.controller.draft!.stage == OrganizationStage.privacy) {
      await scope.controller.startChat();
    }
    scope.controller.updateComposer(message, []);
    await scope.controller.sendMessage();
  }

  group('進入與隱私', () {
    test('標記完成僅進入聊天室，不檢查連線或呼叫 AI', () async {
      final controller = scope.controller;
      controller.updatePrivacy([const PrivateTextRange(3, 6)]);
      await controller.startChat();
      expect(scope.client.calls, isEmpty);
      expect(scope.settings.keyReads, 0);
      expect(controller.draft!.stage, OrganizationStage.chat);
      expect(controller.draft!.turns, isEmpty);
      expect(controller.draft!.protectedSource, endsWith('王小明說天氣很好。'));
      expect(controller.draft!.protectedSource, isNot(startsWith('今天和王小明')));
      expect(controller.canGenerate, isFalse);
    });
    test('快速需求直接送出，但保留尚未送出的文字與隱藏標記', () async {
      final controller = scope.controller;
      await controller.startChat();
      controller.updateComposer('私人內容', [const PrivateTextRange(0, 2)]);
      await controller.sendMessage(message: '先潤飾語句');
      expect(scope.client.calls.single.messages.single.text, '先潤飾語句');
      expect(controller.draft!.composer, '私人內容');
      expect(controller.draft!.composerRanges.single.end, 2);
      expect(controller.canGenerate, isFalse);
      controller.updateComposer('', []);
      expect(controller.canGenerate, isTrue);
    });
    test('開始整理後新增的人物也會隱藏，切換隱藏設定會更新預覽與送出內容', () async {
      final controller = scope.controller;
      await controller.startChat();
      await scope.harness.repository.createPerson(
        scope.setup.session,
        PersonDraft(name: '林新同學', aliases: ['新同學']),
      );
      controller.updateComposer('保留林新同學說的話', []);
      final preview = (await controller.previewRequest())!;
      expect(preview.turns.single.text, contains('⟦P'));
      expect(preview.turns.single.text, isNot(contains('林新同學')));
      await controller.sendMessage();
      expect(
        scope.client.calls.single.messages.last.text,
        preview.turns.single.text,
      );
      scope.settings.hidePersonNames = false;
      controller.updateComposer('林新同學原名', []);
      expect((await controller.previewRequest())!.turns.last.text, '林新同學原名');
      await controller.sendMessage();
      expect(scope.client.calls.last.messages.last.text, '林新同學原名');
    });
    test('人物隱藏用 P、其他選取用 S，取消的姓名不重新隱藏', () async {
      await scope.dispose();
      scope = await OrganizationTestScope.create(withPerson: true);
      final controller = scope.controller;
      controller.updatePrivacy([
        const PrivateTextRange(9, 12),
        const PrivateTextRange(13, 15),
      ]);
      await controller.startChat();
      expect(controller.draft!.protectedSource, '今天和王小明散步。⟦P01⟧說⟦S01⟧很好。');
      controller.updateComposer('王小明和私事', [
        const PrivateTextRange(0, 3),
        const PrivateTextRange(4, 6),
      ]);
      await controller.sendMessage();
      expect(scope.client.calls.single.messages.single.text, '⟦P01⟧和⟦S02⟧');
      await controller.persist();
      controller.lock();
      await controller.load(scope.setup.session);
      expect(controller.draft!.protectedSource, '今天和王小明散步。⟦P01⟧說⟦S01⟧很好。');
    });
    test('尚未確認的預選會跟著最新隱藏開關更新', () async {
      await scope.dispose();
      scope = await OrganizationTestScope.create(withPerson: true);
      scope.settings.hidePersonNames = false;
      scope.controller.lock();
      await scope.controller.load(scope.setup.session);
      expect(scope.controller.draft!.hiddenRanges, isEmpty);

      scope.settings.hidePersonNames = true;
      await scope.controller.refreshPrivacyPreset();
      expect(scope.controller.draft!.hiddenRanges, isNotEmpty);

      scope.settings.hidePersonNames = false;
      scope.controller.lock();
      await scope.controller.load(scope.setup.session);
      scope.settings.hidePersonNames = true;
      await scope.controller.startChat();
      expect(scope.controller.draft!.protectedSource, contains('⟦P'));
      expect(scope.controller.draft!.protectedSource, isNot(contains('王小明')));
    });
    test('已確認或已保存的隱藏區間不會因開關重算', () async {
      await scope.dispose();
      scope = await OrganizationTestScope.create(withPerson: true);
      final controller = scope.controller;
      controller.updatePrivacy([const PrivateTextRange(0, 2)]);
      scope.settings.hidePersonNames = false;
      await controller.refreshPrivacyPreset();
      expect(controller.draft!.hiddenRanges, [const PrivateTextRange(0, 2)]);

      controller.updatePrivacy([]);
      await controller.persist();
      controller.lock();
      await controller.load(scope.setup.session);
      scope.settings.hidePersonNames = true;
      await controller.refreshPrivacyPreset();
      expect(controller.draft!.hiddenRanges, isEmpty);
      await controller.startChat();
      expect(controller.draft!.protectedSource, contains('王小明'));
    });
    test('保存全部取消的標記後恢復，不重新套用人物預選', () async {
      scope.controller.updatePrivacy([const PrivateTextRange(0, 2)]);
      scope.controller.updatePrivacy([]);
      await scope.controller.persist();
      scope.controller.lock();
      await scope.controller.load(scope.setup.session);
      expect(scope.controller.draft!.hiddenRanges, isEmpty);
      expect(scope.controller.draft!.stage, OrganizationStage.privacy);
    });
  });

  group('預覽與生成', () {
    test('兩種預覽與實際請求一致，隱藏原文不會隨後續稿件送回', () async {
      final controller = scope.controller;
      controller.updatePrivacy([const PrivateTextRange(3, 6)]);
      await controller.startChat();
      controller.updateComposer('私人內容', [const PrivateTextRange(0, 2)]);
      final preview = (await controller.previewRequest())!;
      expect(preview.turns.single.pending, isTrue);
      expect(preview.systemPrompt, contains('<diary_data>'));
      expect(preview.systemPrompt, contains(controller.draft!.protectedSource));
      expect(preview.turns.single.text, isNot(contains('私人')));
      expect((await controller.previewRequest(generate: true))!.turns, isEmpty);
      await controller.sendMessage();
      expect(scope.client.calls.single.prompt, preview.systemPrompt);
      expect(
        scope.client.calls.single.messages.single.text,
        preview.turns.single.text,
      );
      final token = privacyTokenPattern.firstMatch(
        preview.turns.single.text,
      )![0]!;
      scope.client.output = jsonEncode({
        'reply': '完成',
        'body': '${controller.draft!.protectedSource}，補充 $token',
      });
      final generation = (await controller.previewRequest(generate: true))!;
      expect(generation.turns.any((t) => t.pending), isFalse);
      await controller.generateDraft();
      expect(scope.client.calls.last.prompt, generation.systemPrompt);
      expect(
        scope.client.calls.last.messages.map((m) => m.text),
        generation.turns.map((t) => t.text),
      );
      expect(controller.draft!.restoredBody, contains('私人'));
      await controller.returnToChat();
      controller.updateComposer('再修順', []);
      final followup = (await controller.previewRequest())!;
      expect(followup.systemPrompt, isNot(contains('私人')));
      expect(followup.turns.map((t) => t.text).join(), isNot(contains('私人')));
      scope.client.output = '會保留你的語氣。';
      await controller.sendMessage();
      expect(scope.client.calls.last.prompt, followup.systemPrompt);
    });
    test('輸入與模型改變時重建預覽，日記資料只使用原文', () async {
      await send('修順');
      final controller = scope.controller;
      controller.draft!.replaceBody('目前稿');
      final first = (await controller.previewRequest())!;
      controller.updateComposer('新的需求', []);
      expect((await controller.previewRequest())!.turns.last.text, '新的需求');
      await controller.changeConnection(
        controller.draft!.connection.copyWith(model: '另一個模型'),
      );
      expect(
        (await controller.previewRequest())!.systemPrompt,
        first.systemPrompt,
      );
      controller.draft!.replaceBody('手動更新稿');
      expect(
        (await controller.previewRequest())!.systemPrompt,
        isNot(contains('手動更新稿')),
      );
    });
    test('重試與編輯保留分支，只傳送目前選取的對話', () async {
      await send('修順');
      final controller = scope.controller;
      scope.client.output = '原回答';
      await send('精簡');
      scope.client.output = '重試回答';
      await controller.sendMessage(retryTurn: 1);
      expect(controller.draft!.activeTurnIndices, [0, 2]);
      expect(controller.draft!.turns[1].reply, '原回答');
      await controller.selectTurn(1);
      controller.updateComposer('未送出', []);
      await controller.beginEditing(1);
      expect(
        (await controller.previewRequest(generate: true))!.turns
            .map((t) => t.text),
        contains('原回答'),
      );
      expect(controller.canGenerate, isFalse);
      controller.updateComposer('私人內容，請修順', [const PrivateTextRange(0, 2)]);
      scope.client.output = '編輯後回答';
      await controller.sendMessage();
      expect(controller.draft!.activeTurnIndices, [0, 3]);
      expect(controller.draft!.composer, '未送出');
      expect(scope.client.calls.last.messages.last.text, isNot(contains('私人')));
      expect(
        scope.client.calls.last.messages.map((m) => m.text),
        isNot(contains('重試回答')),
      );
      final loaded = await scope.container
          .read(diaryOrganizationStoreProvider)
          .load(scope.entry.id, scope.setup.session);
      expect(loaded!.activeTurnIndices, [0, 3]);
      expect(loaded.versionsOf(1), [1, 2, 3]);
    });
    test('送出與生成使用最新提示詞覆寫，未覆寫的用途維持內建', () async {
      scope.settings.organizationPrompts = const AiPromptOverrides(
        conversationOverride: '自訂需求對話',
      );
      await send('修順');
      expect(scope.client.calls.single.prompt, contains('自訂需求對話'));
      expect(scope.client.calls.single.prompt, isNot(contains('日記整理夥伴')));
      scope.client.output = jsonEncode({'reply': '完成', 'body': '整理稿'});
      await scope.controller.generateDraft();
      expect(scope.client.calls.last.prompt, contains('日記文字整理助手'));
      expect(scope.client.calls.last.prompt, isNot(contains('自訂需求對話')));
    });
    test('聊天室選擇模型同步工作與 AI 設定', () async {
      final connection = scope.controller.draft!.connection;
      final updated = connection.copyWith(
        addedModels: [...connection.addedModels, 'another-model'],
        enabledModels: [connection.model, 'another-model'],
      );
      scope.settings.organizationPrompts = const AiPromptOverrides(
        conversationOverride: '保留覆寫',
      );
      scope.settings.settings = AiConnectionSettings(
        activeConnectionId: updated.connectionId,
        connections: {updated.connectionId: updated},
      );
      await scope.controller.startChat();
      await scope.controller.selectModel(
        ChatModelOption(
          connectionConfig: updated.copyWith(model: 'another-model'),
        ),
      );
      expect(scope.controller.draft!.connection.model, 'another-model');
      expect(scope.settings.settings.activeConfig.model, 'another-model');
      expect(scope.settings.organizationPrompts.conversationOverride, '保留覆寫');
      final saved = await scope.container
          .read(diaryOrganizationStoreProvider)
          .load(scope.entry.id, scope.setup.session);
      expect(saved!.connection.model, 'another-model');
    });
  });

  group('離開、鎖定與套用', () {
    test('返回聊天清除未採用稿，重新生成只根據原文與聊天需求', () async {
      await send('保留語氣');
      final controller = scope.controller;
      scope.client.output = jsonEncode({'reply': '完成', 'body': '第一稿'});
      await controller.generateDraft();
      expect(controller.draft!.turns, hasLength(1));
      expect(controller.draft!.stage, OrganizationStage.review);
      await controller.editBody('手動改過的稿');
      await controller.returnToChat();
      expect(controller.draft!.organizedBody, isNull);
      final saved = (await scope.container
          .read(diaryOrganizationStoreProvider)
          .load(scope.entry.id, scope.setup.session))!;
      expect(saved.organizedBody, isNull);
      expect(saved.stage, OrganizationStage.chat);
      expect(jsonEncode(saved.toJson()), isNot(contains('手動改過的稿')));
      scope.client.output = '會精簡重複敘述。';
      await send('再精簡');
      scope.client.output = jsonEncode({'reply': '完成', 'body': '第二稿'});
      await controller.generateDraft();
      expect(scope.client.calls.last.prompt, isNot(contains('手動改過的稿')));
      expect(controller.draft!.currentBody, '第二稿');
      expect(controller.draft!.turns, hasLength(2));
      expect(jsonEncode(controller.draft!.toJson()), isNot(contains('第一稿')));
      await controller.selectTurn(0);
      expect(controller.draft!.currentBody, '第二稿');
    });
    test('請求中離頁仍繼續，重進不重送，完成結果可從加密草稿恢復', () async {
      await scope.controller.startChat();
      scope.controller.updateComposer('修順', []);
      final stream = StreamController<String>();
      final started = Completer<void>();
      scope.client.response = () {
        started.complete();
        return stream.stream;
      };
      final request = scope.controller.sendMessage();
      await started.future;
      await scope.controller.load(scope.setup.session);
      scope.subscription.close();
      await scope.container.pump();
      expect(scope.controller.busy, isTrue);
      stream.add('會修順文字並保留語氣。');
      await stream.close();
      await request;
      final loaded = await scope.container
          .read(diaryOrganizationStoreProvider)
          .load(scope.entry.id, scope.setup.session);
      expect(loaded!.turns.single.reply, '會修順文字並保留語氣。');
      expect(scope.client.calls, hasLength(1));
    });
    test('格式錯誤及停止生成都不採用稿件，晚到內容不會覆寫', () async {
      await send('修順');
      final controller = scope.controller;
      scope.client.output = '錯誤的 JSON';
      await controller.generateDraft();
      expect(controller.draft!.organizedBody, isNull);
      expect(controller.draft!.generationInterrupted, isTrue);
      final stream = StreamController<String>();
      final started = Completer<void>();
      scope.client.response = () {
        started.complete();
        return stream.stream;
      };
      final request = controller.generateDraft();
      await started.future;
      expect(controller.generating, isTrue);
      controller.stop();
      stream.add(jsonEncode({'reply': '晚到', 'body': '不應套用'}));
      await stream.close();
      await request;
      expect(controller.draft!.organizedBody, isNull);
      expect(controller.generating, isFalse);
      expect(controller.draft!.turns, hasLength(1));
    });
    test('生成寫入失敗不採用稿，返回聊天寫入失敗仍保留檢視稿', () async {
      await scope.dispose();
      late FailingOrganizationStore store;
      scope = await OrganizationTestScope.create(
        overrides: [
          diaryOrganizationStoreProvider.overrideWith(
            (ref) => store = FailingOrganizationStore(
              paths: ref.watch(vaultPathStrategyProvider),
              crypto: ref.watch(cryptoServiceProvider),
              repository: ref.watch(vaultRepositoryProvider),
            ),
          ),
        ],
      );
      await send('修順');
      scope.client.response = () async* {
        store.failSaves = true;
        yield jsonEncode({'reply': '完成', 'body': '無法保存的新稿'});
      };
      await scope.controller.generateDraft();
      expect(scope.controller.draft!.organizedBody, isNull);
      expect(scope.controller.error, AiErrorCode.storage);
      store.failSaves = false;
      final loaded = await store.load(scope.entry.id, scope.setup.session);
      expect(loaded!.organizedBody, isNull);
      scope.client.response = null;
      scope.client.output = jsonEncode({'reply': '完成', 'body': '仍在檢視的稿'});
      await scope.controller.generateDraft();
      store.failSaves = true;
      await expectLater(scope.controller.returnToChat(), throwsStateError);
      expect(scope.controller.draft!.stage, OrganizationStage.review);
      expect(scope.controller.draft!.organizedBody, '仍在檢視的稿');
      store.failSaves = false;
    });
    test('刪除整理後，晚到回覆不會重建草稿', () async {
      await scope.controller.startChat();
      scope.controller.updateComposer('修順', []);
      final stream = StreamController<String>();
      final started = Completer<void>();
      scope.client.response = () {
        started.complete();
        return stream.stream;
      };
      final request = scope.controller.sendMessage();
      await started.future;
      await scope.controller.discard();
      stream.add('晚到內容');
      await stream.close();
      await request;
      expect(
        await scope.container
            .read(diaryOrganizationStoreProvider)
            .load(scope.entry.id, scope.setup.session),
        isNull,
      );
      expect(scope.controller.draft, isNull);
    });
    test('鎖定保存最後片段，解鎖後手動重試而不自動送出', () async {
      await scope.controller.startChat();
      scope.controller.updateComposer('修順', []);
      final stream = StreamController<String>();
      final started = Completer<void>();
      scope.client.response = () {
        started.complete();
        return stream.stream;
      };
      final controller = scope.controller;
      final request = controller.sendMessage();
      await started.future;
      stream.add('鎖定前的片段');
      await Future<void>.delayed(Duration.zero);
      final session = scope.container.read(appSessionProvider.notifier);
      await session.lock();
      expect(controller.draft, isNull);
      expect(controller.busy, isFalse);
      expect(scope.client.closed, isTrue);
      stream.add('晚到內容');
      await stream.close();
      await request;
      await scope.harness.repository.ensureIndexReady(scope.setup.session);
      session.activateSession(scope.setup.session);
      await controller.load(scope.setup.session);
      expect(controller.draft!.turns.single.reply, '鎖定前的片段');
      expect(controller.draft!.turns.single.interrupted, isTrue);
      expect(scope.client.calls, hasLength(1));
      scope.client.response = null;
      scope.client.output = '重試完成';
      await controller.sendMessage(retryTurn: 0);
      expect(controller.draft!.turns.last.reply, '重試完成');
    });
    test('原日記改變時不能套用舊稿', () async {
      await send('修順');
      scope.controller.draft!.replaceBody('整理稿');
      await scope.harness.repository.saveEntry(
        scope.setup.session,
        scope.entry.copyWith(markdownBody: '手動更新'),
      );
      expect(await scope.controller.apply(), isNull);
      expect(scope.controller.conflict, isTrue);
      expect(
        (await scope.harness.repository.loadEntry(
          scope.setup.session,
          scope.entry.id,
        ))!.markdownBody,
        '手動更新',
      );
    });
  });
}
