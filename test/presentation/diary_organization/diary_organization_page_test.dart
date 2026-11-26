import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/app/router.dart';
import 'package:quill_diary/application/diary/diary_entry_providers.dart';
import 'package:quill_diary/application/diary_organization/diary_organization_controller.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/diary_organization/diary_organization.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_chat_input_panel.dart';
import 'package:quill_diary/presentation/ai/ai_connection_settings_dialog.dart';
import 'package:quill_diary/presentation/ai/ai_request_preview_dialog.dart';
import 'package:quill_diary/presentation/diary_organization/diary_organization_page.dart';
import 'package:quill_diary/presentation/diary_organization/organization_quick_actions.dart';
import 'package:quill_diary/presentation/diary_organization/organization_review.dart';
import 'package:quill_diary/presentation/editor/pages/editor_page.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_hybrid_body.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_markdown_preview.dart';
import 'package:quill_diary/shared/presentation/private_text_controller.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_segmented_choice_bar.dart';
import 'package:quill_diary/shared/presentation/widgets/private_text.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/diary_organization/failing_organization_store.dart';
import '../../helpers/diary_organization/organization_test_scope.dart';
import '../../helpers/shared/test_l10n.dart';

Widget _app(
  OrganizationTestScope scope,
  Widget page, {
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) => UncontrolledProviderScope(
  container: scope.container,
  child: MaterialApp(
    theme: appTestTheme(brightness: brightness),
    locale: appZhLocale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: page,
  ),
);

Future<void> _drainStorage(WidgetTester tester, Future<void> operation) async {
  var complete = false;
  Object? failure;
  unawaited(
    operation.then<void>(
      (_) {
        complete = true;
      },
      onError: (Object error) {
        failure = error;
        complete = true;
      },
    ),
  );
  await _waitForUi(tester, () => complete);
  if (failure != null) throw failure!;
}

Future<void> _waitForUi(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(ready(), isTrue, reason: '非同步畫面操作須可完成');
}

void main() {
  testWidgets('越界舊候選不顯示內容，返回聊天後保留需求並清除候選', (tester) async {
    final scope = (await tester.runAsync(
      () => OrganizationTestScope.create(),
    ))!;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await _drainStorage(tester, scope.dispose());
    });
    final draft = scope.controller.draft!..prepare();
    draft.originals['{{PRI_01}}'] = '其他分支的秘密';
    draft.appendTurn(OrganizationTurn(user: '舊需求 {{PRI_01}}'));
    draft.appendTurn(OrganizationTurn(user: '目前需求'));
    draft.organizedBody = '${draft.protectedSource} {{PRI_01}}';
    draft.generationReply = '不能沿用的舊說明';
    draft.stage = OrganizationStage.review;
    scope.settings.keys[draft.connection.credentialId] = 'synthetic-key';
    await tester.pumpWidget(
      _app(scope, DiaryOrganizationPage(entryId: scope.entry.id)),
    );
    await tester.pumpAndSettle();
    expect(find.text(testL10n.organizationUnsafeCandidate), findsOneWidget);
    expect(find.textContaining('其他分支的秘密'), findsNothing);
    expect(find.text(draft.generationReply!), findsNothing);
    expect(find.text(testL10n.organizationApply), findsNothing);
    await tester.tap(find.text(testL10n.organizationBack));
    await _waitForUi(
      tester,
      () => scope.controller.draft!.organizedBody == null,
    );
    expect(scope.controller.draft!.generationReply, isNull);
    expect(scope.controller.draft!.turns, hasLength(2));
    expect(scope.controller.draft!.stage, OrganizationStage.chat);
    expect(tester.takeException(), isNull);
  });

  testWidgets('整理說明可展開，切到背景與鎖定會關閉並遮蔽內容', (tester) async {
    final scope = (await tester.runAsync(
      () => OrganizationTestScope.create(),
    ))!;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await _drainStorage(tester, scope.dispose());
    });
    final draft = scope.controller.draft!..prepare();
    draft.replaceBody(draft.protectedSource);
    draft.generationReply = '已修順。';
    draft.stage = OrganizationStage.review;
    scope.settings.keys[draft.connection.credentialId] = 'synthetic-key';
    await tester.pumpWidget(
      _app(scope, DiaryOrganizationPage(entryId: scope.entry.id)),
    );
    await tester.pumpAndSettle();
    expect(find.text(testL10n.organizationReplyTitle), findsOneWidget);
    expect(find.text(testL10n.organizationShowReply), findsNothing);
    draft.generationReply = '保留原句並修順標點。' * 12;
    scope.controller.notifyListeners();
    await tester.pumpAndSettle();
    await tester.tap(find.text(testL10n.organizationShowReply));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialogShell), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.byType(AppDialogShell), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.scheduleForcedFrame();
    await tester.pump();
    expect(find.byType(AppDialogShell), findsNothing);
    expect(find.text(draft.generationReply!), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.tap(find.text(testL10n.organizationShowReply));
    await tester.pumpAndSettle();
    await _drainStorage(
      tester,
      scope.container.read(appSessionProvider.notifier).lock(),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppDialogShell), findsNothing);
    expect(find.text(draft.generationReply!), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('連線與輸入', () {
    for (final missingKey in [false, true]) {
      testWidgets('進入整理時${missingKey ? '缺少 API Key' : '缺少模型'}會開啟設定，取消後不重複跳出', (
        tester,
      ) async {
        final scope = (await tester.runAsync(
          () => OrganizationTestScope.create(),
        ))!;
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await _drainStorage(tester, scope.dispose());
        });
        scope.controller.draft!.connection = missingKey
            ? const AiConnectionConfig(
                provider: AiProvider.openai,
                model: 'test-model',
              )
            : scope.controller.draft!.connection.copyWith(model: '');
        await tester.pumpWidget(
          _app(scope, DiaryOrganizationPage(entryId: scope.entry.id)),
        );
        await _waitForUi(
          tester,
          () => find.byType(AiConnectionSettingsDialog).evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        expect(scope.client.calls, isEmpty);
        await tester.tap(
          find.descendant(
            of: find.byType(AiConnectionSettingsDialog),
            matching: find.widgetWithText(
              TextButton,
              testL10n.commonActionCancel,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AiConnectionSettingsDialog), findsNothing);
        expect(
          find.byKey(const ValueKey('organization-privacy-text')),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(AiConnectionSettingsDialog), findsNothing);
        await tester.runAsync(scope.controller.startChat);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('organization-composer')),
          '先準備整理需求',
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AiChatInputPanel>(find.byType(AiChatInputPanel))
              .canSend,
          isFalse,
        );
        final quickActions = tester.widgetList<OrganizationQuickActions>(
          find.byType(OrganizationQuickActions),
        );
        expect(quickActions.every((actions) => !actions.enabled), isTrue);
        expect(scope.controller.draft!.composer, '先準備整理需求');
        expect(scope.client.calls, isEmpty);
      });
    }
    testWidgets('設定補齊後更新整理連線，尚未送出 AI 請求', (tester) async {
      final scope = (await tester.runAsync(
        () => OrganizationTestScope.create(),
      ))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await _drainStorage(tester, scope.dispose());
      });
      final configured = scope.controller.draft!.connection;
      scope.controller.draft!.connection = configured.copyWith(model: '');
      await tester.pumpWidget(
        _app(scope, DiaryOrganizationPage(entryId: scope.entry.id)),
      );
      await _waitForUi(
        tester,
        () => find.byType(AiConnectionSettingsDialog).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      // 由設定視窗回傳已保存的連線，驗證頁面與 controller 的交接。
      Navigator.of(tester.element(find.byType(AiConnectionSettingsDialog)))
          .pop(AiConnectionSettingsResult(chatConnection: configured));
      await _waitForUi(
        tester,
        () => scope.controller.draft!.connection.model == configured.model,
      );
      await tester.pumpAndSettle();
      expect(scope.client.calls, isEmpty);
      expect(find.byType(AiConnectionSettingsDialog), findsNothing);
    });
    testWidgets('快捷可依序追加且保留未送出的私密文字，生成包含所有方向', (tester) async {
      final scope = (await tester.runAsync(
        () => OrganizationTestScope.create(body: '原始日記'),
      ))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await _drainStorage(tester, scope.dispose());
      });
      await tester.runAsync(scope.controller.startChat);
      scope.controller.updateComposer('未送出秘密', [const PrivateTextRange(3, 5)]);
      scope.client.output = '整理時會修順原文。';
      await tester.pumpWidget(
        _app(scope, DiaryOrganizationPage(entryId: scope.entry.id)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AiConnectionSettingsDialog), findsNothing);
      await tester.tap(find.byKey(const ValueKey('organization-quick-0')));
      await _waitForUi(tester, () => !scope.controller.busy);
      await tester.pumpAndSettle();
      final bar = find.byKey(const ValueKey('organization-quick-bar'));
      expect(bar, findsOneWidget);
      expect(
        tester.getRect(bar).bottom,
        lessThanOrEqualTo(
          tester
              .getRect(find.byKey(const ValueKey('organization-generate')))
              .top,
        ),
      );
      expect(scope.controller.draft!.composer, '未送出秘密');
      expect(scope.controller.draft!.composerRanges.single.toJson(), {
        'start': 3,
        'end': 5,
      });
      final stream = StreamController<String>();
      scope.client.response = () => stream.stream;
      await tester.tap(find.byKey(const ValueKey('organization-quick-2')));
      await _waitForUi(tester, () => scope.client.calls.length == 2);
      expect(
        tester
            .widget<InkWell>(find.byKey(const ValueKey('organization-quick-0')))
            .onTap,
        isNull,
      );
      stream.add('整理時會重排段落。');
      await _drainStorage(tester, stream.close());
      await _waitForUi(tester, () => !scope.controller.busy);
      await tester.pumpAndSettle();
      expect(scope.controller.draft!.turns, hasLength(2));
      expect(scope.controller.draft!.composer, '未送出秘密');
      await tester.enterText(
        find.byKey(const ValueKey('organization-composer')),
        '',
      );
      await tester.pump();
      scope.client.response = null;
      scope.client.output = jsonEncode({'reply': '已整理', 'body': '整理後日記'});
      await tester.tap(find.byKey(const ValueKey('organization-generate')));
      await _waitForUi(tester, () => !scope.controller.busy);
      await tester.pumpAndSettle();
      final requests = scope.client.calls.last.messages
          .where((m) => m.isUser)
          .map((m) => m.text);
      expect(
        requests,
        containsAll([
          testZhL10n.organizationPolishRequest,
          testZhL10n.organizationStructureRequest,
        ]),
      );
      await tester.tap(find.text('返回聊天'));
      await _waitForUi(tester, () => !scope.controller.busy);
      await tester.pumpAndSettle();
      expect(bar, findsOneWidget);
      await _drainStorage(tester, scope.controller.beginEditing(0));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<InkWell>(find.byKey(const ValueKey('organization-quick-0')))
            .onTap,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('整理輸入框可插入人物並送出隱藏姓名，編輯訊息也能再次使用', (tester) async {
      final scope = (await tester.runAsync(
        () => OrganizationTestScope.create(withPerson: true),
      ))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await _drainStorage(tester, scope.dispose());
      });
      await tester.runAsync(scope.controller.startChat);
      await tester.pumpWidget(
        _app(scope, DiaryOrganizationPage(entryId: scope.entry.id)),
      );
      await tester.pumpAndSettle();
      final surface = tester.getRect(
        find.byKey(const ValueKey('ai-composer-surface')),
      );
      final page = tester.getRect(find.byType(DiaryOrganizationPage));
      expect(
        (page.right - surface.right).round(),
        (surface.left - page.left).round(),
      );
      final composer = find.byKey(const ValueKey('organization-composer'));
      await tester.enterText(composer, '請保留@小明');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, '王小明'));
      await tester.pumpAndSettle();
      expect(scope.controller.draft!.composer, '請保留王小明');
      scope.client.output = '整理時會保留**{{PER_01}}**。';
      await tester.tap(find.byTooltip('送出'));
      await _waitForUi(tester, () => !scope.controller.busy);
      await tester.pumpAndSettle();
      expect(
        scope.client.calls.single.messages.last.text,
        isNot(contains('王小明')),
      );
      expect(scope.client.calls.single.messages.last.text, contains('{{PER'));
      final reply = tester.widget<PrivateText>(
        find.descendant(
          of: find.byKey(
            const ValueKey('ai-message-body-organization-assistant-0'),
          ),
          matching: find.byType(PrivateText),
        ),
      );
      expect(reply.text, '整理時會保留王小明。');
      expect(
        reply.ranges
            .map((range) => reply.text.substring(range.start, range.end))
            .join(),
        '王小明',
      );
      await _drainStorage(tester, scope.controller.beginEditing(0));
      await tester.pumpAndSettle();
      await tester.enterText(composer, '改成@小');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, '王小明'));
      await tester.pumpAndSettle();
      expect(scope.controller.draft!.composer, '改成王小明');
      await _drainStorage(tester, scope.controller.persist());
    });
    testWidgets('人名與個資高亮，開始整理後改成代號', (tester) async {
      final scope = (await tester.runAsync(
        () => OrganizationTestScope.create(
          withPerson: true,
          body: '今天和王小明散步。王小明說天氣很好。a+b@example.org',
        ),
      ))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await _drainStorage(tester, scope.dispose());
      });
      await tester.pumpWidget(
        _app(scope, DiaryOrganizationPage(entryId: scope.entry.id)),
      );
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('organization-privacy-text')),
      );
      final controller = field.controller! as PrivateTextController;
      expect(controller.privateRanges, isEmpty);
      expect(
        controller.highlightRanges.map(
          (range) => controller.text.substring(range.start, range.end),
        ),
        ['王小明', '王小明', 'a+b@example.org'],
      );
      scope.client.output = '想保留原本的語氣嗎？';
      await tester.tap(find.text('開始整理'));
      await _waitForUi(
        tester,
        () =>
            !scope.controller.busy &&
            scope.controller.draft!.stage == OrganizationStage.chat,
      );
      expect(scope.client.calls, isEmpty);
      await tester.pumpAndSettle();
      expect(find.text('語句潤飾'), findsOneWidget);
      expect(find.text('內容精簡'), findsOneWidget);
      expect(find.text('段落整理'), findsOneWidget);
      expect(find.text(testL10n.organizationElaborate), findsOneWidget);
      expect(find.textContaining('今天和王小明散步。'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('organization-quick-0')));
      await _waitForUi(tester, () => !scope.controller.busy);
      await tester.pumpAndSettle();
      final outbound = scope.client.calls.single.prompt;
      expect(
        tester
            .widget<OrganizationQuickActions>(
              find.byType(OrganizationQuickActions),
            )
            .compact,
        isTrue,
      );
      expect(outbound, isNot(contains('王小明')));
      expect(outbound, isNot(contains('a+b@example.org')));
      await _drainStorage(tester, scope.controller.persist());
    });
    testWidgets('窄畫面放大文字時可開始整理，方向卡片從頂端呈現', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scope = (await tester.runAsync(
        () => OrganizationTestScope.create(),
      ))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await _drainStorage(tester, scope.dispose());
      });
      await tester.pumpWidget(
        _app(
          scope,
          DiaryOrganizationPage(entryId: scope.entry.id),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('開始整理'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('開始整理'));
      await _waitForUi(tester, () => !scope.controller.busy);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text(testL10n.organizationChooseDirection)).dy,
        greaterThan(0),
      );
      await tester.ensureVisible(find.text(testL10n.organizationElaborate));
      expect(tester.takeException(), isNull);
    });
    testWidgets('整理回覆無法採用時進度卡消失，錯誤留在畫面內', (tester) async {
      final scope = (await tester.runAsync(
        () => OrganizationTestScope.create(),
      ))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await _drainStorage(tester, scope.dispose());
      });
      await tester.runAsync(scope.controller.startChat);
      scope.client.output = List.filled(40, '這一行會把對話捲到底部。').join('\n');
      scope.controller.updateComposer('修順', []);
      await tester.runAsync(scope.controller.sendMessage);
      await tester.pumpWidget(
        _app(scope, DiaryOrganizationPage(entryId: scope.entry.id)),
      );
      await tester.pumpAndSettle();
      scope.client.output = '錯誤的 JSON';
      await tester.tap(find.byKey(const ValueKey('organization-generate')));
      await _waitForUi(tester, () => !scope.controller.busy);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('organization-generation-card')),
        findsNothing,
      );
      final error = find.byKey(const ValueKey('organization-generation-error'));
      expect(error, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('organization-conversation')),
          matching: error,
        ),
        findsNothing,
      );
      expect(tester.widget<Text>(error).data, testL10n.aiErrorResponse);
      final rect = tester.getRect(error);
      final viewHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(viewHeight));
      expect(
        find.byKey(const ValueKey('organization-composer')),
        findsOneWidget,
      );
      expect(scope.controller.draft!.stage, OrganizationStage.chat);
      expect(scope.controller.draft!.organizedBody, isNull);
    });
  });

  group('預覽與編輯', () {
    testWidgets('預覽同時列出兩種系統提示詞，生成使用底部進度面板，查看修改沒有頂部操作', (tester) async {
      final scope = (await tester.runAsync(
        () => OrganizationTestScope.create(),
      ))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await _drainStorage(tester, scope.dispose());
      });
      scope.controller.updatePrivacy([const PrivateTextRange(3, 6)]);
      await tester.runAsync(scope.controller.startChat);
      await tester.pumpWidget(
        _app(scope, DiaryOrganizationPage(entryId: scope.entry.id)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuButton<bool>), findsNothing);
      expect(find.byTooltip('查看送給 AI 的內容'), findsOneWidget);
      expect(find.byTooltip('刪除整理對話'), findsOneWidget);
      scope.controller.updateComposer('私人需求', [const PrivateTextRange(0, 2)]);
      await tester.tap(find.byTooltip('查看送給 AI 的內容'));
      await _waitForUi(
        tester,
        () => find.byType(AiRequestPreviewDialog).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-request-original')), findsOneWidget);
      final dialog = tester.widget<AiRequestPreviewDialog>(
        find.byType(AiRequestPreviewDialog),
      );
      final chatTitle = testL10n.aiPreviewSystemLabel(
        testL10n.aiRequestPreviewChat,
      );
      final generationTitle = testL10n.aiPreviewSystemLabel(
        testL10n.organizationGenerate,
      );
      expect(find.text(chatTitle), findsOneWidget);
      expect(find.text(generationTitle), findsOneWidget);
      expect(find.text(testL10n.chatDiaryPreviewPending), findsOneWidget);
      expect(scope.client.calls, isEmpty);
      final jsonCard = find.byKey(const ValueKey('ai-request-json'));
      await tester.tap(jsonCard);
      await tester.pumpAndSettle();
      expect(find.text(testL10n.aiRequestPreviewJsonHint), findsOneWidget);
      final jsonText = tester
          .widget<PrivateText>(
            find.descendant(of: jsonCard, matching: find.byType(PrivateText)),
          )
          .text;
      final json = jsonDecode(jsonText) as Map;
      final chatJson = json['chat'] as Map;
      final generationJson = json['generation'] as Map;
      expect(chatJson['prompt'], chatTitle);
      expect(generationJson['prompt'], generationTitle);
      expect(chatJson['messages'], [
        {
          'role': 'user',
          'text': dialog.preview.effective().turns.single.text,
          'pending': true,
        },
      ]);
      expect(generationJson['messages'], isEmpty);
      expect(
        chatJson['diary_body'],
        dialog.preview.effective().diaryContext!.diaryBody,
      );
      expect(
        generationJson['diary_body'],
        dialog.generationPreview!.effective().diaryContext!.diaryBody,
      );
      expect(jsonText, isNot(contains('私人')));
      expect(jsonText, isNot(contains('今天和王小明')));
      await tester.tap(find.widgetWithText(TextButton, '關閉'));
      await tester.pumpAndSettle();
      scope.controller.updateComposer('', []);
      scope.client.output = '會修順文字。';
      await tester.tap(find.byKey(const ValueKey('organization-quick-0')));
      await _waitForUi(tester, () => !scope.controller.busy);
      await tester.pumpAndSettle();
      final stream = StreamController<String>();
      scope.client.response = () => stream.stream;
      await tester.tap(find.byKey(const ValueKey('organization-generate')));
      await _waitForUi(tester, () => scope.client.calls.length == 2);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('organization-generation-card')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('organization-composer')), findsNothing);
      IconButton buttonOf(String tooltip) => tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        ),
      );
      expect(buttonOf('查看送給 AI 的內容').onPressed, isNotNull);
      expect(buttonOf('刪除整理對話').onPressed, isNull);
      await tester.tap(find.byTooltip('查看送給 AI 的內容'));
      await _waitForUi(
        tester,
        () => find.byType(AiRequestPreviewDialog).evaluate().isNotEmpty,
      );
      final sendingPreview = tester.widget<AiRequestPreviewDialog>(
        find.byType(AiRequestPreviewDialog),
      );
      expect(sendingPreview.preview.turns, isNotEmpty);
      expect(
        sendingPreview.preview.turns.every((turn) => !turn.pending),
        isTrue,
      );
      expect(scope.controller.busy, isTrue);
      expect(scope.client.calls, hasLength(2));
      await tester.tap(find.widgetWithText(TextButton, '關閉'));
      await _waitForUi(
        tester,
        () => find.byType(AiRequestPreviewDialog).evaluate().isEmpty,
      );
      await tester.tap(find.text('停止生成'));
      await tester.pumpAndSettle();
      stream.add(jsonEncode({'reply': '晚到', 'body': '不應採用'}));
      await _drainStorage(tester, stream.close());
      expect(scope.controller.draft!.organizedBody, isNull);
      scope.client.response = null;
      scope.client.output = jsonEncode({
        'reply': '完成',
        'body': '${scope.controller.draft!.protectedSource}，整理後的文字。',
      });
      await tester.tap(find.byKey(const ValueKey('organization-generate')));
      await _waitForUi(tester, () => !scope.controller.busy);
      await tester.pumpAndSettle();
      expect(find.text('查看修改'), findsOneWidget);
      expect(find.byType(DropdownButton<int>), findsNothing);
      expect(find.byTooltip('查看送給 AI 的內容'), findsNothing);
      expect(find.byTooltip('刪除整理對話'), findsNothing);
      expect(scope.controller.draft!.turns, hasLength(1));
      expect(tester.takeException(), isNull);
    });
    testWidgets('手動編輯沿用圓角對話框，大字與鍵盤可操作，返回聊天刪除候選稿', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final scope = (await tester.runAsync(
        () => OrganizationTestScope.create(body: '原文'),
      ))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await _drainStorage(tester, scope.dispose());
      });
      final draft = scope.controller.draft!..prepare();
      draft.originals['{{PER_01}}'] = '其他分支的稱呼';
      draft.appendTurn(OrganizationTurn(user: '舊需求 {{PER_01}}'));
      draft.appendTurn(
        OrganizationTurn(
          user: '新需求 {{PER_01}}',
          surfaces: {
            '{{PER_01}}': ['目前稱呼'],
          },
        ),
      );
      draft.replaceBody('整理後的內容 {{PER_01}}');
      draft.stage = OrganizationStage.review;
      await tester.pumpWidget(
        _app(
          scope,
          DiaryOrganizationPage(entryId: scope.entry.id),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('手動編輯'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialogShell), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.getSize(find.byType(AlertDialog)).width, closeTo(288, 0.1));
      final double cardHeight = tester
          .getSize(
            find
                .descendant(
                  of: find.byType(AlertDialog),
                  matching: find.byType(Material),
                )
                .first,
          )
          .height;
      expect(cardHeight, closeTo(700 * appDialogMaxHeightFactor, 1));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('organization-draft-editor')))
            .height,
        greaterThan(cardHeight * 0.5),
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('organization-draft-editor')),
            )
            .controller!
            .text,
        '整理後的內容 目前稱呼',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.enterText(
        find.byKey(const ValueKey('organization-draft-editor')),
        '手動修改的候選內容 目前稱呼',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.widgetWithText(FilledButton, testL10n.commonActionConfirm),
      );
      await _waitForUi(tester, () => !scope.controller.busy);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(scope.controller.draft!.organizedBody, '手動修改的候選內容 {{PER_01}}');
      await tester.tap(find.text('返回聊天'));
      await _waitForUi(tester, () => !scope.controller.busy);
      await tester.pumpAndSettle();
      expect(scope.controller.draft!.organizedBody, isNull);
      expect(scope.controller.draft!.stage, OrganizationStage.chat);
      expect(find.text('目前整理稿'), findsNothing);
      expect(find.text('查看修改'), findsNothing);
      expect(draft.source.markdownBody, '原文');
      expect(tester.takeException(), isNull);
    });
    for (final brightness in Brightness.values) {
      testWidgets(
        '${brightness == Brightness.light ? '亮色' : '暗色'}對比採逐行呈現，切到全文使用唯讀日記排版',
        (tester) async {
          final scope = (await tester.runAsync(
            () => OrganizationTestScope.create(body: '## 原標題\n今天散步。'),
          ))!;
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            await _drainStorage(tester, scope.dispose());
          });
          final draft = scope.controller.draft!;
          draft.prepare();
          draft.replaceBody('## 整理標題\n今天去散步。\n- [ ] 任務');
          draft.stage = OrganizationStage.review;
          await tester.pumpWidget(
            _app(
              scope,
              DiaryOrganizationPage(entryId: scope.entry.id),
              brightness: brightness,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AppSegmentedChoiceBar<bool>), findsOneWidget);
          expect(find.byType(ChoiceChip), findsNothing);
          expect(find.text('刪除'), findsNothing);
          expect(find.text('新增'), findsNothing);
          expect(find.text('−'), findsWidgets);
          expect(find.text('+'), findsWidgets);
          final buttons = find.byType(OutlinedButton);
          expect(buttons, findsNWidgets(3));
          final first = tester.getRect(buttons.at(0));
          for (var i = 1; i < 3; i++) {
            final rect = tester.getRect(buttons.at(i));
            expect(rect.top, first.top);
            expect(rect.size, first.size);
          }
          expect(find.text('確定修改'), findsOneWidget);
          await tester.tap(find.text('整理後全文'));
          await tester.pumpAndSettle();
          final preview = tester.widget<EditorMarkdownPreview>(
            find.byType(EditorMarkdownPreview),
          );
          expect(preview.interactiveCheckboxes, isFalse);
          expect(preview.onMarkdownChanged, isNull);
          expect(find.text('整理標題', findRichText: true), findsOneWidget);
          expect(find.byType(OrganizationDiffView), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets('窄畫面放大文字時三顆操作等寬直排，對比與全文皆不溢出', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scope = (await tester.runAsync(
        () => OrganizationTestScope.create(),
      ))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await _drainStorage(tester, scope.dispose());
      });
      final draft = scope.controller.draft!;
      draft.prepare();
      draft.replaceBody('今天一起去散步，天氣非常舒服。' * 20);
      draft.stage = OrganizationStage.review;
      await tester.pumpWidget(
        _app(
          scope,
          DiaryOrganizationPage(entryId: scope.entry.id),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      final buttons = find.byType(OutlinedButton);
      final first = tester.getRect(buttons.at(0));
      for (var i = 1; i < 3; i++) {
        final rect = tester.getRect(buttons.at(i));
        expect(rect.left, first.left);
        expect(rect.width, first.width);
        expect(rect.height, first.height);
        expect(rect.top, greaterThan(tester.getRect(buttons.at(i - 1)).bottom));
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('整理後全文'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('套用', () {
    testWidgets('套用寫入失敗時留在對比頁並保留整理稿', (tester) async {
      final scope = (await tester.runAsync(
        () => OrganizationTestScope.create(
          overrides: [
            diaryOrganizationStoreProvider.overrideWith(
              (ref) => FailingOrganizationStore(
                paths: ref.watch(vaultPathStrategyProvider),
                crypto: ref.watch(cryptoServiceProvider),
                repository: ref.watch(vaultRepositoryProvider),
              ),
            ),
          ],
        ),
      ))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await _drainStorage(tester, scope.dispose());
      });
      final draft = scope.controller.draft!;
      draft.prepare();
      draft.replaceBody('有效的整理稿');
      draft.stage = OrganizationStage.review;
      await tester.pumpWidget(
        _app(scope, DiaryOrganizationPage(entryId: scope.entry.id)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('確定修改'));
      await tester.pump();
      await _waitForUi(tester, () => !scope.controller.busy);
      await tester.pumpAndSettle();
      expect(scope.controller.busy, isFalse);
      expect(scope.controller.error, isNotNull);
      expect(find.text('查看修改'), findsOneWidget);
      expect(scope.controller.draft!.restoredBody, '有效的整理稿');
      final saved = await tester.runAsync(
        () => scope.harness.repository.loadEntry(
          scope.setup.session,
          scope.entry.id,
        ),
      );
      expect(saved!.markdownBody, scope.entry.markdownBody);
    });
    testWidgets('套用後立即更新、延遲重讀不回復舊稿，取消編輯及重開仍顯示新稿', (tester) async {
      Completer<void>? readGate;
      final scope = (await tester.runAsync(
        () => OrganizationTestScope.create(
          widgetMode: true,
          overrides: [
            entryProvider.overrideWith((ref, id) async {
              ref.watch(diaryRevisionProvider);
              final session = await ref.watch(
                activeVaultSessionProvider.future,
              );
              if (session == null) return null;
              await readGate?.future;
              return ref.read(vaultRepositoryProvider).loadEntry(session, id);
            }),
          ],
        ),
      ))!;
      await tester.runAsync(() async {
        await scope.controller.startChat();
        scope.controller.updateComposer('修順語句', []);
        await scope.controller.sendMessage();
        scope.client.output = jsonEncode({
          'reply': '完成',
          'body': '這是整理後的日記內容。',
        });
        await scope.controller.generateDraft().timeout(
          const Duration(seconds: 8),
        );
        await scope.container
            .read(entryProvider(scope.entry.id).future)
            .timeout(const Duration(seconds: 8));
        await scope.container
            .read(recoveryMetadataProvider.future)
            .timeout(const Duration(seconds: 8));
      });
      final router = AppRouter.createRouter()..go('/editor/${scope.entry.id}');
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        if (readGate != null && !readGate.isCompleted) readGate.complete();
        await _drainStorage(
          tester,
          Future.wait([
            scope.container.read(entryProvider(scope.entry.id).future),
            scope.container.read(recoveryMetadataProvider.future),
          ]).then<void>((_) {}),
        );
        await _drainStorage(tester, scope.dispose());
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope.container,
          child: MaterialApp.router(
            theme: appTestTheme(),
            locale: appZhLocale,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('日記 AI 功能'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('entry-ai-organize')));
      await tester.pumpAndSettle();
      expect(find.text('修改對比'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('organization-apply')),
            )
            .onPressed,
        isNotNull,
        reason:
            'conflict=${scope.controller.conflict}, editor=${scope.controller.editorDraftExists}, busy=${scope.controller.busy}',
      );
      readGate = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('organization-apply')));
      await tester.pump();
      expect(scope.controller.busy, isTrue);
      await _waitForUi(tester, () => !scope.controller.busy);
      expect(scope.controller.busy, isFalse);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/editor/${scope.entry.id}',
      );
      expect(
        find.textContaining('這是整理後的日記內容。', findRichText: true),
        findsWidgets,
      );
      expect(
        scope.container.read(entryProvider(scope.entry.id)).isLoading,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('editor-top-bar-edit')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditorHybridBody>(find.byType(EditorHybridBody))
            .bodyController
            .text,
        '這是整理後的日記內容。',
      );
      await tester.tap(find.byKey(const Key('editor-top-bar-close')));
      await tester.pump();
      await _waitForUi(
        tester,
        () => find.byType(EditorMarkdownPreview).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(find.byType(EditorMarkdownPreview), findsOneWidget);
      expect(
        find.textContaining('這是整理後的日記內容。', findRichText: true),
        findsWidgets,
      );
      readGate.complete();
      await _drainStorage(
        tester,
        scope.container
            .read(entryProvider(scope.entry.id).future)
            .then<void>((_) {}),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('這是整理後的日記內容。', findRichText: true),
        findsWidgets,
      );
      router.go('/settings/personalization');
      await tester.pumpAndSettle();
      router.go('/editor/${scope.entry.id}');
      await tester.pumpAndSettle();
      expect(find.byType(EditorPage), findsOneWidget);
      expect(
        find.textContaining('這是整理後的日記內容。', findRichText: true),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
