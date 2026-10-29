import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_prompt_resolver.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_providers.dart';
import 'package:quill_diary/application/session/app_session_controller.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_connection_labels.dart';
import 'package:quill_diary/presentation/ai/ai_connection_settings_dialog.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_prompt_dialog.dart';
import 'package:quill_diary/presentation/settings/pages/settings_page.dart';
import 'package:quill_diary/presentation/settings/widgets/settings_sections.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';

import '../../helpers/ai/ai_test_helpers.dart';
import '../../helpers/presentation/settings/settings_test_scope.dart';
import '../../helpers/shared/widget_test_app.dart';

class _SettingsSession extends AppSessionController {
  @override
  AppSessionState build() =>
      const AppSessionState(status: AppLockStatus.uninitialized);
}

void main() {
  late MemoryAiConnectionSettingsStore store;
  late MemoryChatDiarySettingsStore diary;
  late ValueNotifier<Locale> locale;
  var networkCalls = 0;
  var modelFailure = false;
  AiFailure? connectionFailure;
  var throwOnConnection = false;
  Completer<void>? connectionGate;
  Completer<void>? modelsGate;
  FakeAiClient? lastClient;
  Widget app({Widget? child}) => ProviderScope(
    overrides: [
      aiConnectionSettingsStoreProvider.overrideWithValue(store),
      chatDiarySettingsStoreProvider.overrideWithValue(diary),
      appSessionProvider.overrideWith(_SettingsSession.new),
      aiClientFactoryProvider.overrideWithValue((connectionConfig, key) {
        networkCalls++;
        return lastClient = FakeAiClient(connectionConfig)
          ..failure = connectionFailure
          ..response = throwOnConnection ? () => throw StateError('未知') : null
          ..connectionGate = connectionGate?.future
          ..modelsGate = modelsGate?.future
          ..modelFailure = modelFailure
              ? const AiFailure(AiErrorCode.network)
              : null;
      }),
    ],
    child: ValueListenableBuilder<Locale>(
      valueListenable: locale,
      builder: (context, value, _) => widgetTestApp(
        locale: value,
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
    store = MemoryAiConnectionSettingsStore();
    diary = MemoryChatDiarySettingsStore();
    locale = ValueNotifier(appZhLocale);
    networkCalls = 0;
    modelFailure = false;
    connectionFailure = null;
    throwOnConnection = false;
    connectionGate = null;
    modelsGate = null;
    lastClient = null;
  });
  tearDown(() => locale.dispose());
  Future<void> open(WidgetTester tester) async {
    addTearDown(() async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox.shrink());
    });
    await tester.pumpWidget(app());
    await tester.tap(find.text('AI 設定'));
    await tester.pumpAndSettle();
  }

  Future<void> prompt(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  for (final language in ['zh', 'en']) {
    testWidgets('設定頁以單一 AI 卡片開啟設定，$language 窄螢幕大字級可操作', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      locale.value = Locale(language);
      final l10n = lookupAppLocalizations(locale.value);
      await tester.pumpWidget(
        settingsTestScope(
          wrapMaterialApp: false,
          child: app(child: const SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.aiSettings), findsNothing);
      final button = appActionButton(l10n.aiOpenSettings);
      await scrollSettingsPageUntilVisible(tester, button);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      final card = find.ancestor(
        of: button,
        matching: find.byType(SettingsSectionCard),
      );
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.byType(AppActionButton)),
        findsOneWidget,
      );
      expect(
        tester.widget<AppActionButton>(button).appearance,
        AppActionButtonAppearance.primary,
      );
      expect(tester.widget<AppActionButton>(button).fullWidth, isTrue);
      final sections = tester
          .widget<AppScrollablePageBody>(find.byType(AppScrollablePageBody))
          .children
          .whereType<SettingsSectionCard>()
          .toList();
      final aiIndex = sections.indexWhere(
        (section) => section.title == l10n.aiSettings,
      );
      expect(
        sections[aiIndex - 1].title,
        l10n.settingsUnlockMethodSectionTitle,
      );
      expect(
        sections[aiIndex + 1].title,
        l10n.settingsImportExportSectionTitle,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(AiConnectionSettingsDialog), findsOneWidget);
      expect(find.text(l10n.aiSettingsHint), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.commonActionCancel));
      await tester.pumpAndSettle();
      expect(find.byType(AiConnectionSettingsDialog), findsNothing);
      expect(networkCalls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('設定讀取失敗時停用儲存且不覆寫既有資料', (tester) async {
    store.failReads = true;
    await open(tester);
    expect(find.text('無法保存進度，請確認儲存空間後重試。'), findsOneWidget);
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
      reading.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AiConnectionSettingsDialog), findsNothing);
      expect(diary.reads, readingKey ? 1 : 0);
      expect(store.keyReads, readingKey ? 1 : 0);
      expect(networkCalls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('開啟設定不連線，取消不保存金鑰或聊天日記設定', (tester) async {
    await open(tester);
    final key = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'API Key',
    );
    await tester.enterText(key, '不能保存的測試金鑰');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(store.keys, isEmpty);
    expect(networkCalls, 0);
  });

  testWidgets('兩份提示詞在獨立對話框編輯，自訂內容不被語系切換覆寫', (tester) async {
    await open(tester);
    expect(find.text('使用內建提示詞'), findsNWidgets(2));
    await prompt(tester, '對話引導');
    expect(find.text('這些提示詞決定 AI 怎麼聊天、怎麼寫日記，儲存後從下一次回覆或生成生效。'), findsOneWidget);
    final conversation = find.byKey(
      const ValueKey(ChatDiaryPromptPurpose.conversation),
    );
    expect(
      tester.widget<TextField>(conversation).controller!.text,
      contains('請一律使用繁體中文'),
    );
    await tester.enterText(conversation, '我的自訂聊天指示');
    locale.value = appEnLocale;
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(conversation).controller!.text, '我的自訂聊天指示');
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Custom prompt'), findsOneWidget);
    expect(find.text('Built-in prompt'), findsOneWidget);
    await prompt(tester, 'Diary generation');
    final generation = find.byKey(
      const ValueKey(ChatDiaryPromptPurpose.generation),
    );
    expect(
      tester.widget<TextField>(generation).controller!.text,
      contains('write both the title and body in natural English'),
    );
    await tester.enterText(generation, 'My diary override');
    await tester.tap(find.text('Restore default'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(generation).controller!.text,
      contains('natural English'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(diary.settings.prompts.conversationOverride, '我的自訂聊天指示');
    expect(diary.settings.prompts.generationOverride, isNull);
    expect(networkCalls, 0);
  });

  testWidgets('小螢幕與鍵盤下可讀取完整提示詞，取消提示詞不改變設定', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await open(tester);
    expect(tester.takeException(), isNull);
    await prompt(tester, '對話引導');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.showKeyboard(
      find.byKey(const ValueKey(ChatDiaryPromptPurpose.conversation)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byKey(const ValueKey(ChatDiaryPromptPurpose.conversation)),
      '取消的內容',
    );
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(find.byType(ChatDiaryPromptDialog), findsNothing);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(diary.settings.prompts.conversationOverride, isNull);
    expect(find.byType(AiConnectionSettingsDialog), findsNothing);
  });

  testWidgets('提供商只列四項，模型在金鑰上方且可手動輸入，清空金鑰後儲存移除', (tester) async {
    store.keys['openai'] = 'synthetic-key';
    await open(tester);
    await tester.tap(find.byType(DropdownButtonFormField<AiProvider>));
    await tester.pumpAndSettle();
    expect(find.text('Ollama'), findsNothing);
    expect(find.text('自訂'), findsOneWidget);
    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('Gemini'), findsOneWidget);
    await tester.tap(find.text('OpenAI').last);
    await tester.pumpAndSettle();
    final model = find.byKey(const ValueKey('ai-model-autocomplete'));
    final key = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'API Key',
    );
    expect(tester.getTopLeft(model).dy, lessThan(tester.getTopLeft(key).dy));
    expect(tester.widget<TextField>(key).obscureText, isTrue);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    final button = tester.widget<AppActionButton>(find.byType(AppActionButton));
    expect(button.fullWidth, isTrue);
    expect(button.appearance, AppActionButtonAppearance.primary);
    await tester.enterText(model, 'my-manual-model');
    await tester.tap(key);
    await tester.enterText(key, '');
    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
    await tester.pumpAndSettle();
    expect(store.settings.activeConfig.model, 'my-manual-model');
    expect(store.keys['openai'], isEmpty);
  });

  testWidgets('autocomplete 取得清單後在本機搜尋，任意名稱皆可保存', (tester) async {
    store.keys['openai'] = 'synthetic-key';
    await open(tester);
    final field = find.byKey(const ValueKey('ai-model-autocomplete'));
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'test');
    await tester.pumpAndSettle();
    expect(find.text('test-model'), findsOneWidget);
    expect(networkCalls, 1);
    await tester.enterText(field, 'manual-model-not-in-list');
    await tester.pumpAndSettle();
    expect(find.text('test-model'), findsNothing);
    expect(find.byType(MenuItemButton), findsNothing);
    expect(find.text('找不到模型時，也可以直接輸入名稱。'), findsNothing);
    expect(networkCalls, 1);
    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
    await tester.pumpAndSettle();
    expect(store.settings.activeConfig.model, 'manual-model-not-in-list');
  });

  testWidgets('切換 Custom 網址不沿用其他目的地的金鑰，取消不寫入', (tester) async {
    const connectionConfig = AiConnectionConfig(
      provider: AiProvider.custom,
      model: 'model',
      baseUrl: 'https://first.example/v1',
    );
    store.settings = const AiConnectionSettings(
      provider: AiProvider.custom,
      configs: {AiProvider.custom: connectionConfig},
    );
    store.keys[connectionConfig.credentialId] = 'first-synthetic-key';
    await open(tester);
    final url = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == '服務網址',
    );
    final key = find.byWidgetPredicate((w) => w is TextField && w.obscureText);
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
    await open(tester);
    await tester.tap(find.byType(DropdownButtonFormField<AiProvider>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自訂'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'API Key',
      ),
      'orphan-key',
    );
    await tester.tap(find.byType(DropdownButtonFormField<AiProvider>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenAI').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
    await tester.pumpAndSettle();
    expect(find.text('請先填寫服務網址、模型與必要的 API Key。'), findsOneWidget);
    expect(find.text('無法保存進度，請確認儲存空間後重試。'), findsNothing);
    expect(find.byType(AiConnectionSettingsDialog), findsOneWidget);
    expect(store.keys.values, isNot(contains('orphan-key')));
  });

  testWidgets('模型清單讀取失敗保留手動名稱與輸入焦點', (tester) async {
    store.settings = AiConnectionSettings(
      configs: const {
        AiProvider.openai: AiConnectionConfig(
          provider: AiProvider.openai,
          model: 'manual-model',
        ),
      },
    );
    store.keys['openai'] = 'synthetic-key';
    modelFailure = true;
    await open(tester);
    final field = find.byKey(const ValueKey('ai-model-autocomplete'));
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, 'manual-model');
    await tester.enterText(field, 'another-manual-model');
    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
    await tester.pumpAndSettle();
    expect(store.settings.activeConfig.model, 'another-manual-model');
    expect(networkCalls, 1);
  });

  testWidgets('介紹依提供商顯示政策與 HTTP 說明，連線不再要求確認', (tester) async {
    const connectionConfig = AiConnectionConfig(
      provider: AiProvider.gemini,
      model: 'test-model',
    );
    store.settings = const AiConnectionSettings(
      provider: AiProvider.gemini,
      configs: {AiProvider.gemini: connectionConfig},
    );
    store.keys['gemini'] = 'synthetic-key';
    await open(tester);
    expect(find.textContaining('Gemini 免費與付費'), findsOneWidget);
    expect(find.text('查看服務商資料政策'), findsNothing);
    expect(find.text('服務連線'), findsNothing);
    await tester.ensureVisible(find.text('測試連線'));
    await tester.tap(find.text('測試連線'));
    await tester.pumpAndSettle();
    expect(find.text('允許連線'), findsNothing);
    expect(networkCalls, 1);
    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<AiProvider>),
    );
    await tester.tap(find.byType(DropdownButtonFormField<AiProvider>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自訂').last);
    await tester.pumpAndSettle();
    final url = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == '服務網址',
    );
    await tester.enterText(url, 'http://127.0.0.1:11434');
    await tester.pumpAndSettle();
    expect(find.textContaining('Gemini 免費與付費'), findsNothing);
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
      provider: AiProvider.custom,
      configs: {AiProvider.custom: connectionConfig},
    );
    await open(tester);
    final field = find.byType(DropdownButtonFormField<AiApiProtocol>);
    await tester.tap(field);
    await tester.pumpAndSettle();
    for (final protocol in AiApiProtocol.values) {
      expect(find.text(aiProtocolLabel(protocol)), findsWidgets);
    }
    await tester.tap(find.text('Claude Messages'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
    await tester.pumpAndSettle();
    expect(store.settings.activeConfig.protocol, AiApiProtocol.claudeMessages);
    expect(store.settings.activeConfig.baseUrl, connectionConfig.baseUrl);
    expect(store.settings.activeConfig.model, connectionConfig.model);
    expect(store.keys.values.every((apiKey) => apiKey.isEmpty), isTrue);
    expect(networkCalls, 0);
  });

  testWidgets('連線測試顯示旋轉動畫並以設定視窗上方的 toast 回報成功', (tester) async {
    const connectionConfig = AiConnectionConfig(
      provider: AiProvider.custom,
      model: 'model',
      baseUrl: 'https://test.example/v1',
    );
    store.settings = AiConnectionSettings(
      provider: AiProvider.custom,
      configs: {AiProvider.custom: connectionConfig},
    );
    connectionGate = Completer<void>();
    await open(tester);
    final model = find.byKey(const ValueKey('ai-model-autocomplete'));
    await tester.showKeyboard(model);
    await tester.tap(model);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsOneWidget);
    await tester.ensureVisible(find.text('測試連線'));
    await tester.tap(find.text('測試連線'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<TextField>(model).focusNode!.hasFocus, isFalse);
    expect(find.byType(MenuItemButton), findsNothing);
    await tester.tap(find.text('測試連線'));
    expect(lastClient!.connectionTests, 1);
    expect(
      tester.widget<AppActionButton>(find.byType(AppActionButton)).loading,
      isTrue,
    );
    connectionGate!.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<AppActionButton>(find.byType(AppActionButton)).loading,
      isFalse,
    );
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
    await tester.ensureVisible(find.text('測試連線'));
    await tester.tap(find.text('測試連線'));
    await tester.pumpAndSettle();
    expect(find.text('請先填寫服務網址、模型與必要的 API Key。'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('請先填寫服務網址、模型與必要的 API Key。'),
        matching: find.byType(AiConnectionSettingsDialog),
      ),
      findsNothing,
    );
    expect(networkCalls, 0);
    expect(
      tester.widget<AppActionButton>(find.byType(AppActionButton)).loading,
      isFalse,
    );
  });

  testWidgets('連線逾時以 toast 提示並解除載入狀態', (tester) async {
    const connectionConfig = AiConnectionConfig(
      provider: AiProvider.custom,
      model: 'model',
      baseUrl: 'https://test.example/v1',
    );
    store.settings = const AiConnectionSettings(
      provider: AiProvider.custom,
      configs: {AiProvider.custom: connectionConfig},
    );
    connectionFailure = const AiFailure(AiErrorCode.timeout);
    await open(tester);
    await tester.ensureVisible(find.text('測試連線'));
    await tester.tap(find.text('測試連線'));
    await tester.pumpAndSettle();
    expect(find.text('等候服務回應逾時，請稍後重試或確認模型是否可用。'), findsOneWidget);
    expect(
      tester.widget<AppActionButton>(find.byType(AppActionButton)).loading,
      isFalse,
    );
  });

  for (final close in [false, true]) {
    testWidgets('${close ? '關閉設定' : '切入背景'}後不顯示晚到的連線結果', (tester) async {
      const connectionConfig = AiConnectionConfig(
        provider: AiProvider.custom,
        model: 'model',
        baseUrl: 'https://test.example/v1',
      );
      store.settings = const AiConnectionSettings(
        provider: AiProvider.custom,
        configs: {AiProvider.custom: connectionConfig},
      );
      connectionGate = Completer<void>();
      await open(tester);
      await tester.ensureVisible(find.text('測試連線'));
      await tester.tap(find.text('測試連線'));
      await tester.pump(const Duration(milliseconds: 100));
      if (close) {
        Navigator.of(tester.element(find.byType(AiConnectionSettingsDialog)))
            .pop();
      } else {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
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
      provider: AiProvider.custom,
      configs: {AiProvider.custom: connectionConfig},
    );
    connectionFailure = const AiFailure(AiErrorCode.network, status: 503);
    await open(tester);
    await tester.ensureVisible(find.text('測試連線'));
    await tester.tap(find.text('測試連線'));
    await tester.pumpAndSettle();
    expect(find.textContaining('HTTP 503'), findsOneWidget);
    expect(lastClient!.connectionTests, 1);
    expect(
      tester.widget<AppActionButton>(find.byType(AppActionButton)).loading,
      isFalse,
    );
  });

  testWidgets('連線測試的未知例外不顯示成回應不完整', (tester) async {
    const connectionConfig = AiConnectionConfig(
      provider: AiProvider.custom,
      model: 'model',
      baseUrl: 'https://test.example/v1',
    );
    store.settings = AiConnectionSettings(
      provider: AiProvider.custom,
      configs: {AiProvider.custom: connectionConfig},
    );
    throwOnConnection = true;
    await open(tester);
    await tester.ensureVisible(find.text('測試連線'));
    await tester.tap(find.text('測試連線'));
    await tester.pumpAndSettle();
    expect(find.text('這次沒有完成，內容已保留，請再試一次。'), findsOneWidget);
    expect(find.text('服務未回傳完整可用內容，請重試或確認模型設定。'), findsNothing);
  });

  testWidgets('模型清單載入不會擋住連線測試，取消查詢後不覆寫結果', (tester) async {
    const connectionConfig = AiConnectionConfig(
      provider: AiProvider.custom,
      model: 'model',
      baseUrl: 'https://test.example/v1',
    );
    store.settings = AiConnectionSettings(
      provider: AiProvider.custom,
      configs: {AiProvider.custom: connectionConfig},
    );
    modelsGate = Completer<void>();
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('ai-model-autocomplete')));
    await tester.pump(const Duration(milliseconds: 100));
    final modelClient = lastClient!;
    await tester.ensureVisible(find.text('測試連線'));
    await tester.tap(find.text('測試連線'));
    await tester.pumpAndSettle();
    expect(modelClient.closed, isTrue);
    expect(lastClient!.connectionTests, 1);
    expect(find.text('連線成功'), findsOneWidget);
    modelsGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('連線成功'), findsOneWidget);
  });
}
