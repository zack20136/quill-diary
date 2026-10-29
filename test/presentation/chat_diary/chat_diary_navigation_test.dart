import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/app/router.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/editor/editor_entry_providers.dart';
import 'package:quill_diary/application/home/home_entry_query_providers.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_settings.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/chat_diary/chat_diary_store.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/preferences/preferences_providers.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/storage_path_providers.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_connection_settings_dialog.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_page.dart';
import 'package:quill_diary/presentation/editor/pages/editor_page.dart';
import 'package:quill_diary/presentation/home/pages/home_page.dart';
import 'package:quill_diary/presentation/home/widgets/home_chat_diary_draft_card.dart';

import '../../helpers/ai/ai_test_helpers.dart';
import '../../helpers/app_test_theme.dart';
import '../../helpers/presentation/chat_diary/chat_diary_navigation_scope.dart';
import '../../helpers/vault/manifest_write_test_crypto_service.dart';
import '../../helpers/vault/vault_test_harness.dart';

enum _WritingFlowScenario { direct, chat, leaveDuringSave }

void main() {
  testWidgets('空白聊天離開不留草稿，有輸入可續聊且再次新增不沿用舊內容', (tester) async {
    const connectionConfig = AiConnectionConfig(
      provider: AiProvider.custom,
      model: 'local-model',
      baseUrl: 'https://custom.example/v1',
    );
    final store = MemoryChatDiaryStore();
    final connections = MemoryAiConnectionSettingsStore()
      ..settings = AiConnectionSettings(
        provider: AiProvider.custom,
        configs: {AiProvider.custom: connectionConfig},
      );
    var networkCalls = 0;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, _) => const HomePage()),
        GoRoute(
          path: '${AppRouter.chatDiaryRoutePrefix}/new/:id',
          builder: (_, state) => ChatDiaryPage(
            chatId: state.pathParameters['id']!,
            isNewChat: true,
          ),
        ),
        GoRoute(
          path: '${AppRouter.chatDiaryRoutePrefix}/:id',
          builder: (_, state) =>
              ChatDiaryPage(chatId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      chatDiaryNavigationApp(
        router: router,
        store: store,
        connections: connections,
        clientFactory: (connectionConfig, _) {
          networkCalls++;
          return FakeAiClient(connectionConfig);
        },
      ),
    );
    await tester.pumpAndSettle();
    final readySettings = connections.settings;
    connections.settings = const AiConnectionSettings();
    await tester.tap(find.byTooltip('新增日記'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('聊天寫日記'));
    await tester.pumpAndSettle();
    expect(find.byType(AiConnectionSettingsDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.byType(HomePage), findsOneWidget);
    expect(store.storedChats, isEmpty);
    await tester.tap(find.byTooltip('新增日記'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('聊天寫日記'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ai-model-autocomplete')),
      'manual-model',
    );
    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
    await tester.pumpAndSettle();
    expect(store.storedChats, isEmpty);
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(networkCalls, 0);
    expect(find.text('請先填寫服務網址、模型與必要的 API Key。'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    connections.settings = readySettings;
    await tester.tap(find.byTooltip('新增日記'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('聊天寫日記'));
    await tester.pumpAndSettle();
    expect(store.storedChats, isEmpty);
    expect(find.byType(ChatDiaryPage), findsOneWidget);
    expect(networkCalls, 0);
    final chatPage = tester.widget<ChatDiaryPage>(find.byType(ChatDiaryPage));
    expect(
      ProviderScope.containerOf(tester.element(find.byType(ChatDiaryPage)))
          .read(chatDiaryControllerProvider(chatPage.chatId!))
          .chat!
          .openingMessage,
      isNotEmpty,
    );
    expect(
      await store.list(
        const UnlockedVaultSession(vaultId: 'vault', trustedDevice: true),
      ),
      isEmpty,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(store.storedChats, isEmpty);
    expect(find.byType(HomeChatDiaryDraftCard), findsNothing);
    await tester.tap(find.byTooltip('新增日記'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('聊天寫日記'));
    await tester.pumpAndSettle();
    final firstId = tester
        .widget<ChatDiaryPage>(find.byType(ChatDiaryPage))
        .chatId!;
    await tester.enterText(find.byType(TextField), '第一份輸入');
    expect(router.canPop(), isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomeChatDiaryDraftCard), findsOneWidget);
    expect(find.text('第一份輸入'), findsOneWidget);
    await tester.tap(find.text('第一份輸入'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ChatDiaryPage>(find.byType(ChatDiaryPage)).chatId,
      firstId,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '第一份輸入',
    );
    expect(router.canPop(), isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新增日記'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('聊天寫日記'));
    await tester.pumpAndSettle();
    expect(store.storedChats.keys, [firstId]);
    expect(
      tester.widget<ChatDiaryPage>(find.byType(ChatDiaryPage)).chatId,
      isNot(firstId),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(router.canPop(), isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomeChatDiaryDraftCard), findsOneWidget);
    expect(store.storedChats.keys, [firstId]);
    await store.delete(firstId);
    await tester.tap(find.text('第一份輸入'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(HomeChatDiaryDraftCard), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  for (final scenario in _WritingFlowScenario.values) {
    final chatMode = scenario == _WritingFlowScenario.chat;
    final leaveDuringSave = scenario == _WritingFlowScenario.leaveDuringSave;
    testWidgets(
      leaveDuringSave
          ? '實際儲存途中離開編輯器，完成後不導頁或更新已離開的畫面'
          : '${chatMode ? '聊天生成' : '直接寫作'}經過實際編輯器儲存後，返回首頁可再新增日記',
      (tester) async {
        await tester.runAsync(() async {
          final crypto = ManifestWriteTestCryptoService();
          final harness = await VaultTestHarness.create(cryptoService: crypto);
          final setup = await harness.repository.setupRecoveryKey();
          final session = setup.session;
          final store = ChatDiaryStore(
            paths: harness.pathStrategy,
            crypto: LocalCryptoService(),
            repository: harness.repository,
            editorDraftStore: EditorDraftStore(
              pathStrategy: harness.pathStrategy,
              cryptoService: LocalCryptoService(),
            ),
          );
          final router = AppRouter.createRouter();
          const connectionConfig = AiConnectionConfig(
            provider: AiProvider.custom,
            model: 'synthetic-model',
            baseUrl: 'https://synthetic.example/v1',
          );
          final connections = MemoryAiConnectionSettingsStore()
            ..settings = const AiConnectionSettings(
              provider: AiProvider.custom,
              configs: {AiProvider.custom: connectionConfig},
            );
          final diarySettings = MemoryChatDiarySettingsStore()
            ..settings = const ChatDiarySettings(hidePersonNames: false);
          Future<void> waitUntil(
            bool Function() ready, {
            bool waitForIdle = true,
          }) async {
            final waiting = Stopwatch()..start();
            while (waiting.elapsed < const Duration(seconds: 10)) {
              await tester.pump(const Duration(milliseconds: 30));
              await Future<void>.delayed(const Duration(milliseconds: 10));
              if (ready() &&
                  (!waitForIdle || !tester.binding.hasScheduledFrame)) {
                return;
              }
            }
            fail('實際儲存流程未在預期時間內完成');
          }

          final saveGate = Completer<void>();
          try {
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  effectiveAppSessionProvider.overrideWith(
                    (_) async => AppSessionState(
                      status: AppLockStatus.unlocked,
                      session: session,
                    ),
                  ),
                  appSessionProvider.overrideWith(
                    () => ChatDiaryNavigationSession(session: session),
                  ),
                  vaultPathStrategyProvider.overrideWithValue(
                    harness.pathStrategy,
                  ),
                  vaultRepositoryProvider.overrideWithValue(harness.repository),
                  chatDiaryStoreProvider.overrideWithValue(store),
                  aiConnectionSettingsStoreProvider.overrideWithValue(
                    connections,
                  ),
                  chatDiarySettingsStoreProvider.overrideWithValue(
                    diarySettings,
                  ),
                  userPreferencesProvider.overrideWithValue(
                    UserPreferences(
                      storageFile: File(
                        '${harness.tempDir.path}/preferences.json',
                      ),
                    ),
                  ),
                  aiClientFactoryProvider.overrideWithValue(
                    (connectionConfig, _) =>
                        FakeAiClient(connectionConfig)
                          ..output = '# 合成日記\n\n今天留下的一段合成內容。',
                  ),
                  homeEntriesProvider.overrideWith(
                    (_) => const AsyncData<List<EntryIndexRecord>>([]),
                  ),
                  homeEntryIndexListProvider.overrideWith(
                    (_) async =>
                        const HomeEntryQueryResult(query: '', entries: []),
                  ),
                  homePinnedEntryIdsProvider.overrideWith((_) async => {}),
                ],
                child: MaterialApp.router(
                  routerConfig: router,
                  theme: appTestTheme(),
                  locale: appZhLocale,
                  supportedLocales: appSupportedLocales,
                  localizationsDelegates: appLocalizationsDelegates,
                ),
              ),
            );
            await waitUntil(() => find.byTooltip('新增日記').evaluate().isNotEmpty);
            await tester.tap(find.byTooltip('新增日記'));
            await tester.pumpAndSettle();
            final mode = chatMode ? '聊天寫日記' : '直接寫日記';
            await tester.tap(find.text(mode));
            if (chatMode) {
              await waitUntil(
                () => find
                    .byKey(const ValueKey('chat-diary-composer'))
                    .evaluate()
                    .isNotEmpty,
              );
              final chatId = tester
                  .widget<ChatDiaryPage>(find.byType(ChatDiaryPage))
                  .chatId!;
              expect(
                (await store.draftDirectory(chatId)).existsSync(),
                isFalse,
              );
              await tester.enterText(
                find.byKey(const ValueKey('chat-diary-composer')),
                '今天留下的一段合成內容。',
              );
              await tester.pump();
              await tester.tap(find.byTooltip('送出'));
              final controller = ProviderScope.containerOf(
                tester.element(find.byType(ChatDiaryPage)),
              ).read(chatDiaryControllerProvider(chatId));
              await waitUntil(() => controller.canGenerate);
              await tester.tap(find.text('生成日記'));
            }
            final bodyField = find.byWidgetPredicate(
              (widget) =>
                  widget is TextField &&
                  widget.decoration?.hintText == '在這裡輸入內容…',
            );
            await waitUntil(() => bodyField.evaluate().isNotEmpty);
            expect(find.byType(EditorPage), findsOneWidget);
            if (!chatMode) await tester.enterText(bodyField, '今天留下的一段合成內容。');
            await tester.pump();
            if (leaveDuringSave) {
              crypto.manifestWriteStarted = Completer<void>();
              crypto.manifestWriteGate = saveGate.future;
            }
            final scope = ProviderScope.containerOf(
              tester.element(find.byType(EditorPage)),
            );
            final initialRevision = scope.read(entryIndexRevisionProvider);
            await tester.tap(find.byTooltip('儲存'));
            if (leaveDuringSave) {
              await waitUntil(
                () => crypto.manifestWriteStarted!.isCompleted,
                waitForIdle: false,
              );
              router.go(AppRouter.homeRoute);
              await waitUntil(() => find.byType(EditorPage).evaluate().isEmpty);
              saveGate.complete();
              await waitUntil(
                () => scope.read(entryIndexRevisionProvider) > initialRevision,
              );
              final savedEntries = await harness.repository.listEntries();
              expect(savedEntries, hasLength(1));
              expect(
                (await harness.repository.loadEntry(
                  session,
                  savedEntries.single.id,
                ))!.markdownBody,
                contains('今天留下的一段合成內容。'),
              );
              expect(
                router.routeInformationProvider.value.uri.path,
                AppRouter.homeRoute,
              );
              expect(tester.takeException(), isNull);
              return;
            }
            await waitUntil(
              () =>
                  tester
                      .widgetList<EditorPage>(find.byType(EditorPage))
                      .any((page) => page.entryId != null) &&
                  scope.read(entryIndexRevisionProvider) > initialRevision,
            );
            final savedId = tester
                .widgetList<EditorPage>(find.byType(EditorPage))
                .singleWhere((page) => page.entryId != null)
                .entryId!;
            final saved = await harness.repository.loadEntry(session, savedId);
            expect(saved!.markdownBody, contains('今天留下的一段合成內容。'));
            if (chatMode) {
              expect(await store.loadForEntry(savedId, session), isNotNull);
            }
            await tester.binding.handlePopRoute();
            await waitUntil(() => find.byType(HomePage).evaluate().isNotEmpty);
            await tester.tap(find.byTooltip('新增日記'));
            await tester.pumpAndSettle();
            await tester.tap(find.text(mode));
            await waitUntil(
              () => chatMode
                  ? find
                        .byKey(const ValueKey('chat-diary-composer'))
                        .evaluate()
                        .isNotEmpty
                  : bodyField.evaluate().isNotEmpty,
            );
            if (chatMode) {
              expect(
                tester
                    .widget<TextField>(
                      find.byKey(const ValueKey('chat-diary-composer')),
                    )
                    .controller!
                    .text,
                isEmpty,
              );
            } else {
              expect(
                tester.widget<TextField>(bodyField).controller!.text,
                isEmpty,
              );
            }
            expect(tester.takeException(), isNull);
          } finally {
            if (!saveGate.isCompleted) saveGate.complete();
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await store.flush();
            router.dispose();
            await harness.dispose();
          }
        });
      },
    );
  }

  testWidgets('完成聊天區分刪除與損壞圖片，返回日記後重讀附件，日記刪除則回首頁', (tester) async {
    final chat = testChatDiarySession()
      ..finished = true
      ..generatedEntryId = 'entry';
    chat.appendMessage(
      ChatDiaryMessage(
        id: 'message',
        isUser: true,
        text: '合成圖片',
        outboundText: '合成圖片',
        imageIds: ['kept', 'missing', 'broken', 'invalid'],
      ),
    );
    final store = MemoryChatDiaryStore(chat)
      ..images['kept'] = testAiPng
      ..images['invalid'] = Uint8List.fromList([0, 1, 2])
      ..failedImages.add('broken');
    final repository = MemoryChatDiaryEntryRepository(
      DiaryEntry(
        id: 'entry',
        vaultId: 'vault',
        date: const DateOnly('2026-10-27'),
        createdAt: DateTime(2026, 10, 27),
        updatedAt: DateTime(2026, 10, 27),
        markdownBody: '合成日記',
      ),
    );
    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('測試首頁')),
        ),
        GoRoute(
          path: '/chat',
          builder: (_, _) => ChatDiaryPage(entryId: 'entry'),
        ),
        GoRoute(
          path: '${AppRouter.editorRoute}/:id',
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () {
                    store.images.remove('kept');
                    context.pop();
                  },
                  child: const Text('移除附件'),
                ),
                TextButton(
                  onPressed: () {
                    repository.entry = null;
                    context.pop();
                  },
                  child: const Text('刪除日記'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith(ChatDiaryNavigationSession.new),
          chatDiaryStoreProvider.overrideWithValue(store),
          vaultRepositoryProvider.overrideWithValue(repository),
          aiConnectionSettingsStoreProvider.overrideWithValue(
            MemoryAiConnectionSettingsStore(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: appTestTheme(brightness: Brightness.light),
          locale: appZhLocale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('圖片已刪除'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('圖片已刪除'), matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(find.byIcon(Icons.broken_image_outlined), findsNWidgets(2));
    expect(store.imageReads, 4);
    await tester.tap(find.text('開啟日記'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除附件'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('圖片已刪除'), findsNWidgets(2));
    expect(store.imageReads, 8);
    await tester.tap(find.text('開啟日記'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除日記'));
    await tester.pumpAndSettle();
    expect(find.text('測試首頁'), findsOneWidget);
    expect(find.byType(ChatDiaryPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
