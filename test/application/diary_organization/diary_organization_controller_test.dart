import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/ai/ai_prompt_localizations.dart';
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
import '../../helpers/shared/test_l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OrganizationTestScope scope;
  setUp(() async {
    scope = await OrganizationTestScope.create();
  });
  tearDown(() async {
    await scope.dispose();
  });

  Future<void> recreateScopeWithPerson() async {
    await scope.dispose();
    scope = await OrganizationTestScope.create(withPerson: true);
  }

  Future<void> send(String message) async {
    if (scope.controller.draft!.stage == OrganizationStage.privacy) {
      await scope.controller.startChat();
    }
    scope.controller.updateComposer(message, []);
    await scope.controller.sendMessage();
  }

  test('取消自動隱藏的 email 會明文送出，並留在草稿', () async {
    const email = 'a+b@example.org';
    const text = '信箱 $email';
    final start = text.indexOf(email);
    final controller = scope.controller;
    await controller.startChat();
    controller.updateComposer(text, const [], [
      PrivateTextRange(start, start + email.length),
    ]);
    await controller.sendMessage();
    final turn = controller.draft!.turns.single.user;
    expect(turn, contains(email));
    final loaded = DiaryOrganization.fromJson(controller.draft!.toJson());
    expect(loaded.revealedSecrets, contains(email));
    expect(loaded.turns.single.user, contains(email));
  });

  test('另一個需求版本的私密代號不能出現在生成結果', () async {
    final controller = scope.controller;
    await controller.startChat();
    controller.updateComposer('舊秘密', [const PrivateTextRange(0, 3)]);
    await controller.sendMessage();
    final token = controller.draft!.originals.keys.last;
    await controller.beginEditing(0);
    controller.updateComposer('目前的整理需求', []);
    await controller.sendMessage();
    scope.client.output = jsonEncode({
      'reply': '修改說明',
      'body': '${controller.draft!.protectedSource} $token',
    });
    await controller.generateDraft();
    expect(controller.error, AiErrorCode.response);
    expect(controller.draft!.organizedBody, isNull);
    expect(controller.draft!.turns, hasLength(2));
    expect(controller.draft!.restore(token), token);
  });

  test('串流回覆引用其他版本代號時不還原，完成後標示失敗', () async {
    final controller = scope.controller;
    await controller.startChat();
    controller.updateComposer('舊秘密', [const PrivateTextRange(0, 3)]);
    await controller.sendMessage();
    final token = controller.draft!.originals.keys.last;
    await controller.beginEditing(0);
    controller.updateComposer('目前需求', []);
    final entered = Completer<void>();
    final release = Completer<void>();
    scope.client.response = () async* {
      yield token;
      entered.complete();
      await release.future;
    };
    final sending = controller.sendMessage();
    await entered.future;
    final index = controller.draft!.activeTurnIndices.last;
    expect(
      controller.draft!
          .visibleText(controller.draft!.turns[index].reply, turn: index)
          .text,
      controller.draft!.turns[index].reply,
    );
    expect(controller.draft!.turns[index].reply, isNot(contains('舊秘密')));
    release.complete();
    await sending;
    expect(controller.error, AiErrorCode.response);
    expect(controller.draft!.turns[index].interrupted, isTrue);
    expect(controller.canGenerate, isFalse);
  });

  test('生成說明與候選一起保存，修改內文及返回聊天清除說明', () async {
    await send('只修順語句');
    scope.client.output = jsonEncode({'reply': '保留原意並修順語句。', 'body': '修順後的內文'});
    await scope.controller.generateDraft();
    expect(scope.controller.draft!.generationReply, '保留原意並修順語句。');
    expect(
      (await scope.container
              .read(diaryOrganizationStoreProvider)
              .load(scope.entry.id, scope.setup.session))!
          .generationReply,
      '保留原意並修順語句。',
    );
    await scope.controller.editBody('手動修改後');
    expect(scope.controller.draft!.generationReply, isNull);
    await scope.controller.returnToChat();
    expect(scope.controller.draft!.organizedBody, isNull);
  });

  test('生成說明含代號時保存原始回覆，有效內文仍保留', () async {
    await send('修順');
    scope.client.output = jsonEncode({
      'reply': '限制 {{PRI_FF}}',
      'body': '合法整理稿',
    });
    await scope.controller.generateDraft();
    expect(scope.controller.error, isNull);
    expect(scope.controller.draft!.organizedBody, '合法整理稿');
    final reply = scope.controller.draft!.generationReply;
    expect(reply, startsWith('限制 {{PRI_'));
    expect(reply, isNot(contains('{{PRI_FF}}')));
  });

  test('越界舊候選收尾保存被拒絕時，鎖定仍立即清除畫面資料', () async {
    final controller = scope.controller;
    await controller.startChat();
    final draft = controller.draft!;
    draft.originals['{{PRI_01}}'] = '其他分支的秘密';
    draft.appendTurn(OrganizationTurn(user: '舊需求 {{PRI_01}}'));
    draft.appendTurn(OrganizationTurn(user: '目前需求'));
    draft.organizedBody = '${draft.protectedSource} {{PRI_01}}';
    draft.stage = OrganizationStage.review;
    expect(controller.lock, returnsNormally);
    expect(controller.draft, isNull);
    expect(controller.vault, isNull);
    expect(controller.busy, isFalse);
    expect(controller.loading, isFalse);
    final saved = await scope.container
        .read(diaryOrganizationStoreProvider)
        .load(scope.entry.id, scope.setup.session);
    expect(saved!.organizedBody, isNull);
  });

  group('進入與隱私', () {
    test('AI 關閉時保留整理輸入與隱藏標記，不送出需求或生成', () async {
      final controller = scope.controller;
      await controller.startChat();
      controller.updateComposer('私人整理需求', [const PrivateTextRange(0, 2)]);
      await scope.container.read(aiEnabledProvider.notifier).setEnabled(false);
      await controller.sendMessage();
      await controller.generateDraft();
      expect(controller.draft!.composer, '私人整理需求');
      expect(controller.draft!.composerRanges.single.end, 2);
      expect(scope.client.calls, isEmpty);
      await scope.container.read(aiEnabledProvider.notifier).setEnabled(true);
      expect(scope.client.calls, isEmpty);
    });

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

    test('開始整理後新增的人物在隱藏開啟時直接換成代號，關閉時保留原名', () async {
      final controller = scope.controller;
      await controller.startChat();
      await scope.harness.repository.createPerson(
        scope.setup.session,
        PersonDraft(name: '林新同學', aliases: ['新同學']),
      );
      const text = '保留林新同學說的話';
      controller.updateComposer(text, []);
      final preview = (await controller.previewRequest())!;
      expect(preview.turns.single.text, contains('{{PER'));
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
      await recreateScopeWithPerson();
      final controller = scope.controller;
      controller.updatePrivacy([
        const PrivateTextRange(9, 12),
        const PrivateTextRange(13, 15),
      ]);
      await controller.startChat();
      expect(
        controller.draft!.protectedSource,
        '今天和{{PER_01}}散步。{{PER_01}}說{{PRI_01}}很好。',
      );
      controller.updateComposer('王小明和私事', [
        const PrivateTextRange(0, 3),
        const PrivateTextRange(4, 6),
      ]);
      await controller.sendMessage();
      expect(
        scope.client.calls.single.messages.single.text,
        '{{PER_01}}和{{PRI_02}}',
      );
      await controller.persist();
      controller.lock();
      await controller.load(scope.setup.session);
      expect(
        controller.draft!.protectedSource,
        '今天和{{PER_01}}散步。{{PER_01}}說{{PRI_01}}很好。',
      );
    });

    test('隱藏開關不改寫手動區間，開始整理時才套用目前的人名規則', () async {
      await recreateScopeWithPerson();
      scope.settings.hidePersonNames = false;
      scope.controller.lock();
      await scope.controller.load(scope.setup.session);
      expect(scope.controller.draft!.hiddenRanges, isEmpty);

      scope.settings.hidePersonNames = true;
      await scope.controller.refreshPrivacyPreset();
      expect(scope.controller.draft!.hiddenRanges, isEmpty);

      scope.settings.hidePersonNames = false;
      scope.controller.lock();
      await scope.controller.load(scope.setup.session);
      scope.settings.hidePersonNames = true;
      await scope.controller.startChat();
      expect(scope.controller.draft!.protectedSource, contains('{{PER'));
      expect(scope.controller.draft!.protectedSource, isNot(contains('王小明')));
    });

    test('已保存的手動區間不會因開關重算，開始整理仍依目前開關替換人名', () async {
      await recreateScopeWithPerson();
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
      expect(controller.draft!.protectedSource, contains('{{PER'));
      expect(controller.draft!.protectedSource, isNot(contains('王小明')));
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

    test('生成途中可預覽本次請求，停止後晚到的預覽不回傳也不報錯', () async {
      await send('修順');
      final controller = scope.controller;
      final stream = StreamController<String>();
      final started = Completer<void>();
      scope.client.response = () {
        started.complete();
        return stream.stream;
      };
      final generating = controller.generateDraft();
      await started.future;
      final during = await controller.previewRequest();
      expect(during, isNotNull);
      expect(during!.turns, isNotEmpty);
      expect(controller.busy, isTrue);
      expect(scope.client.calls, hasLength(2));
      final gate = Completer<void>();
      scope.settings.readGate = gate.future;
      scope.settings.readStarted = Completer<void>();
      final latePreview = controller.previewRequest();
      await scope.settings.readStarted!.future;
      controller.stop();
      gate.complete();
      expect(await latePreview, isNull);
      expect(controller.error, isNull);
      await stream.close();
      await generating;
      expect(controller.draft!.organizedBody, isNull);
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
      scope.settings.organizationPrompts =
          const DiaryOrganizationPromptSettings(conversationOverride: '自訂需求對話');
      await send('修順');
      expect(scope.client.calls.single.prompt, contains('自訂需求對話'));
      expect(
        scope.client.calls.single.prompt,
        contains(testL10n.organizationRules),
      );
      expect(
        scope.client.calls.single.prompt,
        contains(testL10n.organizationConversationLabel),
      );
      expect(
        scope.client.calls.single.prompt,
        isNot(contains(testL10n.organizationConversationPrompt)),
      );
      scope.client.output = jsonEncode({'reply': '完成', 'body': '整理稿'});
      await scope.controller.generateDraft();
      expect(
        scope.client.calls.last.prompt,
        contains(testL10n.organizationGenerationPrompt),
      );
      expect(scope.client.calls.last.prompt, isNot(contains('自訂需求對話')));
    });

    test('聊天室選擇模型同步工作與 AI 設定', () async {
      final connection = scope.controller.draft!.connection;
      final updated = connection.copyWith(
        addedModels: [...connection.addedModels, 'another-model'],
        enabledModels: [connection.model, 'another-model'],
      );
      scope.settings.organizationPrompts =
          const DiaryOrganizationPromptSettings(conversationOverride: '保留覆寫');
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

    test('前後說明與圍欄仍採用整理稿，空白或純說明則不採用', () async {
      await send('修順');
      final payload = jsonEncode({'reply': '已修順 {這段}', 'body': '整理後日記'});
      scope.client.output = '先說明\n```json\n$payload\n```\n後記';
      await scope.controller.generateDraft();
      expect(scope.controller.error, isNull);
      expect(scope.controller.draft!.stage, OrganizationStage.review);
      expect(scope.controller.draft!.currentBody, '整理後日記');
      expect(scope.controller.draft!.generationReply, '已修順 {這段}');

      await scope.controller.returnToChat();
      scope.client.output = jsonEncode({'reply': '沒有內容', 'body': '  \n'});
      await scope.controller.generateDraft();
      expect(scope.controller.draft!.stage, OrganizationStage.chat);
      expect(scope.controller.draft!.organizedBody, isNull);
      expect(scope.controller.error, AiErrorCode.response);

      scope.client.output = '這只是說明，沒有整理稿';
      await scope.controller.generateDraft();
      expect(scope.controller.draft!.organizedBody, isNull);
      expect(scope.controller.draft!.stage, OrganizationStage.chat);
      expect(scope.controller.error, AiErrorCode.response);
    });

    test('整理稿少了保護代號時不採用', () async {
      await recreateScopeWithPerson();
      await send('修順');
      expect(scope.controller.draft!.protectedSource, contains('{{PER'));
      scope.client.output = jsonEncode({'reply': '完成', 'body': '沒有保留代號的稿'});
      await scope.controller.generateDraft();
      expect(scope.controller.draft!.organizedBody, isNull);
      expect(scope.controller.draft!.stage, OrganizationStage.chat);
      expect(scope.controller.error, AiErrorCode.response);
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
