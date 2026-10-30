import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/session/app_session_controller.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_hidden_text.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_message_bubble.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_page.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_private_text_controller.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/widgets/app_image_gallery_dialog.dart';

import '../../helpers/ai/ai_test_helpers.dart';
import '../../helpers/shared/widget_test_app.dart';

class _ChatPreferences extends UserPreferences {
  @override
  Future<AppLanguage> get appLocale async => AppLanguage.zh;
  @override
  Future<PersonalizationPreferences> loadPersonalizationPreferences() async =>
      PersonalizationPreferences.defaults;
}

class _ChatSession extends AppSessionController {
  @override
  AppSessionState build() => const AppSessionState(
    status: AppLockStatus.unlocked,
    session: UnlockedVaultSession(vaultId: 'vault', trustedDevice: true),
  );
  void setLocked() =>
      state = const AppSessionState(status: AppLockStatus.locked);
}

class _ImageChatDiaryStore extends OverviewChatDiaryStore {
  _ImageChatDiaryStore(super.initialChat);

  @override
  Future<void> saveImage(
    String chatId,
    ChatDiaryImage image,
    Uint8List bytes,
    UnlockedVaultSession session,
  ) async {
    images[image.id] = bytes;
  }
}

class _PickedImageFile implements File {
  @override
  String get path => 'image.png';

  @override
  Future<Uint8List> readAsBytes() async => testAiPng;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  void resumeApp(WidgetTester tester) {
    if (tester.binding.lifecycleState == AppLifecycleState.paused) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    }
    if (tester.binding.lifecycleState == AppLifecycleState.hidden) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  Completer<List<String>> mockGalleryPicker(WidgetTester tester) {
    const channel = MethodChannel('plugins.flutter.io/image_picker');
    final result = Completer<List<String>>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => switch (call.method) {
        'retrieve' => null,
        'pickMultiImage' => result.future,
        _ => throw StateError('非預期的選圖呼叫：${call.method}'),
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    addTearDown(() => resumeApp(tester));
    return result;
  }

  Future<ProviderContainer> pumpChat(
    WidgetTester tester,
    ChatDiarySession chat,
    FakeAiClient client, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
    Locale locale = const Locale('zh'),
    bool withBack = false,
    OverviewChatDiaryStore? store,
    OverviewAiSettingsStore? aiSettings,
    EditorDraftStore? editorDrafts,
  }) async {
    final container = ProviderContainer(
      overrides: [
        if (editorDrafts != null)
          editorDraftStoreProvider.overrideWithValue(editorDrafts),
        chatDiaryStoreProvider.overrideWithValue(
          store ?? OverviewChatDiaryStore(chat),
        ),
        appSessionProvider.overrideWith(_ChatSession.new),
        aiSettingsStoreProvider.overrideWithValue(
          aiSettings ?? OverviewAiSettingsStore(),
        ),
        aiClientFactoryProvider.overrideWithValue((_, _) => client),
        userPreferencesProvider.overrideWithValue(_ChatPreferences()),
      ],
    );
    addTearDown(container.dispose);
    final page = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: ChatDiaryPage(chatId: chat.id),
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: widgetTestApp(
          brightness: brightness,
          locale: locale,
          wrapScaffold: false,
          center: false,
          child: withBack
              ? Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      await Navigator.of(context)
                          .push<void>(MaterialPageRoute(builder: (_) => page));
                    },
                    child: const Text('開啟聊天室'),
                  ),
                )
              : page,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (withBack) {
      await tester.tap(find.text('開啟聊天室'));
      await tester.pumpAndSettle();
    }
    return container;
  }

  testWidgets('長對話只建立可見訊息，輸入及捲動不建立全部泡泡', (tester) async {
    final chat = testChatDiarySession(hidePersonNames: false);
    for (var index = 0; index < 120; index++) {
      chat.appendMessage(
        ChatDiaryMessage(
          id: generateChatDiaryMessageId(),
          isUser: index.isEven,
          text: '訊息 $index\n這是對話內容。',
          outboundText: '訊息 $index',
          parentId: chat.activeMessages.lastOrNull?.id,
        ),
      );
    }
    await pumpChat(tester, chat, FakeAiClient(chat.connectionConfig));
    expect(find.byType(ChatDiaryMessageBubble).evaluate().length, lessThan(30));
    expect(find.byKey(ValueKey(chat.messages.last.id)), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('chat-diary-composer')),
      '新的輸入',
    );
    await tester.pumpAndSettle();
    expect(find.byType(ChatDiaryMessageBubble).evaluate().length, lessThan(30));
    final list = tester.widget<ListView>(find.byType(ListView).first);
    list.controller!.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey(chat.messages.first.id)), findsOneWidget);
    expect(find.byKey(ValueKey(chat.messages.last.id)), findsNothing);
  });

  testWidgets('聊天室編輯可取消恢復輸入，中文組字維持私密並建立可切換的版本', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chat = testChatDiarySession(hidePersonNames: false)
      ..composerText = '原本尚未送出的話';
    for (final message in [
      ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: '原本秘密',
        outboundText: '原本秘密',
        privateRanges: [const ChatDiaryPrivateRange(2, 4)],
      ),
      ChatDiaryMessage(
        id: 'reply',
        isUser: false,
        text: '你想記得哪一個細節？',
        outboundText: '你想記得哪一個細節？',
      ),
    ]) {
      chat.appendMessage(
        message..parentId = chat.activeMessages.lastOrNull?.id,
      );
    }
    final client = FakeAiClient(chat.connectionConfig)..output = '**新的回覆**';
    final container = await pumpChat(tester, chat, client);
    final sent = tester.widget<Text>(find.text('原本秘密'));
    final highlight = chatDiaryHiddenHighlight(
      Theme.of(tester.element(find.text('原本秘密'))).colorScheme,
    );
    expect(
      (sent.textSpan! as TextSpan).children!.cast<TextSpan>().any(
        (span) => span.text == '秘密' && span.style?.backgroundColor == highlight,
      ),
      isTrue,
    );
    final field = find.byKey(const ValueKey('chat-diary-composer'));
    await tester.tap(find.byTooltip('編輯訊息'));
    await tester.pumpAndSettle();
    final input =
        tester.widget<TextField>(field).controller!
            as ChatDiaryPrivateTextController;
    expect(input.text, '原本秘密');
    expect(input.privateRanges.single.start, 2);
    input.value = const TextEditingValue(
      text: '原本秘密ㄇ',
      selection: TextSelection.collapsed(offset: 5),
      composing: TextRange(start: 4, end: 5),
    );
    await tester.pump();
    expect(input.privateRanges.single.end, 5);
    final span = input.buildTextSpan(
      context: tester.element(field),
      withComposing: true,
    );
    expect(
      span.children!.cast<TextSpan>().any(
        (span) =>
            span.style?.decoration == TextDecoration.underline &&
            span.style?.backgroundColor != null,
      ),
      isTrue,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(input.text, '原本尚未送出的話');
    await tester.tap(find.byTooltip('編輯訊息'));
    await tester.pumpAndSettle();
    await tester.enterText(field, '改寫的新片段');
    await tester.tap(find.byTooltip('編輯並送出'));
    await tester.pumpAndSettle();
    expect(input.text, '原本尚未送出的話');
    expect(find.text('2 / 2'), findsOneWidget);
    final controller = container.read(chatDiaryControllerProvider(chat.id));
    expect(controller.chat!.activeMessages.first.text, '改寫的新片段');
    await tester.tap(find.byTooltip('上一個版本'));
    await tester.pumpAndSettle();
    expect(controller.chat!.activeMessages.first.text, '原本秘密');
    expect(client.calls, hasLength(1));
    expect(find.text('你想記得哪一個細節？'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('錯誤只在對應回覆呈現，重試保留失敗版本並顯示新回覆', (tester) async {
    final chat = testChatDiarySession(hidePersonNames: false);
    final client = FakeAiClient(chat.connectionConfig)
      ..failure = const AiFailure(AiErrorCode.network);
    final container = await pumpChat(tester, chat, client);
    await tester.enterText(find.byType(TextField), '測試片段');
    await tester.pump();
    await tester.tap(find.byTooltip('送出'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final state = container.read(chatDiaryControllerProvider(chat.id));
    expect(
      state.busy,
      isFalse,
      reason:
          'calls=${client.calls.length}, error=${state.error}, messages=${state.chat!.activeMessages.map((m) => m.status).toList()}',
    );
    final error = container.read(chatDiaryControllerProvider(chat.id)).error;
    expect(error, AiErrorCode.network);
    expect(find.text('無法連線或連線已中斷，內容已保留，可稍後重試。'), findsOneWidget);
    expect(find.byTooltip('重試回覆'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '編輯訊息'), findsNothing);
    client.failure = null;
    client.output = '這個片段最想留下什麼？';
    await tester.tap(find.byTooltip('重試回覆'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('這個片段最想留下什麼？'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('對 AI 隱藏按鈕位於附件旁並可隱藏與取消選取文字，預覽只顯示聊天且系統指令收合', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chat = testChatDiarySession(hidePersonNames: false)
      ..composerText = '公開秘密';
    final client = FakeAiClient(chat.connectionConfig);
    final container = await pumpChat(tester, chat, client);
    final input =
        tester.widget<TextField>(find.byType(TextField)).controller!
            as ChatDiaryPrivateTextController;
    input.selection = const TextSelection(baseOffset: 2, extentOffset: 4);
    await tester.pump();
    final hide = find.byTooltip('對 AI 隱藏');
    expect(
      tester.getCenter(hide).dy,
      tester.getCenter(find.byTooltip('加入圖片')).dy,
    );
    expect(find.byIcon(Icons.shield_outlined), findsNothing);
    await tester.tap(hide);
    await tester.pump();
    expect(input.privateRanges.map((r) => (r.start, r.end)), [(2, 4)]);
    await tester.tap(find.byTooltip('取消隱藏'));
    await tester.pump();
    expect(input.privateRanges, isEmpty);
    input.selection = const TextSelection(baseOffset: 2, extentOffset: 4);
    await tester.pump();
    await tester.tap(find.byTooltip('對 AI 隱藏'));
    await tester.pump();
    await tester.tap(find.byTooltip('查看送給 AI 的內容'));
    await tester.pumpAndSettle();
    expect(find.text('系統提示詞'), findsOneWidget);
    expect(find.text('日記生成'), findsNothing);
    expect(find.textContaining('你是 Quill Diary 的日記聊天夥伴'), findsNothing);
    final preview = find.byType(AlertDialog);
    expect(
      find.descendant(of: preview, matching: find.text('你')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: preview, matching: find.text('尚未送出')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: preview, matching: find.textContaining('公開⟦S')),
      findsOneWidget,
    );
    final previewText = tester.widget<SelectableText>(
      find.descendant(of: preview, matching: find.byType(SelectableText)),
    );
    final previewHighlight = chatDiaryHiddenHighlight(
      Theme.of(tester.element(preview)).colorScheme,
    );
    expect(
      previewText.textSpan!.children!.cast<TextSpan>().any(
        (span) =>
            chatDiaryPrivacyTokenPattern.hasMatch(span.text ?? '') &&
            span.style?.backgroundColor == previewHighlight,
      ),
      isTrue,
    );
    await tester.tap(find.text('系統提示詞'));
    await tester.pumpAndSettle();
    expect(find.textContaining('你是 Quill Diary 的日記聊天夥伴'), findsOneWidget);
    await tester.tap(find.text('關閉'));
    await tester.pumpAndSettle();
    expect(client.calls, isEmpty);
    await container.read(chatDiaryControllerProvider(chat.id)).persist();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('傳送預覽把照片留在原訊息，並顯示完成回覆與尚未送出的內容', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chat = testChatDiarySession(hidePersonNames: false);
    final sentImage = generateAssetId();
    final pendingImage = generateAssetId();
    chat.images.addAll([
      ChatDiaryImage(
        id: sentImage,
        mimeType: 'image/png',
        filename: 'sent.png',
      ),
      ChatDiaryImage(
        id: pendingImage,
        mimeType: 'image/png',
        filename: 'pending.png',
      ),
    ]);
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: '想記住這張照片',
        outboundText: '想記住這張照片',
        imageIds: [sentImage],
      ),
    );
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'reply',
        parentId: 'user',
        isUser: false,
        text: '這段值得留下',
        outboundText: '這段值得留下',
      ),
    );
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'failed',
        parentId: 'reply',
        isUser: false,
        text: '這段失敗不會送出',
        outboundText: '這段失敗不會送出',
        status: ChatDiaryMessageStatus.failed,
      ),
    );
    chat.composerText = '還沒送出';
    chat.pendingImageIds.add(pendingImage);
    final store = OverviewChatDiaryStore(chat);
    store.images[sentImage] = testAiPng;
    store.images[pendingImage] = testAiPng;
    await pumpChat(
      tester,
      chat,
      FakeAiClient(chat.connectionConfig),
      store: store,
    );
    await tester.tap(find.byTooltip('查看送給 AI 的內容'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('這段失敗不會送出')),
      findsNothing,
    );
    final you = find.descendant(of: dialog, matching: find.text('你'));
    final assistant = find.descendant(of: dialog, matching: find.text('AI'));
    expect(you, findsWidgets);
    expect(assistant, findsOneWidget);
    final pendingTag = find.descendant(of: dialog, matching: find.text('尚未送出'));
    expect(pendingTag, findsOneWidget);
    expect(
      tester.getCenter(you.first).dx,
      greaterThan(tester.getCenter(assistant).dx),
    );
    expect(
      tester.getCenter(pendingTag).dx,
      lessThan(tester.getCenter(you.last).dx),
    );
    expect(
      tester.getCenter(pendingTag).dx,
      greaterThan(tester.getCenter(assistant).dx),
    );
    final images = find.descendant(of: dialog, matching: find.byType(Image));
    expect(images, findsNWidgets(2));
    final userText = find.descendant(
      of: dialog,
      matching: find.text('想記住這張照片'),
    );
    final reply = find.descendant(of: dialog, matching: find.text('這段值得留下'));
    final pending = find.descendant(of: dialog, matching: find.text('還沒送出'));
    expect(
      (tester.getCenter(pendingTag).dy - tester.getCenter(you.last).dy).abs(),
      lessThan(12),
    );
    expect(
      tester.getTopLeft(you.last).dx - tester.getTopRight(pendingTag).dx,
      lessThan(20),
    );
    expect(
      tester.getTopLeft(userText).dx,
      greaterThan(tester.getTopLeft(reply).dx),
    );
    expect(
      tester.getBottomLeft(images.first).dy,
      lessThan(tester.getTopLeft(userText).dy),
    );
    expect(
      tester.getBottomLeft(userText).dy,
      lessThan(tester.getTopLeft(reply).dy),
    );
    expect(
      tester.getBottomLeft(reply).dy,
      lessThan(tester.getTopLeft(images.last).dy),
    );
    expect(
      tester.getBottomLeft(images.last).dy,
      lessThan(tester.getTopLeft(pending).dy),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('傳送預覽的長文字在泡泡寬度內換行', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chat = testChatDiarySession(hidePersonNames: false)
      ..composerText = '很長的內容' * 30;
    await pumpChat(tester, chat, FakeAiClient(chat.connectionConfig));
    await tester.tap(find.byTooltip('查看送給 AI 的內容'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final bubble = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.textContaining('很長的內容'),
    );
    expect(bubble, findsOneWidget);
    expect(tester.getSize(bubble).width, lessThan(360));
    expect(tester.getSize(bubble).height, greaterThan(40));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('使用者與 AI 訊息可複製文字，按鈕在編輯前並以 toast 回報', (tester) async {
    final copiedTexts = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedTexts.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final chat = testChatDiarySession(hidePersonNames: false);
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: '想留下的秘密',
        outboundText: '想留下的⟦S01⟧',
      ),
    );
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'reply',
        parentId: 'user',
        isUser: false,
        text: '**值得記住的片段**',
        outboundText: '**值得記住的片段**',
      ),
    );
    await pumpChat(tester, chat, FakeAiClient(chat.connectionConfig));
    final copyButtons = find.byTooltip('複製');
    expect(copyButtons, findsNWidgets(2));
    expect(
      tester.getCenter(copyButtons.first).dx,
      lessThan(tester.getCenter(find.byTooltip('編輯訊息')).dx),
    );
    await tester.tap(copyButtons.first);
    await tester.pumpAndSettle();
    expect(copiedTexts, ['想留下的秘密']);
    expect(find.text('已複製到剪貼簿'), findsOneWidget);
    await tester.tap(find.byTooltip('關閉'));
    await tester.pumpAndSettle();
    await tester.tap(copyButtons.last);
    await tester.pumpAndSettle();
    expect(copiedTexts, ['想留下的秘密', '**值得記住的片段**']);
    await tester.tap(find.byTooltip('關閉'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('空白生成留在聊天室顯示提示並保留對話', (tester) async {
    final chat = testChatDiarySession(hidePersonNames: false);
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: '先聊聊操作',
        outboundText: '先聊聊操作',
      ),
    );
    final client = FakeAiClient(chat.connectionConfig)..output = '';
    final container = await pumpChat(
      tester,
      chat,
      client,
      editorDrafts: EmptyEditorDraftStore(),
    );
    await tester.tap(find.text('生成日記'));
    await tester.pumpAndSettle();
    final controller = container.read(chatDiaryControllerProvider(chat.id));
    expect(find.byType(ChatDiaryPage), findsOneWidget);
    expect(find.text('目前沒有適合生成的紀錄內容，可以再補充想留下的事。'), findsOneWidget);
    expect(controller.chat!.activeMessages.single.text, '先聊聊操作');
    expect(controller.chat!.generatedEntryId, isNull);
    expect(controller.error, isNull);
    expect(controller.canGenerate, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('生成失敗只顯示可關閉的 toast，不佔用輸入區上方空間', (tester) async {
    final chat = testChatDiarySession(hidePersonNames: false);
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: '今天到公園散步',
        outboundText: '今天到公園散步',
      ),
    );
    final client = FakeAiClient(chat.connectionConfig)
      ..failure = const AiFailure(AiErrorCode.tls);
    final container = await pumpChat(tester, chat, client);
    await container
        .read(chatDiaryControllerProvider(chat.id))
        .generate(tester.element(find.byType(ChatDiaryPage)).l10n);
    await tester.pumpAndSettle();
    const message = '無法驗證服務的 TLS 憑證，請確認網址與憑證設定。';
    expect(find.text(message), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Dismissible),
        matching: find.text(message),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('關閉'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('附圖在使用者文字泡泡上方，共用日記圖片檢視可切圖縮放並在背景關閉', (tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chat = testChatDiarySession(hidePersonNames: false);
    final imageIds = [generateAssetId(), generateAssetId()];
    chat.images.addAll([
      for (final id in imageIds)
        ChatDiaryImage(id: id, mimeType: 'image/png', filename: 'image.png'),
    ]);
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'user',
        isUser: true,
        text: '想記住這兩張照片',
        outboundText: '想記住這兩張照片',
        imageIds: imageIds,
      ),
    );
    final store = OverviewChatDiaryStore(chat);
    for (final id in imageIds) {
      store.images[id] = testAiPng;
    }
    await pumpChat(
      tester,
      chat,
      FakeAiClient(chat.connectionConfig),
      store: store,
    );
    expect(
      tester.getBottomLeft(find.byType(Image).first).dy,
      lessThan(tester.getTopLeft(find.text('想記住這兩張照片')).dy),
    );
    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    final gallery = find.byType(AppImageGalleryDialog);
    expect(gallery, findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    final dialog = find.descendant(of: gallery, matching: find.byType(Dialog));
    expect(
      tester.widget<Dialog>(dialog).backgroundColor,
      tester.element(dialog).appColors.galleryBackground,
    );
    final pages = find.descendant(of: gallery, matching: find.byType(PageView));
    await tester.drag(pages, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    final viewer = find
        .descendant(of: gallery, matching: find.byType(InteractiveViewer))
        .hitTestable();
    final center = tester.getCenter(viewer);
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InteractiveViewer>(viewer)
          .transformationController!
          .value
          .getMaxScaleOnAxis(),
      greaterThan(1),
    );
    expect(
      tester.widget<PageView>(pages).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    await tester.tap(find.byTooltip('關閉'));
    await tester.pumpAndSettle();
    expect(gallery, findsNothing);
    await tester.tap(find.byTooltip('查看送給 AI 的內容'));
    await tester.pumpAndSettle();
    final previewImage = find
        .descendant(of: find.byType(AlertDialog), matching: find.byType(Image))
        .first;
    await tester.ensureVisible(previewImage);
    await tester.tap(previewImage);
    await tester.pumpAndSettle();
    expect(gallery, findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(gallery, findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('聊天室內儲存設定後立即更新模型與持久化連線', (tester) async {
    final chat = testChatDiarySession(hidePersonNames: false)
      ..composerText = '尚未送出的內容';
    final aiSettings = OverviewAiSettingsStore();
    final container = await pumpChat(
      tester,
      chat,
      FakeAiClient(chat.connectionConfig),
      aiSettings: aiSettings,
    );
    expect(
      tester.getCenter(find.byTooltip('AI 設定')).dx,
      lessThan(tester.getCenter(find.byTooltip('加入圖片')).dx),
    );
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    final delete = find.byTooltip('刪除本機聊天');
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(of: delete, matching: find.byType(IconButton)),
          )
          .style!
          .foregroundColor!
          .resolve({}),
      Theme.of(tester.element(delete)).colorScheme.error,
    );
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text('刪除'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('AI 設定'));
    await tester.pumpAndSettle();
    final Finder addField = find.byKey(
      const ValueKey('ai-model-add-field-custom'),
    );
    await tester.ensureVisible(addField);
    await tester.enterText(addField, 'updated-model');
    await tester.pump();
    final Finder add = find.byKey(const ValueKey('ai-model-add-custom'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump();
    final Finder protocol = find.byKey(const ValueKey('ai-protocol-field'));
    await tester.ensureVisible(protocol);
    await tester.tap(protocol);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(MenuItemButton, 'OpenAI Chat Completions'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '儲存'));

    await tester.pumpAndSettle();
    expect(find.text('自訂/test-model'), findsOneWidget);
    expect(find.text('自訂/updated-model'), findsNothing);
    final controller = container.read(chatDiaryControllerProvider(chat.id));
    expect(
      controller.chat!.connectionConfig.protocol,
      AiApiProtocol.chatCompletions,
    );
    expect(controller.chat!.connectionConfig.model, 'test-model');
    expect(aiSettings.settings.activeConfig.addedModels, [
      'test-model',
      'updated-model',
    ]);
    expect(
      (await container
              .read(chatDiaryStoreProvider)
              .load(
                chat.id,
                const UnlockedVaultSession(
                  vaultId: 'vault',
                  trustedDevice: true,
                ),
              ))!
          .connectionConfig
          .model,
      'test-model',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('聊天室切換模型會改這一則，並成為下一則新聊天的模型', (tester) async {
    final chat = testChatDiarySession(hidePersonNames: false);
    final aiSettings = OverviewAiSettingsStore()
      ..settings = AiConnectionSettings(
        provider: AiProvider.custom,
        configs: {
          AiProvider.custom: chat.connectionConfig.copyWith(
            addedModels: const ['test-model', 'other-model'],
            enabledModels: const ['test-model', 'other-model'],
          ),
        },
      );
    final container = await pumpChat(
      tester,
      chat,
      FakeAiClient(chat.connectionConfig),
      aiSettings: aiSettings,
    );
    await tester.tap(find.byKey(const ValueKey('chat-model-tag')));
    await tester.pumpAndSettle();
    final tag = tester.getRect(find.byKey(const ValueKey('chat-model-tag')));
    final menu = tester.getRect(find.byKey(const ValueKey('chat-model-menu')));
    expect(menu.bottom, lessThan(tag.top - 8));
    await tester.tap(find.text('自訂/other-model'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(chatDiaryControllerProvider(chat.id))
          .chat!
          .connectionConfig
          .model,
      'other-model',
    );
    expect(aiSettings.settings.activeConfig.model, 'other-model');
    expect(find.text('自訂/other-model'), findsOneWidget);
  });

  testWidgets('閱讀舊內容時串流不拉走捲動位置，回到底部後繼續跟隨', (tester) async {
    final chat = testChatDiarySession(hidePersonNames: false);
    for (var i = 0; i < 25; i++) {
      chat.appendMessage(
        ChatDiaryMessage(
          id: 'u$i',
          parentId: chat.activeMessages.lastOrNull?.id,
          isUser: true,
          text: '第 $i 段記錄\n今天留下的合成片段',
          outboundText: '記錄',
        ),
      );
      chat.appendMessage(
        ChatDiaryMessage(
          id: 'a$i',
          parentId: chat.activeMessages.lastOrNull?.id,
          isUser: false,
          text: '這是一段回覆\n幫助回想當下的細節。',
          outboundText: '回覆',
        ),
      );
    }
    final client = FakeAiClient(chat.connectionConfig);
    final stream = StreamController<String>();
    client.response = () => stream.stream;
    final container = await pumpChat(tester, chat, client);
    final controller = container.read(chatDiaryControllerProvider(chat.id));
    final list = find.byType(ListView).first;
    await tester.drag(list, const Offset(0, 800));
    await tester.pumpAndSettle();
    final scroll = tester.widget<ListView>(list).controller!;
    final before = scroll.offset;
    final sending = controller.regenerateReply(
      controller.chat!.activeMessages.last.id,
    );
    for (var i = 0; i < 10 && client.calls.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    stream.add('新的串流內容');
    await tester.pump(const Duration(milliseconds: 50));
    expect(scroll.offset, closeTo(before, 1));
    expect(find.byTooltip('回到最新訊息'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('回到最新訊息'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump(const Duration(milliseconds: 250));
    stream.add('\n後續串流內容');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(scroll.position.extentAfter, lessThan(5));
    await stream.close();
    await sending;
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('傳送中停用聊天室功能按鈕，仍可返回其他頁面', (tester) async {
    final chat = testChatDiarySession(hidePersonNames: false);
    final stream = StreamController<String>();
    final client = FakeAiClient(chat.connectionConfig)
      ..response = () => stream.stream;
    final container = await pumpChat(tester, chat, client, withBack: true);
    await tester.enterText(find.byType(TextField), '合成訊息');
    await tester.pump();
    await tester.tap(find.byTooltip('送出'));
    for (var i = 0; i < 20 && client.calls.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    final controller = container.read(chatDiaryControllerProvider(chat.id));
    expect(controller.busy, isTrue);
    for (final element in find.byType(IconButton).evaluate()) {
      if (element.findAncestorWidgetOfExactType<BackButton>() == null) {
        expect((element.widget as IconButton).onPressed, isNull);
      }
    }
    for (final button in tester.widgetList<TextButton>(
      find.byType(TextButton),
    )) {
      expect(button.onPressed, isNull);
    }
    expect(find.bySemanticsLabel('正在等候回覆'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byTooltip('處理中'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pump(const Duration(milliseconds: 400));
    await stream.close();
    await tester.pumpAndSettle();
    expect(find.byType(ChatDiaryPage), findsNothing);
    expect(find.text('開啟聊天室'), findsOneWidget);
    expect(client.closed, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final locale in [const Locale('zh'), const Locale('en')]) {
      testWidgets(
        '窄螢幕大字與鍵盤下的${brightness == Brightness.light ? '淺色' : '深色'}${locale.languageCode == 'zh' ? '繁中' : '英文'}聊天介面可操作',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          final chat = testChatDiarySession(hidePersonNames: false);
          for (final message in [
            ChatDiaryMessage(
              id: 'user',
              isUser: true,
              text: '昨天跟朋友煮晚餐，湯太鹹，大家笑了很久。',
              outboundText: '合成案例',
            ),
            ChatDiaryMessage(
              id: 'reply',
              isUser: false,
              text: '一起煮飯時那個笑成一團的片段，聽起來很值得留下。\n\n你最記得誰的反應？',
              outboundText: '合成回覆',
            ),
          ]) {
            chat.appendMessage(
              message..parentId = chat.activeMessages.lastOrNull?.id,
            );
          }
          await pumpChat(
            tester,
            chat,
            FakeAiClient(chat.connectionConfig),
            brightness: brightness,
            textScale: 1.5,
            locale: locale,
            withBack: true,
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(BackButton), findsOneWidget);
          expect(find.byType(PopupMenuButton<String>), findsNothing);
          expect(
            find.text(locale.languageCode == 'en' ? 'Generate diary' : '生成日記'),
            findsOneWidget,
          );
          final actionButtons = find.descendant(
            of: find.byType(Wrap).first,
            matching: find.byType(IconButton),
          );
          expect(actionButtons, findsNWidgets(2));
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.showKeyboard(find.byType(TextField));
          await tester.enterText(find.byType(TextField), '準備補充的內容');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.byTooltip(locale.languageCode == 'en' ? 'Send' : '送出'),
            findsOneWidget,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        },
      );
    }
  }

  testWidgets('選圖暫時失去焦點不遮蔽聊天，取消後仍保留一般失焦遮蔽', (tester) async {
    final picked = mockGalleryPicker(tester);
    final chat = testChatDiarySession(hidePersonNames: false)
      ..composerText = '選圖前輸入的文字';
    await pumpChat(tester, chat, FakeAiClient(chat.connectionConfig));
    await tester.tap(find.byTooltip('加入圖片'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.bySemanticsLabel('內容已隱藏'), findsNothing);
    expect(find.text('選圖前輸入的文字'), findsOneWidget);

    picked.complete([]);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('選圖前輸入的文字'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.bySemanticsLabel('內容已隱藏'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '圖庫先回傳圖片再返回前景時，遮蔽背景並在前景加入圖片',
    (tester) => IOOverrides.runZoned(() async {
      final picked = mockGalleryPicker(tester);
      final chat = testChatDiarySession(hidePersonNames: false);
      final store = _ImageChatDiaryStore(chat);
      final container = await pumpChat(
        tester,
        chat,
        FakeAiClient(chat.connectionConfig),
        store: store,
      );
      await tester.tap(find.byTooltip('加入圖片'));
      await tester.pumpAndSettle();
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      tester.binding.scheduleForcedFrame();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('內容已隱藏'), findsOneWidget);

      picked.complete(['image.png']);
      await tester.pumpAndSettle();
      expect(store.images, isEmpty);
      resumeApp(tester);
      await tester.pumpAndSettle();
      final restored = container
          .read(chatDiaryControllerProvider(chat.id))
          .chat!;
      expect(restored.pendingImageIds, hasLength(1));
      expect(store.images.values.single, testAiPng);
      expect(find.bySemanticsLabel('內容已隱藏'), findsNothing);
      expect(tester.takeException(), isNull);
    }, createFile: (_) => _PickedImageFile()),
  );

  testWidgets('等候圖庫返回前景時鎖定，不會將已選取的圖片加入聊天', (tester) async {
    final picked = mockGalleryPicker(tester);
    final chat = testChatDiarySession(hidePersonNames: false);
    final store = _ImageChatDiaryStore(chat);
    final container = await pumpChat(
      tester,
      chat,
      FakeAiClient(chat.connectionConfig),
      store: store,
    );
    await tester.tap(find.byTooltip('加入圖片'));
    await tester.pumpAndSettle();
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    picked.complete(['不應讀取的圖片.png']);
    await tester.pumpAndSettle();

    (container.read(appSessionProvider.notifier) as _ChatSession).setLocked();
    await tester.pumpAndSettle();
    resumeApp(tester);
    await tester.pumpAndSettle();
    expect(store.images, isEmpty);
    expect(container.read(chatDiaryControllerProvider(chat.id)).chat, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('背景遮蔽聊天且返回不自動重送，鎖定後清除輸入與畫面', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chat = testChatDiarySession(hidePersonNames: false)
      ..composerText = '尚未送出的私密文字';
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'message',
        isUser: true,
        text: '已送出的合成日記內容',
        outboundText: '已送出的合成日記內容',
      ),
    );
    final store = OverviewChatDiaryStore(chat);
    final client = FakeAiClient(chat.connectionConfig);
    final container = ProviderContainer(
      overrides: [
        chatDiaryStoreProvider.overrideWithValue(store),
        appSessionProvider.overrideWith(_ChatSession.new),
        aiClientFactoryProvider.overrideWithValue((_, _) => client),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: widgetTestApp(
          wrapScaffold: false,
          center: false,
          child: ChatDiaryPage(chatId: chat.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('已送出的合成日記內容'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '尚未送出的私密文字',
    );
    expect(tester.takeException(), isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('已送出的合成日記內容'), findsNothing);
    expect(find.textContaining('test-model'), findsNothing);
    expect(find.bySemanticsLabel('內容已隱藏'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    for (final tooltip in ['查看送給 AI 的內容', '刪除本機聊天']) {
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip(tooltip),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('已送出的合成日記內容'), findsOneWidget);
    expect(client.calls, isEmpty);
    (container.read(appSessionProvider.notifier) as _ChatSession).setLocked();
    await tester.pumpAndSettle();
    expect(find.text('已送出的合成日記內容'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(container.read(chatDiaryControllerProvider(chat.id)).chat, isNull);
    expect(
      (await store.load(
        chat.id,
        const UnlockedVaultSession(vaultId: 'vault', trustedDevice: true),
      ))!.composerText,
      '尚未送出的私密文字',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
