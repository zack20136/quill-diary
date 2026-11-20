import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/ai/ai_prompt_localizations.dart';
import 'package:quill_diary/application/ai/ai_prompts.dart';
import 'package:quill_diary/application/session/app_session_controller.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/ai/ai_stored_settings.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_connection_labels.dart';
import 'package:quill_diary/presentation/ai/ai_connection_settings_dialog.dart';
import 'package:quill_diary/presentation/ai/ai_prompt_dialog.dart';
import 'package:quill_diary/presentation/ai/ai_prompt_settings_dialog.dart';
import 'package:quill_diary/presentation/settings/pages/settings_page.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';

import '../../helpers/ai/ai_test_helpers.dart';
import '../../helpers/preferences/in_memory_user_preferences.dart';
import '../../helpers/presentation/settings/settings_test_scope.dart';
import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

class _SettingsSession extends AppSessionController {
  @override
  AppSessionState build() => const AppSessionState(
    status: AppLockStatus.unlocked,
    session: UnlockedVaultSession(vaultId: 'vault', trustedDevice: true),
  );
}

void main() {
  late OverviewAiSettingsStore store;
  late ValueNotifier<Locale> locale;
  var networkCalls = 0;
  AiFailure? connectionFailure;
  var throwOnConnection = false;
  Completer<void>? connectionGate;
  FakeAiClient? lastClient;
  Widget app({Widget? child, Brightness brightness = Brightness.light}) =>
      ProviderScope(
        overrides: [
          userPreferencesProvider.overrideWithValue(InMemoryUserPreferences()),
          aiSettingsStoreProvider.overrideWithValue(store),
          appSessionProvider.overrideWith(_SettingsSession.new),
          aiClientFactoryProvider.overrideWithValue((connectionConfig, key) {
            networkCalls++;
            return lastClient = FakeAiClient(connectionConfig)
              ..failure = connectionFailure
              ..response = throwOnConnection
                  ? () => throw StateError('未知')
                  : null
              ..connectionGate = connectionGate?.future;
          }),
        ],
        child: ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (context, value, _) => widgetTestApp(
            locale: value,
            brightness: brightness,
            child:
                child ??
                Builder(
                  builder: (context) => FilledButton(
                    onPressed: () => showAiConnectionSettingsDialog(context),
                    child: Text(context.l10n.aiSettings),
                  ),
                ),
          ),
        ),
      );
  setUp(() {
    store = OverviewAiSettingsStore();
    locale = ValueNotifier(appZhLocale);
    networkCalls = 0;
    connectionFailure = null;
    throwOnConnection = false;
    connectionGate = null;
    lastClient = null;
  });
  tearDown(() => locale.dispose());
  Future<void> open(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    addTearDown(() async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox.shrink());
    });
    await tester.pumpWidget(app(brightness: brightness));
    await tester.tap(find.text('AI 設定'));
    await tester.pumpAndSettle();
  }

  final promptEntry = find.byKey(const ValueKey('ai-prompt-settings'));

  Future<void> openPrompts(WidgetTester tester) async {
    await tester.ensureVisible(promptEntry);
    await tester.tap(promptEntry);
    await tester.pumpAndSettle();
  }

  Future<void> closePrompts(WidgetTester tester) async {
    await tester.tap(
      find
          .descendant(
            of: find.byType(AiPromptSettingsDialog),
            matching: find.byType(TextButton),
          )
          .last,
    );
    await tester.pumpAndSettle();
  }

  Future<void> prompt(WidgetTester tester, String label) async {
    if (find.byType(AiPromptSettingsDialog).evaluate().isEmpty) {
      await openPrompts(tester);
    }
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('取消不可讀設定重建確認不替換設定或外送請求', (tester) async {
    store.failReads = true;
    await open(tester);
    await tester.tap(find.text('重設 AI 設定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(store.failReads, isTrue);
    expect(find.byKey(const ValueKey('ai-settings-scroll')), findsNothing);
    expect(find.text('重設 AI 設定'), findsOneWidget);
    expect(networkCalls, 0);
  });

  testWidgets('設定讀取失敗提供重設入口，重設後可重新編輯且保留 API Key', (tester) async {
    store.failReads = true;
    const config = AiConnectionConfig(provider: AiProvider.openai);
    await store.saveApiKey(config, '保留的測試金鑰');
    await open(tester);
    expect(find.text('重設 AI 設定'), findsOneWidget);
    await tester.tap(find.text('重設 AI 設定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重設 AI 設定').last);
    await tester.pumpAndSettle();
    expect(find.text('重設 AI 設定'), findsNothing);
    expect(find.byKey(const ValueKey('ai-settings-scroll')), findsOneWidget);
    expect(await store.readApiKey(config), '保留的測試金鑰');
    expect(networkCalls, 0);
  });

  List<String> modelOrder() => find
      .descendant(
        of: find.byType(AiConnectionSettingsDialog),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Material &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith('ai-model-'),
        ),
      )
      .evaluate()
      .map((element) => (element.widget.key! as ValueKey<String>).value)
      .toList();

  Future<String> addConnection(
    WidgetTester tester,
    String name,
    String key,
  ) async {
    final add = find.byKey(const ValueKey('ai-add-connection'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    final nameField = find
        .byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'ai-connection-name-',
              ),
        )
        .last;
    final id = (tester.widget<TextField>(nameField).key! as ValueKey<String>)
        .value
        .substring('ai-connection-name-'.length);
    await tester.ensureVisible(nameField);
    await tester.enterText(nameField, name);
    await tester.enterText(
      find.byKey(ValueKey('ai-connection-url-$id')),
      'https://same.example/v1',
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ValueKey('ai-api-key-$id')), key);
    final model = find.byKey(ValueKey('ai-model-add-field-$id'));
    await tester.ensureVisible(model);
    await tester.enterText(model, 'same-model');
    await tester.pump();
    final addModel = find.byKey(ValueKey('ai-model-add-$id'));
    await tester.ensureVisible(addModel);
    await tester.tap(addModel);
    await tester.pumpAndSettle();
    return id;
  }

  group('連線', () {
    testWidgets('同網址同模型分別保存，刪除須確認且儲存後不提供恢復', (tester) async {
      await open(tester);
      final a = await addConnection(tester, '工作', 'key-a');
      final b = await addConnection(tester, '個人', 'key-b');
      expect(a, isNot(b));
      expect(store.keys, isEmpty);
      final bName = find.byKey(ValueKey('ai-connection-name-$b'));
      await tester.ensureVisible(bName);
      await tester.enterText(bName, '工作');
      await tester.tap(find.widgetWithText(FilledButton, '儲存'));
      await tester.pumpAndSettle();
      expect(find.text(testL10n.aiConnectionNameInvalid), findsOneWidget);
      expect(store.keys, isEmpty);
      await tester.enterText(bName, '個人');
      await tester.tap(find.widgetWithText(FilledButton, '儲存'));
      await tester.pumpAndSettle();
      final configA = store.settings.connectionFor(a);
      final configB = store.settings.connectionFor(b);
      expect(store.keys[configA.credentialId], 'key-a');
      expect(store.keys[configB.credentialId], 'key-b');
      expect(store.settings.activeConnectionId, a);
      await tester.tap(find.text('AI 設定'));
      await tester.pumpAndSettle();
      final remove = find.byKey(ValueKey('ai-connection-delete-$a'));
      await tester.ensureVisible(remove);
      final colors = Theme.of(tester.element(remove)).colorScheme;
      expect(
        tester.widget<TextButton>(remove).style!.foregroundColor!.resolve({}),
        colors.error,
      );
      final deleteIcon = find.descendant(
        of: remove,
        matching: find.byIcon(Icons.delete_outline),
      );
      expect(IconTheme.of(tester.element(deleteIcon)).color, colors.error);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(find.text('確定刪除連線？'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '取消').last);
      await tester.pumpAndSettle();
      expect(remove, findsOneWidget);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '刪除'));
      await tester.pumpAndSettle();
      expect(remove, findsNothing);
      expect(store.settings.connections.containsKey(a), isTrue);
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
      expect(store.settings.connections.containsKey(a), isTrue);
      await tester.tap(find.text('AI 設定'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '刪除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '儲存'));
      await tester.pumpAndSettle();
      expect(store.settings.connections.containsKey(a), isFalse);
      expect(store.settings.activeConnectionId, b);
      expect(store.keys.containsKey(configA.credentialId), isFalse);
      expect(store.keys[configB.credentialId], 'key-b');
      await tester.tap(find.text('AI 設定'));
      await tester.pumpAndSettle();
      expect(find.text('已移除連線'), findsNothing);
      expect(find.text('工作'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
      expect(networkCalls, 0);
      expect(tester.takeException(), isNull);
    });
    testWidgets('刪除最後一組可用連線仍可儲存，晚到金鑰不恢復已刪除草稿', (tester) async {
      final config = addModel(
        const AiConnectionConfig(
          provider: AiProvider.custom,
          customConnectionId: 'aic_only',
          displayName: '唯一連線',
          baseUrl: 'https://old.example/v1',
        ),
        'manual',
      );
      store.settings = AiConnectionSettings(
        activeConnectionId: config.connectionId,
        connections: {config.connectionId: config},
      );
      store.keys[config.credentialId] = 'old-key';
      await open(tester);
      final gate = Completer<void>();
      store.keyReadGate = gate.future;
      final url = find.byKey(const ValueKey('ai-connection-url-aic_only'));
      await tester.ensureVisible(url);
      await tester.enterText(url, 'https://new.example/v1');
      await tester.pump();
      final remove = find.byKey(
        const ValueKey('ai-connection-delete-aic_only'),
      );
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '刪除'));
      await tester.pumpAndSettle();
      gate.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '儲存'));
      await tester.pumpAndSettle();
      expect(find.byType(AiConnectionSettingsDialog), findsNothing);
      expect(
        store.settings.connections.containsKey(config.connectionId),
        isFalse,
      );
      expect(store.settings.activeConnectionId, 'openai');
      expect(store.keys, isEmpty);
      expect(tester.takeException(), isNull);
    });
    testWidgets('一組連線換網址的晚到金鑰不會寫進另一組，取消不保存', (tester) async {
      await open(tester);
      final a = await addConnection(tester, '工作', 'key-a');
      final b = await addConnection(tester, '個人', 'key-b');
      await tester.tap(find.widgetWithText(FilledButton, '儲存'));
      await tester.pumpAndSettle();
      final before = store.settings.toJson();
      await tester.tap(find.text('AI 設定'));
      await tester.pumpAndSettle();
      final gate = Completer<void>();
      store.keyReadGate = gate.future;
      final url = find.byKey(ValueKey('ai-connection-url-$a'));
      await tester.ensureVisible(url);
      await tester.enterText(url, 'https://new.example/v1');
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(ValueKey('ai-api-key-$a')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.ensureVisible(find.widgetWithText(ExpansionTile, '個人'));
      await tester.tap(find.widgetWithText(ExpansionTile, '個人'));
      await tester.pumpAndSettle();
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(ValueKey('ai-api-key-$b')))
            .controller!
            .text,
        'key-b',
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(store.settings.toJson(), before);
      expect(store.keys[store.settings.connectionFor(a).credentialId], 'key-a');
      expect(tester.takeException(), isNull);
    });
    testWidgets('設定讀取失敗時停用儲存且不覆寫既有資料', (tester) async {
      store.failReads = true;
      await open(tester);
      expect(find.textContaining('AI 設定無法讀取'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '儲存'))
            .onPressed,
        isNull,
      );
      expect(networkCalls, 0);
    });
    for (final readingKey in [false, true]) {
      testWidgets('${readingKey ? '金鑰' : '設定'}讀取尚未完成就關閉，不繼續讀取或顯示晚到訊息', (
        tester,
      ) async {
        final reading = Completer<void>();
        if (readingKey) {
          store.keyReadGate = reading.future;
        } else {
          store.readGate = reading.future;
        }
        await tester.pumpWidget(app());
        await tester.tap(find.text('AI 設定'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        // AI 開關在解鎖時也會讀設定，因此只比對關閉當下之後是否又發出讀取。
        final readsAtClose = store.reads;
        final keyReadsAtClose = store.keyReads;
        reading.complete();
        await tester.pumpAndSettle();
        expect(find.byType(AiConnectionSettingsDialog), findsNothing);
        expect(store.reads, readsAtClose);
        expect(store.keyReads, keyReadsAtClose);
        expect(store.keyReads, readingKey ? 1 : 0);
        expect(networkCalls, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    testWidgets('開啟設定不連線，取消不保存金鑰或聊天日記設定', (tester) async {
      await open(tester);
      final key = find.byKey(const ValueKey('ai-api-key-openai'));
      await tester.enterText(key, '不能保存的測試金鑰');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(store.keys, isEmpty);
      expect(networkCalls, 0);
    });
    testWidgets('切換 Custom 網址不沿用其他目的地的金鑰，取消不寫入', (tester) async {
      const connectionConfig = AiConnectionConfig(
        provider: AiProvider.custom,
        model: 'model',
        baseUrl: 'https://first.example/v1',
      );
      store.settings = const AiConnectionSettings(
        activeConnectionId: 'custom',
        connections: {'custom': connectionConfig},
      );
      store.keys[connectionConfig.credentialId] = 'first-synthetic-key';
      await open(tester);
      final url = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '服務網址',
      );
      final key = find.byKey(const ValueKey('ai-api-key-custom'));
      await tester.enterText(url, 'https://other.example/v1');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(key).controller!.text, isEmpty);
      await tester.enterText(key, 'other-synthetic-key');
      await tester.enterText(url, connectionConfig.baseUrl);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(key).controller!.text,
        'first-synthetic-key',
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(store.keys.keys, [connectionConfig.credentialId]);
      expect(store.keys[connectionConfig.credentialId], 'first-synthetic-key');
      expect(networkCalls, 0);
    });
    testWidgets('自訂連線有金鑰但沒有網址時儲存提示設定錯誤', (tester) async {
      store.settings = const AiConnectionSettings(
        connections: {
          'custom': AiConnectionConfig(provider: AiProvider.custom),
        },
      );
      await open(tester);
      await tester.enterText(
        find.byKey(const ValueKey('ai-api-key-custom')),
        'orphan-key',
      );
      await tester.tap(find.widgetWithText(FilledButton, '儲存'));
      await tester.pumpAndSettle();
      expect(find.text(testL10n.aiSettingsNeedConnection), findsOneWidget);
      expect(find.text(testL10n.aiErrorStorage), findsNothing);
      expect(find.byType(AiConnectionSettingsDialog), findsOneWidget);
      expect(store.keys.values, isNot(contains('orphan-key')));
    });
    testWidgets('介紹依提供商顯示政策與 HTTP 說明，連線不再要求確認', (tester) async {
      const connectionConfig = AiConnectionConfig(
        provider: AiProvider.gemini,
        model: 'test-model',
      );
      store.settings = const AiConnectionSettings(
        activeConnectionId: 'gemini',
        connections: {
          'gemini': connectionConfig,
          'custom': AiConnectionConfig(provider: AiProvider.custom),
        },
      );
      store.keys['gemini'] = 'synthetic-key';
      await open(tester);
      expect(
        find.textContaining(testL10n.aiGeminiPolicyNotice),
        findsOneWidget,
      );
      expect(find.text('查看服務商資料政策'), findsNothing);
      expect(find.text('服務連線'), findsNothing);
      final Finder geminiTest = find.byKey(const ValueKey('ai-test-gemini'));
      await tester.ensureVisible(geminiTest);
      await tester.tap(geminiTest);
      await tester.pumpAndSettle();
      expect(find.text('允許連線'), findsNothing);
      expect(networkCalls, 1);
      final url = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '服務網址',
      );
      await tester.ensureVisible(url);
      await tester.enterText(url, 'http://127.0.0.1:11434');
      await tester.pumpAndSettle();
      expect(
        find.textContaining(testL10n.aiGeminiPolicyNotice),
        findsOneWidget,
      );
      expect(find.textContaining('此網址使用 HTTP'), findsOneWidget);
      expect(find.textContaining('選填'), findsNothing);
    });
    testWidgets('Custom 可保存網址、模型與協定，API Key 可留空且切換不自動連線', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const connectionConfig = AiConnectionConfig(
        provider: AiProvider.custom,
        model: 'model',
        baseUrl: 'https://gateway.example/v1',
      );
      store.settings = const AiConnectionSettings(
        activeConnectionId: 'custom',
        connections: {'custom': connectionConfig},
      );
      await open(tester);
      final field = find.byKey(const ValueKey('ai-protocol-field'));
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      for (final protocol in AiApiProtocol.values) {
        expect(find.text(aiProtocolLabel(protocol)), findsWidgets);
      }
      await tester.tap(find.text('Claude Messages'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '儲存'));
      await tester.pumpAndSettle();
      expect(
        store.settings.activeConfig.protocol,
        AiApiProtocol.claudeMessages,
      );
      expect(store.settings.activeConfig.baseUrl, connectionConfig.baseUrl);
      expect(store.settings.activeConfig.model, connectionConfig.model);
      expect(store.keys.values.every((apiKey) => apiKey.isEmpty), isTrue);
      expect(networkCalls, 0);
    });
  });

  group('提示詞', () {
    testWidgets('聊天個性、引導與生成獨立編輯，自訂內容不被語系切換覆寫', (tester) async {
      await open(tester);
      await openPrompts(tester);
      await tester.tap(find.text('固定規則').first);
      await tester.pumpAndSettle();
      expect(find.text('套用'), findsNothing);
      expect(find.text('還原預設'), findsNothing);
      final rules = find.byKey(
        const ValueKey(ChatDiaryPromptPurpose.conversationRules),
      );
      expect(
        tester.widget<TextField>(rules).controller!.text,
        contains(testL10n.chatDiaryConversationRules),
      );
      expect(tester.widget<TextField>(rules).readOnly, isTrue);
      await tester.tap(find.text('關閉').last);
      await tester.pumpAndSettle();
      await prompt(tester, '預設個性');
      expect(
        find.text(lookupAppLocalizations(appZhLocale).chatDiaryPersonalityHelp),
        findsOneWidget,
      );
      final conversation = find.byKey(
        const ValueKey(ChatDiaryPromptPurpose.personality),
      );
      expect(
        tester.widget<TextField>(conversation).controller!.text,
        testL10n.chatDiaryDefaultPersonalityPrompt,
      );
      await tester.enterText(conversation, '我的自訂聊天指示');
      locale.value = appEnLocale;
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(conversation).controller!.text,
        '我的自訂聊天指示',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, testEnL10n.aiPromptApply),
      );
      await tester.pumpAndSettle();
      expect(find.text(testEnL10n.aiPromptCustom), findsOneWidget);
      expect(find.text(testEnL10n.aiPromptBuiltIn), findsNWidgets(4));
      await prompt(tester, 'Conversation guidance');
      final guidance = find.byKey(
        const ValueKey(ChatDiaryPromptPurpose.conversationGuidance),
      );
      await tester.enterText(guidance, 'Shared guidance');
      await tester.tap(
        find.widgetWithText(FilledButton, testEnL10n.aiPromptApply),
      );
      await tester.pumpAndSettle();
      await prompt(tester, testEnL10n.chatDiaryGenerationRulesLabel);
      final generationRules = find.byKey(
        const ValueKey(ChatDiaryPromptPurpose.generationRules),
      );
      expect(tester.widget<TextField>(generationRules).readOnly, isTrue);
      expect(
        tester.widget<TextField>(generationRules).controller!.text,
        testEnL10n.chatDiaryGenerationRules,
      );
      await tester.tap(find.text(testEnL10n.commonActionClose).last);
      await tester.pumpAndSettle();
      await prompt(tester, testEnL10n.chatDiaryGenerationGuidanceLabel);
      final generation = find.byKey(
        const ValueKey(ChatDiaryPromptPurpose.generationGuidance),
      );
      expect(
        tester.widget<TextField>(generation).controller!.text,
        testEnL10n.chatDiaryGenerationGuidancePrompt,
      );
      await tester.enterText(generation, 'My diary override');
      await tester.pump();
      await tester.tap(find.text(testEnL10n.aiPromptRestoreDefault));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(generation).controller!.text,
        testEnL10n.chatDiaryGenerationGuidancePrompt,
      );
      await tester.tap(
        find.widgetWithText(FilledButton, testEnL10n.aiPromptApply),
      );
      await tester.pumpAndSettle();
      await closePrompts(tester);
      final Finder englishKey = find.byKey(const ValueKey('ai-api-key-openai'));
      await tester.ensureVisible(englishKey);
      await tester.enterText(englishKey, 'synthetic-key');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(store.chatDiaryPrompts.personalityOverride, '我的自訂聊天指示');
      expect(store.chatDiaryPrompts.guidanceOverride, 'Shared guidance');
      expect(store.chatDiaryPrompts.generationOverride, isNull);
      expect(store.organizationPrompts.conversationOverride, isNull);
      expect(networkCalls, 0);
    });
    testWidgets('提示詞頁的內建預覽保留編輯稿，完整預覽採用尚未儲存的個性', (tester) async {
      await open(tester);
      await prompt(tester, testL10n.chatDiaryPersonalityLabel);
      final editor = find.byKey(
        const ValueKey(ChatDiaryPromptPurpose.personality),
      );
      await tester.enterText(editor, '新的個性草稿');
      await tester.pumpAndSettle();
      await tester.tap(find.text(testL10n.aiPromptViewBuiltIn));
      await tester.pumpAndSettle();
      final builtIn = find.byKey(const ValueKey('prompt-built-in-preview'));
      expect(tester.widget<TextField>(builtIn).readOnly, isTrue);
      expect(
        tester.widget<TextField>(builtIn).controller!.text,
        isNot(contains('新的個性草稿')),
      );
      await tester.tap(find.text(testL10n.commonActionClose).last);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(editor).controller!.text, '新的個性草稿');
      await tester.tap(
        find.widgetWithText(FilledButton, testL10n.aiPromptApply),
      );
      await tester.pumpAndSettle();
      final complete = find.byKey(
        const ValueKey<Key>(ValueKey('chat-full-prompt')),
      );
      for (final (previewKey, detailKey) in const [
        (
          'chat-full-prompt',
          ValueKey(ChatDiaryPromptPurpose.conversationRules),
        ),
        ('organization-full-prompt', ValueKey('organization-rules-prompt')),
        ('persona-full-prompt', ValueKey('persona-conversation-prompt')),
      ]) {
        expect(
          tester.getTopLeft(find.byKey(ValueKey<Key>(ValueKey(previewKey)))).dy,
          lessThan(tester.getTopLeft(find.byKey(ValueKey<Key>(detailKey))).dy),
        );
      }
      await tester.ensureVisible(complete);
      await tester.tap(complete);
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('chat-full-prompt'));
      expect(
        tester.widget<TextField>(field).controller!.text,
        resolveChatDiaryPrompt(
          ChatDiaryPromptPurpose.conversation,
          AppLanguage.zh,
          const ChatDiaryPromptSettings(personalityOverride: '新的個性草稿'),
        ),
      );
      expect(store.chatDiaryPrompts.personalityOverride, isNull);
      expect(networkCalls, 0);
    });
    testWidgets('既有完整生成提示詞作為引導，切換語言及儲存仍保留原文', (tester) async {
      const legacy = '  既有自訂提示詞，請用 JSON 輸出。\n保留這些換行與空白。  ';
      store.chatDiaryPrompts = const ChatDiaryPromptSettings(
        generationOverride: legacy,
      );
      await open(tester);
      await prompt(tester, testL10n.chatDiaryGenerationGuidanceLabel);
      final generation = find.byKey(
        const ValueKey(ChatDiaryPromptPurpose.generationGuidance),
      );
      expect(tester.widget<TextField>(generation).controller!.text, legacy);
      locale.value = appEnLocale;
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(generation).controller!.text, legacy);
      await tester.tap(
        find.widgetWithText(FilledButton, testEnL10n.aiPromptApply),
      );
      await tester.pumpAndSettle();
      await closePrompts(tester);
      final key = find.byKey(const ValueKey('ai-api-key-openai'));
      await tester.ensureVisible(key);
      await tester.enterText(key, 'synthetic-key');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(store.chatDiaryPrompts.generationOverride, legacy);
      expect(networkCalls, 0);
    });
    testWidgets('日記整理提示詞可自訂，還原後恢復內建', (tester) async {
      await open(tester);
      await openPrompts(tester);
      final fixedRules = find.text('固定規則').last;
      await tester.ensureVisible(fixedRules);
      await tester.tap(fixedRules);
      await tester.pumpAndSettle();
      final rules = find.byKey(const ValueKey('organization-rules-prompt'));
      expect(tester.widget<TextField>(rules).readOnly, isTrue);
      expect(
        tester.widget<TextField>(rules).controller!.text,
        allOf(
          contains(testL10n.organizationRules),
          contains(testL10n.organizationDiscussionRulesPrompt),
          contains(testL10n.organizationDraftRulesPrompt),
        ),
      );
      expect(find.text('套用'), findsNothing);
      expect(find.text('還原預設'), findsNothing);
      await tester.tap(find.text('關閉').last);
      await tester.pumpAndSettle();
      await prompt(tester, '需求對話');
      expect(find.textContaining('先不產生全文'), findsOneWidget);
      final conversation = find.byKey(
        const ValueKey('organization-conversation-prompt'),
      );
      expect(
        tester.widget<TextField>(conversation).controller!.text,
        testL10n.organizationConversationPrompt,
      );
      await tester.enterText(conversation, '自訂整理對話');
      await tester.tap(find.widgetWithText(FilledButton, '套用'));
      await tester.pumpAndSettle();
      expect(find.text('使用自訂提示詞'), findsOneWidget);
      await prompt(tester, '整理生成');
      expect(
        find.textContaining(testL10n.organizationGenerationHelp),
        findsOneWidget,
      );
      final generation = find.byKey(
        const ValueKey('organization-generation-prompt'),
      );
      await tester.enterText(generation, '不要輸出 JSON');
      await tester.pump();
      await tester.tap(find.text('還原預設'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(generation).controller!.text,
        testL10n.organizationGenerationPrompt,
      );
      await tester.tap(find.widgetWithText(FilledButton, '套用'));
      await tester.pumpAndSettle();
      await closePrompts(tester);
      final key = find.byKey(const ValueKey('ai-api-key-openai'));
      await tester.ensureVisible(key);
      await tester.enterText(key, 'synthetic-key');
      await tester.tap(find.widgetWithText(FilledButton, '儲存'));
      await tester.pumpAndSettle();
      expect(store.organizationPrompts.conversationOverride, '自訂整理對話');
      expect(store.organizationPrompts.generationOverride, isNull);
      expect(networkCalls, 0);
    });
    testWidgets('提示詞對話框捲動不會帶走設定頁位置', (tester) async {
      await open(tester);
      final ScrollController settingsScroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('ai-settings-scroll')),
          )
          .controller!;
      double pixels() => settingsScroll.offset;
      await tester.ensureVisible(promptEntry);
      await tester.pump();
      final double before = pixels();
      await openPrompts(tester);
      await prompt(tester, testL10n.chatDiaryPersonalityLabel);
      expect(pixels(), before);
      await tester.drag(
        find.byKey(const ValueKey(ChatDiaryPromptPurpose.personality)),
        const Offset(0, -240),
      );
      await tester.pumpAndSettle();
      expect(pixels(), before);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(pixels(), before);
      await tester.tap(find.text('取消').last);
      await tester.pumpAndSettle();
      expect(find.byType(AiPromptDialog), findsNothing);
      await closePrompts(tester);
      expect(pixels(), closeTo(before, 0.5));
    });
    testWidgets('小螢幕與鍵盤下可讀取完整提示詞，取消提示詞不改變設定', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await open(tester);
      expect(tester.takeException(), isNull);
      await prompt(tester, '預設個性');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.showKeyboard(
        find.byKey(const ValueKey(ChatDiaryPromptPurpose.personality)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.byKey(const ValueKey(ChatDiaryPromptPurpose.personality)),
        '取消的內容',
      );
      await tester.tap(find.text('取消').last);
      await tester.pumpAndSettle();
      expect(find.byType(AiPromptDialog), findsNothing);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await closePrompts(tester);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(store.chatDiaryPrompts.personalityOverride, isNull);
      expect(find.byType(AiConnectionSettingsDialog), findsNothing);
    });
  });

  group('模型與 Thinking', () {
    testWidgets('提供商列出五項，模型在金鑰上方且可手動輸入，清空金鑰後儲存移除', (tester) async {
      store.keys['openai'] = 'synthetic-key';
      store.settings = const AiConnectionSettings(
        connections: {
          'custom': AiConnectionConfig(provider: AiProvider.custom),
        },
      );
      await open(tester);
      expect(find.text('Ollama'), findsNothing);
      expect(find.text('OpenAI'), findsWidgets);
      expect(find.text('自訂'), findsWidgets);
      expect(find.text('Claude'), findsWidgets);
      expect(find.text('Gemini'), findsWidgets);
      expect(find.text('xAI'), findsWidgets);
      final modelRow = find.text('gpt-6.1-terra');
      final model = find.byKey(const ValueKey('ai-model-add-field-openai'));
      final key = find.byKey(const ValueKey('ai-api-key-openai'));
      final testConnection = find.byKey(const ValueKey('ai-test-openai'));
      expect(
        tester.getTopLeft(modelRow).dy,
        lessThan(tester.getTopLeft(key).dy),
      );
      expect(tester.getTopLeft(key).dy, lessThan(tester.getTopLeft(model).dy));
      expect(
        tester.getTopLeft(model).dy,
        lessThan(tester.getTopLeft(testConnection).dy),
      );
      expect(tester.widget<TextField>(key).obscureText, isTrue);
      expect(
        find.byKey(const ValueKey('ai-connection-delete-openai')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('ai-connection-delete-custom')),
        findsOneWidget,
      );
      final button = tester.widget<AppActionButton>(testConnection);
      expect(button.fullWidth, isFalse);
      expect(button.appearance, AppActionButtonAppearance.outlined);
      await tester.enterText(model, 'my-manual-model');
      await tester.pump();
      final Finder addModel = find.byKey(const ValueKey('ai-model-add-openai'));
      await tester.ensureVisible(addModel);
      await tester.tap(addModel);
      await tester.pump();
      final Finder customUrl = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == '服務網址',
      );
      await tester.ensureVisible(customUrl);
      await tester.enterText(customUrl, 'https://example.com/v1');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('ai-model-add-field-custom')),
        'local-model',
      );
      await tester.pump();
      final Finder addCustom = find.byKey(
        const ValueKey('ai-model-add-custom'),
      );
      await tester.ensureVisible(addCustom);
      await tester.tap(addCustom);
      await tester.pump();
      await tester.ensureVisible(key);
      await tester.tap(key);
      await tester.enterText(key, '');
      await tester.tap(find.widgetWithText(FilledButton, '儲存'));
      await tester.pumpAndSettle();
      expect(store.settings.activeConfig.model, 'local-model');
      expect(
        store.settings.connectionFor('openai').enabledModels,
        containsAll(['gpt-6.1-terra', 'my-manual-model']),
      );
      expect(store.keys['openai'], isNull);
    });
    testWidgets('官方模型用寫死清單，輸入時不會把既有列濾掉', (tester) async {
      store.keys['openai'] = 'synthetic-key';
      store.settings = const AiConnectionSettings(
        connections: {
          'openai': AiConnectionConfig(
            provider: AiProvider.openai,
            model: 'kept-model',
          ),
        },
      );
      await open(tester);
      expect(networkCalls, 0);
      expect(find.text('gpt-6.1-terra'), findsOneWidget);
      expect(find.text('kept-model'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ai-model-remove-openai-gpt-6.1-terra')),
        findsNothing,
      );
      expect(
        tester
            .widget<Switch>(
              find.byKey(
                const ValueKey('ai-model-switch-openai-gpt-6.1-terra'),
              ),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<Switch>(
              find.byKey(const ValueKey('ai-model-switch-openai-kept-model')),
            )
            .value,
        isTrue,
      );
      final field = find.byKey(const ValueKey('ai-model-add-field-openai'));
      await tester.enterText(field, 'manual-model-not-in-list');
      await tester.pump();
      expect(find.text('gpt-6.1-terra'), findsOneWidget);
      final Finder addModel = find.byKey(const ValueKey('ai-model-add-openai'));
      await tester.ensureVisible(addModel);
      await tester.tap(addModel);
      await tester.pump();
      expect(networkCalls, 0);
      await tester.tap(find.widgetWithText(FilledButton, '儲存'));
      await tester.pumpAndSettle();
      expect(store.settings.activeConfig.model, 'kept-model');
      expect(store.settings.activeConfig.addedModels, [
        'kept-model',
        'manual-model-not-in-list',
      ]);
      expect(
        store.settings.activeConfig.enabledModels,
        containsAll(['kept-model', 'manual-model-not-in-list']),
      );
    });
    testWidgets('打開設定不連線，寫死清單一直留在區塊裡', (tester) async {
      store.keys['openai'] = 'synthetic-key';
      await open(tester);
      expect(networkCalls, 0);
      final Finder addField = find.byKey(
        const ValueKey('ai-model-add-field-openai'),
      );
      await tester.ensureVisible(addField);
      await tester.tap(addField);
      await tester.pumpAndSettle();
      expect(networkCalls, 0);
      await tester.ensureVisible(find.text('更多'));
      await tester.tap(find.text('更多'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ai-model-catalog-dialog')),
        findsOneWidget,
      );
      final Finder catalog = find.byKey(
        const ValueKey('ai-model-catalog-dialog'),
      );
      expect(
        find.descendant(of: catalog, matching: find.text('自訂')),
        findsNothing,
      );
      await tester.tap(find.widgetWithText(TextButton, '關閉'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Switch>(
              find.byKey(
                const ValueKey('ai-model-switch-openai-gpt-6.1-terra'),
              ),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<Switch>(
              find.byKey(const ValueKey('ai-model-switch-openai-gpt-6-luna')),
            )
            .value,
        isFalse,
      );
      final Finder enabledModel = find.text('gpt-6.1-terra');
      final Finder disabledModel = find.text('gpt-6.1-sol');
      expect(
        tester.getTopLeft(enabledModel).dy,
        lessThan(tester.getTopLeft(disabledModel).dy),
      );
      final modelSwitch = find.byKey(
        const ValueKey('ai-model-switch-openai-gpt-6.1-terra'),
      );
      await tester.ensureVisible(modelSwitch);
      await tester.tap(modelSwitch);
      await tester.pump();
      expect(
        tester.getTopLeft(enabledModel).dy,
        lessThan(tester.getTopLeft(disabledModel).dy),
      );
      await tester.enterText(
        find.byKey(const ValueKey('ai-model-add-field-openai')),
        'luna',
      );
      await tester.pump();
      expect(find.text('gpt-6.1-terra'), findsOneWidget);
      expect(find.text('gpt-6-luna'), findsOneWidget);
      expect(networkCalls, 0);
    });
    testWidgets('主列表與更多共用思考設定，儲存後保留選擇且固定模型沒有選單', (tester) async {
      store.keys['openai'] = 'synthetic-key';
      await open(tester);
      final thinking = find.byKey(
        const ValueKey('ai-model-thinking-openai-gpt-6.1-terra'),
      );
      await tester.ensureVisible(thinking);
      await tester.tap(thinking);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, '高'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: thinking, matching: find.text('高')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('更多'));
      await tester.tap(find.text('更多'));
      await tester.pumpAndSettle();
      final catalogThinking = find.descendant(
        of: find.byKey(const ValueKey('ai-model-catalog-dialog')),
        matching: thinking,
      );
      expect(
        find.descendant(of: catalogThinking, matching: find.text('高')),
        findsOneWidget,
      );
      await tester.ensureVisible(catalogThinking);
      await tester.tap(catalogThinking);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, '低'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '關閉'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: thinking, matching: find.text('低')),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, '儲存'));
      await tester.pumpAndSettle();
      expect(store.settings.connectionFor('openai').thinkingLevels, {
        'gpt-6.1-terra': AiThinkingLevel.low,
      });
      expect(networkCalls, 0);
      expect(tester.takeException(), isNull);
    });
    testWidgets('更多內套用 Thinking 只修改草稿，巢狀視窗保留外層捲動位置', (tester) async {
      store.settings = AiConnectionSettings(
        connections: {
          'openai': addModel(defaultConnection(AiProvider.openai), 'manual'),
        },
      );
      store.keys['openai'] = 'synthetic-key';
      await open(tester);
      final settingsScroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('ai-settings-scroll')),
          )
          .controller!;
      await tester.ensureVisible(find.text('更多'));
      await tester.pumpAndSettle();
      final before = settingsScroll.offset;
      await tester.tap(find.text('更多'));
      await tester.pumpAndSettle();
      final thinking = find.descendant(
        of: find.byKey(const ValueKey('ai-model-catalog-dialog')),
        matching: find.byKey(const ValueKey('ai-model-thinking-openai-manual')),
      );
      await tester.ensureVisible(thinking);
      await tester.tap(thinking);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Thinking 設定…'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('thinking-format')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('不傳送 Thinking 參數').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '套用'));
      await tester.pumpAndSettle();
      expect(settingsScroll.offset, before);
      expect(store.settings.connectionFor('openai').thinkingOverrides, isEmpty);
      expect(
        find.descendant(of: thinking, matching: find.text('不傳送')),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, '關閉'));
      await tester.pumpAndSettle();
      expect(settingsScroll.offset, before);
      await tester.tap(find.widgetWithText(FilledButton, '儲存'));
      await tester.pumpAndSettle();
      expect(
        store.settings
            .connectionFor('openai')
            .thinkingOverrides['manual']!
            .levels,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('加入模型才依啟用狀態與供應商重排，取消不保存新增或設定', (tester) async {
      await open(tester);
      final initialOrder = modelOrder();
      for (final model in ['gpt-6.1-terra', 'gpt-6-luna']) {
        final modelSwitch = find.byKey(
          ValueKey('ai-model-switch-openai-$model'),
        );
        await tester.ensureVisible(modelSwitch);
        await tester.tap(modelSwitch);
        await tester.pumpAndSettle();
        expect(modelOrder(), initialOrder);
      }
      final thinking = find.byKey(
        const ValueKey('ai-model-thinking-openai-gpt-6.1-terra'),
      );
      await tester.ensureVisible(thinking);
      await tester.tap(thinking);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, '高'));
      await tester.pumpAndSettle();
      expect(modelOrder(), initialOrder);

      for (final name in ['new-model-b', 'new-model-a']) {
        final field = find.byKey(const ValueKey('ai-model-add-field-openai'));
        await tester.ensureVisible(field);
        await tester.enterText(field, name);
        await tester.pump();
        final add = find.byKey(const ValueKey('ai-model-add-openai'));
        await tester.ensureVisible(add);
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(
          modelOrder().indexOf('ai-model-openai-$name'),
          lessThan(modelOrder().indexOf('ai-model-claude-claude-haiku-5-5')),
        );
      }
      final order = modelOrder();
      expect(
        order.indexOf('ai-model-openai-new-model-b'),
        order.indexOf('ai-model-openai-gpt-6-luna') + 1,
      );
      expect(
        order.indexOf('ai-model-openai-new-model-a'),
        order.indexOf('ai-model-openai-new-model-b') + 1,
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(store.settings.connections, isEmpty);
      expect(networkCalls, 0);
      expect(tester.takeException(), isNull);
    });
    testWidgets('更多的手動模型可由開關左側移除，寫死的列留著', (tester) async {
      await open(tester);
      await tester.enterText(
        find.byKey(const ValueKey('ai-model-add-field-openai')),
        'extra-model',
      );
      await tester.pump();
      final Finder addModel = find.byKey(const ValueKey('ai-model-add-openai'));
      await tester.ensureVisible(addModel);
      await tester.tap(addModel);
      await tester.pump();
      await tester.ensureVisible(find.text('更多'));
      await tester.tap(find.text('更多'));
      await tester.pumpAndSettle();
      final catalog = find.byKey(const ValueKey('ai-model-catalog-dialog'));
      final Finder remove = find.descendant(
        of: catalog,
        matching: find.byKey(
          const ValueKey('ai-model-remove-openai-extra-model'),
        ),
      );
      final modelSwitch = find.descendant(
        of: catalog,
        matching: find.byKey(
          const ValueKey('ai-model-switch-openai-extra-model'),
        ),
      );
      await tester.ensureVisible(remove);
      expect(
        tester.getRect(remove).right,
        lessThanOrEqualTo(tester.getRect(modelSwitch).left),
      );
      expect(
        tester.getCenter(remove).dy,
        closeTo(tester.getCenter(modelSwitch).dy, 1),
      );
      expect(
        tester.widget<IconButton>(remove).tooltip,
        lookupAppLocalizations(appZhLocale).aiModelRemove('extra-model'),
      );
      await tester.tap(remove);
      await tester.pump();
      expect(find.text('extra-model'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, '關閉'));
      await tester.pumpAndSettle();
      expect(find.text('gpt-6.1-terra'), findsOneWidget);
      final Finder openaiKey = find.byKey(const ValueKey('ai-api-key-openai'));
      await tester.ensureVisible(openaiKey);
      await tester.enterText(openaiKey, 'synthetic-key');
      await tester.tap(find.widgetWithText(FilledButton, '儲存'));
      await tester.pumpAndSettle();
      expect(
        store.settings.activeConfig.addedModels,
        isNot(contains('extra-model')),
      );
      expect(store.settings.activeConfig.model, 'gpt-6.1-terra');
      expect(networkCalls, 0);
    });
    testWidgets('重複加入已關閉模型會啟用並重排，空白輸入不改順序', (tester) async {
      await open(tester);
      await tester.enterText(
        find.byKey(const ValueKey('ai-model-add-field-openai')),
        '  gpt-6-luna  ',
      );
      await tester.pump();
      final Finder addModel = find.byKey(const ValueKey('ai-model-add-openai'));
      await tester.ensureVisible(addModel);
      await tester.tap(addModel);
      await tester.pump();
      expect(find.text('gpt-6-luna'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ai-model-remove-openai-gpt-6-luna')),
        findsNothing,
      );
      expect(
        tester
            .widget<Switch>(
              find.byKey(const ValueKey('ai-model-switch-openai-gpt-6-luna')),
            )
            .value,
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('ai-model-openai-gpt-6-luna')),
          matching: find.text('預設'),
        ),
        findsNothing,
      );
      expect(
        modelOrder().indexOf('ai-model-openai-gpt-6-luna'),
        lessThan(modelOrder().indexOf('ai-model-claude-claude-haiku-5-5')),
      );
      final terraSwitch = find.byKey(
        const ValueKey('ai-model-switch-openai-gpt-6.1-terra'),
      );
      await tester.ensureVisible(terraSwitch);
      await tester.tap(terraSwitch);
      await tester.pumpAndSettle();
      final beforeBlank = modelOrder();
      await tester.enterText(
        find.byKey(const ValueKey('ai-model-add-field-openai')),
        '   ',
      );
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('ai-model-add-openai')),
            )
            .onPressed,
        isNull,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(modelOrder(), beforeBlank);
      expect(networkCalls, 0);
    });
  });

  group('連線測試', () {
    testWidgets('連線測試顯示旋轉動畫並以設定視窗上方的 toast 回報成功', (tester) async {
      const connectionConfig = AiConnectionConfig(
        provider: AiProvider.custom,
        model: 'model',
        baseUrl: 'https://test.example/v1',
      );
      store.settings = AiConnectionSettings(
        activeConnectionId: 'custom',
        connections: {'custom': connectionConfig},
      );
      connectionGate = Completer<void>();
      await open(tester);
      final model = find.byKey(const ValueKey('ai-model-add-field-custom'));
      await tester.ensureVisible(model);
      await tester.showKeyboard(model);
      await tester.tap(model);
      await tester.pumpAndSettle();
      final Finder testConnection = find.byKey(
        const ValueKey('ai-test-custom'),
      );
      await tester.ensureVisible(testConnection);
      await tester.tap(testConnection);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: model, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isFalse,
      );
      await tester.tap(testConnection);
      expect(lastClient!.connectionTests, 1);
      expect(tester.widget<AppActionButton>(testConnection).loading, isTrue);
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const ValueKey('ai-model-thinking-custom-model')),
            )
            .onTap,
        isNull,
      );
      expect(
        tester
            .widget<Switch>(
              find.byKey(const ValueKey('ai-model-switch-custom-model')),
            )
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('ai-model-remove-custom-model')),
            )
            .onPressed,
        isNull,
      );
      connectionGate!.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<AppActionButton>(testConnection).loading, isFalse);
      expect(find.text('連線成功'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('連線成功'),
          matching: find.byType(AiConnectionSettingsDialog),
        ),
        findsNothing,
      );
      expect(find.text('允許連線'), findsNothing);
    });
    testWidgets('缺少模型或必要金鑰時立即以 toast 提示且不連線', (tester) async {
      await open(tester);
      final Finder testConnection = find.byKey(
        const ValueKey('ai-test-openai'),
      );
      await tester.ensureVisible(testConnection);
      await tester.tap(testConnection);
      await tester.pumpAndSettle();
      expect(find.text(testL10n.aiErrorConfiguration), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text(testL10n.aiErrorConfiguration),
          matching: find.byType(AiConnectionSettingsDialog),
        ),
        findsNothing,
      );
      expect(networkCalls, 0);
      expect(tester.widget<AppActionButton>(testConnection).loading, isFalse);
    });
    testWidgets('連線逾時以 toast 提示並解除載入狀態', (tester) async {
      const connectionConfig = AiConnectionConfig(
        provider: AiProvider.custom,
        model: 'model',
        baseUrl: 'https://test.example/v1',
      );
      store.settings = const AiConnectionSettings(
        activeConnectionId: 'custom',
        connections: {'custom': connectionConfig},
      );
      connectionFailure = const AiFailure(AiErrorCode.timeout);
      await open(tester);
      final Finder testConnection = find.byKey(
        const ValueKey('ai-test-custom'),
      );
      await tester.ensureVisible(testConnection);
      await tester.tap(testConnection);
      await tester.pumpAndSettle();
      expect(find.text(testL10n.aiErrorTimeout), findsOneWidget);
      expect(tester.widget<AppActionButton>(testConnection).loading, isFalse);
    });
    for (final close in [false, true]) {
      testWidgets('${close ? '關閉設定' : '切入背景'}後不顯示晚到的連線結果', (tester) async {
        const connectionConfig = AiConnectionConfig(
          provider: AiProvider.custom,
          model: 'model',
          baseUrl: 'https://test.example/v1',
        );
        store.settings = const AiConnectionSettings(
          activeConnectionId: 'custom',
          connections: {'custom': connectionConfig},
        );
        connectionGate = Completer<void>();
        await open(tester);
        final Finder testConnection = find.byKey(
          const ValueKey('ai-test-custom'),
        );
        await tester.ensureVisible(testConnection);
        await tester.tap(testConnection);
        await tester.pump(const Duration(milliseconds: 100));
        if (close) {
          Navigator.of(tester.element(find.byType(AiConnectionSettingsDialog)))
              .pop();
        } else {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
        }
        await tester.pump(const Duration(milliseconds: 300));
        connectionGate!.complete();
        await tester.pump();
        if (!close) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        }
        await tester.pumpAndSettle();
        expect(lastClient!.closed, isTrue);
        expect(find.text('連線成功'), findsNothing);
      });
    }
    testWidgets('連線測試失敗顯示 HTTP 狀態且不曝光服務商錯誤原文', (tester) async {
      const connectionConfig = AiConnectionConfig(
        provider: AiProvider.custom,
        model: 'model',
        baseUrl: 'https://test.example/v1',
      );
      store.settings = AiConnectionSettings(
        activeConnectionId: 'custom',
        connections: {'custom': connectionConfig},
      );
      connectionFailure = const AiFailure(AiErrorCode.network, status: 503);
      await open(tester);
      final Finder testConnection = find.byKey(
        const ValueKey('ai-test-custom'),
      );
      await tester.ensureVisible(testConnection);
      await tester.tap(testConnection);
      await tester.pumpAndSettle();
      expect(find.textContaining('HTTP 503'), findsOneWidget);
      expect(lastClient!.connectionTests, 1);
      expect(tester.widget<AppActionButton>(testConnection).loading, isFalse);
    });
    testWidgets('連線測試的未知例外不顯示成回應不完整', (tester) async {
      const connectionConfig = AiConnectionConfig(
        provider: AiProvider.custom,
        model: 'model',
        baseUrl: 'https://test.example/v1',
      );
      store.settings = AiConnectionSettings(
        activeConnectionId: 'custom',
        connections: {'custom': connectionConfig},
      );
      throwOnConnection = true;
      await open(tester);
      final Finder testConnection = find.byKey(
        const ValueKey('ai-test-custom'),
      );
      await tester.ensureVisible(testConnection);
      await tester.tap(testConnection);
      await tester.pumpAndSettle();
      expect(find.text(testL10n.aiErrorUnexpected), findsOneWidget);
      expect(find.text(testL10n.aiErrorResponse), findsNothing);
    });
  });

  group('版面', () {
    testWidgets('AI 總開關只在設定首頁，關閉後仍能開啟與編輯 AI 設定', (tester) async {
      await tester.pumpWidget(
        // app() 覆寫的 appSessionProvider 必須在外層，AI 開關的 notifier 才會讀到解鎖的 session。
        app(
          child: settingsTestScope(
            wrapMaterialApp: false,
            sessionState: const AppSessionState(
              status: AppLockStatus.unlocked,
              session: UnlockedVaultSession(
                vaultId: 'vault',
                trustedDevice: true,
              ),
            ),
            child: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('ai-enabled-switch'));
      await scrollSettingsPageUntilVisible(tester, toggle);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      expect(tester.widget<SwitchListTile>(toggle).onChanged, isNotNull);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      final open = appActionButton(testL10n.aiOpenSettings);
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.byType(AiConnectionSettingsDialog), findsOneWidget);
      // 設定頁仍在對話框下方，只驗證對話框內沒有總開關。
      expect(
        find.descendant(
          of: find.byType(AiConnectionSettingsDialog),
          matching: find.byKey(const ValueKey('ai-enabled-switch')),
        ),
        findsNothing,
      );
      final test = find.byKey(const ValueKey('ai-test-openai'));
      await tester.ensureVisible(test);
      await tester.pumpAndSettle();
      expect(tester.widget<AppActionButton>(test).onPressed, isNull);
      expect(networkCalls, 0);
      await tester.tap(
        find.widgetWithText(TextButton, testL10n.commonActionCancel),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    });
  });

  testWidgets('預設模型沒有金鑰時改回傳已有金鑰的連線', (tester) async {
    addTearDown(() async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox.shrink());
    });
    final initial = defaultConnection(AiProvider.openai);
    AiConnectionSettingsResult? result;
    await tester.pumpWidget(
      app(
        child: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showAiConnectionSettingsDialog(
                context,
                initialConnection: initial,
              );
            },
            child: Text(context.l10n.aiSettings),
          ),
        ),
      ),
    );
    await tester.tap(find.text('AI 設定'));
    await tester.pumpAndSettle();
    final key = find.byKey(const ValueKey('ai-api-key-gemini'));
    await tester.ensureVisible(key);
    await tester.enterText(key, 'gemini-key');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
    await tester.pumpAndSettle();
    expect(result?.chatConnection?.provider, AiProvider.gemini);
    expect(result?.chatConnection?.model, 'gemini-3.8-flash');
    expect(result?.chatConnection?.model, isNot(initial.model));
    expect(await store.readApiKey(result!.chatConnection!), 'gemini-key');
  });

  testWidgets('原本的模型已有金鑰時儲存後仍用同一個', (tester) async {
    addTearDown(() async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox.shrink());
    });
    final initial = defaultConnection(AiProvider.openai);
    await store.saveApiKey(initial, 'openai-key');
    AiConnectionSettingsResult? result;
    await tester.pumpWidget(
      app(
        child: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showAiConnectionSettingsDialog(
                context,
                initialConnection: initial,
              );
            },
            child: Text(context.l10n.aiSettings),
          ),
        ),
      ),
    );
    await tester.tap(find.text('AI 設定'));
    await tester.pumpAndSettle();
    final key = find.byKey(const ValueKey('ai-api-key-gemini'));
    await tester.ensureVisible(key);
    await tester.enterText(key, 'gemini-key');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
    await tester.pumpAndSettle();
    expect(result?.chatConnection?.provider, AiProvider.openai);
    expect(result?.chatConnection?.model, initial.model);
  });
}
