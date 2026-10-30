import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_prompt_resolver.dart';
import 'package:quill_diary/application/session/app_session_controller.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
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
  Widget app({Widget? child}) => ProviderScope(
    overrides: [
      aiSettingsStoreProvider.overrideWithValue(store),
      appSessionProvider.overrideWith(_SettingsSession.new),
      aiClientFactoryProvider.overrideWithValue((connectionConfig, key) {
        networkCalls++;
        return lastClient = FakeAiClient(connectionConfig)
          ..failure = connectionFailure
          ..response = throwOnConnection ? () => throw StateError('未知') : null
          ..connectionGate = connectionGate?.future;
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
    store = OverviewAiSettingsStore();
    locale = ValueNotifier(appZhLocale);
    networkCalls = 0;
    connectionFailure = null;
    throwOnConnection = false;
    connectionGate = null;
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
      expect(find.text(l10n.aiSettingsLead), findsOneWidget);
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
      expect(store.reads, 1);
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
      contains('一律使用繁體中文'),
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
      contains('write the title and body in natural English'),
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
    final Finder englishKey = find.byKey(const ValueKey('ai-api-key-openai'));
    await tester.ensureVisible(englishKey);
    await tester.enterText(englishKey, 'synthetic-key');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(store.chatDiary.prompts.conversationOverride, '我的自訂聊天指示');
    expect(store.chatDiary.prompts.generationOverride, isNull);
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
    settingsScroll.jumpTo(80);
    await tester.pump();
    await tester.ensureVisible(find.text('對話引導'));
    await tester.pump();
    final double before = pixels();
    expect(before, greaterThan(0));
    await tester.tap(find.text('對話引導'));
    await tester.pumpAndSettle();
    expect(pixels(), before);
    await tester.drag(
      find.byKey(const ValueKey(ChatDiaryPromptPurpose.conversation)),
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
    expect(find.byType(ChatDiaryPromptDialog), findsNothing);
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
    expect(store.chatDiary.prompts.conversationOverride, isNull);
    expect(find.byType(AiConnectionSettingsDialog), findsNothing);
  });

  testWidgets('提供商列出五項，模型在金鑰上方且可手動輸入，清空金鑰後儲存移除', (tester) async {
    store.keys['openai'] = 'synthetic-key';
    await open(tester);
    expect(find.text('Ollama'), findsNothing);
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('自訂'), findsOneWidget);
    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('Gemini'), findsOneWidget);
    expect(find.text('xAI'), findsOneWidget);
    final modelRow = find.text('OpenAI/gpt-6.1-terra');
    final model = find.byKey(const ValueKey('ai-model-add-field-openai'));
    final key = find.byKey(const ValueKey('ai-api-key-openai'));
    final testConnection = find.byKey(const ValueKey('ai-test-openai'));
    expect(tester.getTopLeft(modelRow).dy, lessThan(tester.getTopLeft(key).dy));
    expect(tester.getTopLeft(key).dy, lessThan(tester.getTopLeft(model).dy));
    expect(
      tester.getTopLeft(model).dy,
      lessThan(tester.getTopLeft(testConnection).dy),
    );
    expect(tester.widget<TextField>(key).obscureText, isTrue);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
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
      (widget) => widget is TextField && widget.decoration?.labelText == '服務網址',
    );
    await tester.ensureVisible(customUrl);
    await tester.enterText(customUrl, 'https://example.com/v1');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ai-model-add-field-custom')),
      'local-model',
    );
    await tester.pump();
    final Finder addCustom = find.byKey(const ValueKey('ai-model-add-custom'));
    await tester.ensureVisible(addCustom);
    await tester.tap(addCustom);
    await tester.pump();
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.enterText(key, '');
    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
    await tester.pumpAndSettle();
    expect(store.settings.activeConfig.model, 'gpt-6.1-terra');
    expect(
      store.settings.activeConfig.enabledModels,
      containsAll(['gpt-6.1-terra', 'my-manual-model']),
    );
    expect(store.keys['openai'], isNull);
  });

  testWidgets('官方模型用寫死清單，輸入時不會把既有列濾掉', (tester) async {
    store.keys['openai'] = 'synthetic-key';
    store.settings = const AiConnectionSettings(
      configs: {
        AiProvider.openai: AiConnectionConfig(
          provider: AiProvider.openai,
          model: 'kept-model',
        ),
      },
    );
    await open(tester);
    expect(networkCalls, 0);
    expect(find.text('OpenAI/gpt-6.1-terra'), findsOneWidget);
    expect(find.text('OpenAI/kept-model'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ai-model-remove-openai-gpt-6.1-terra')),
      findsNothing,
    );
    expect(
      tester
          .widget<Switch>(
            find.byKey(const ValueKey('ai-model-switch-openai-gpt-6.1-terra')),
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
    expect(find.text('OpenAI/gpt-6.1-terra'), findsOneWidget);
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
    expect(find.text('OpenAI/gpt-6.1-terra'), findsOneWidget);
    expect(find.text('OpenAI/gpt-6.1-sol'), findsOneWidget);
    expect(find.text('OpenAI/gpt-6-luna'), findsOneWidget);
    expect(find.text('Claude/claude-opus-5-5'), findsOneWidget);
    expect(find.text('Gemini/gemini-3.8-flash'), findsOneWidget);
    expect(find.text('xAI/grok-4.7'), findsNothing);
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
    final Finder claudeHeading = find.descendant(
      of: catalog,
      matching: find.text('Claude'),
    );
    expect(claudeHeading, findsOneWidget);
    final sonnet = find.descendant(
      of: catalog,
      matching: find.text('Claude/claude-sonnet-5-5'),
    );
    expect(sonnet, findsOneWidget);
    expect(
      tester.getTopLeft(sonnet).dy,
      greaterThan(tester.getTopLeft(claudeHeading).dy),
    );
    expect(
      tester
          .getTopLeft(
            find.descendant(
              of: catalog,
              matching: find.text('OpenAI/gpt-6.1-sol'),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.descendant(
                of: catalog,
                matching: find.text('OpenAI/gpt-6-luna'),
              ),
            )
            .dy,
      ),
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
            find.byKey(const ValueKey('ai-model-switch-openai-gpt-6.1-terra')),
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
    final Finder enabledModel = find.text('OpenAI/gpt-6.1-terra');
    final Finder disabledModel = find.text('OpenAI/gpt-6.1-sol');
    expect(
      tester.getTopLeft(enabledModel).dy,
      lessThan(tester.getTopLeft(disabledModel).dy),
    );
    await tester.tap(
      find.byKey(const ValueKey('ai-model-switch-openai-gpt-6.1-terra')),
    );
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
    expect(find.text('OpenAI/gpt-6.1-terra'), findsOneWidget);
    expect(find.text('OpenAI/gpt-6-luna'), findsOneWidget);
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
    expect(
      find.byKey(
        const ValueKey('ai-model-thinking-xai-grok-4.20-non-reasoning'),
      ),
      findsNothing,
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
    expect(store.settings.configFor(AiProvider.openai).thinkingLevels, {
      'gpt-6.1-terra': AiThinkingLevel.low,
    });
    expect(networkCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手動加入的模型可以移除，寫死的列留著', (tester) async {
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
    final Finder remove = find.byKey(
      const ValueKey('ai-model-remove-openai-extra-model'),
    );
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pump();
    expect(find.text('OpenAI/extra-model'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, '關閉'));
    await tester.pumpAndSettle();
    expect(find.text('OpenAI/gpt-6.1-terra'), findsOneWidget);
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
    await open(tester);
    await tester.enterText(
      find.byKey(const ValueKey('ai-api-key-custom')),
      'orphan-key',
    );
    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
    await tester.pumpAndSettle();
    expect(
      find.text('至少填一個服務的 API Key，或填自訂服務網址，並打開一個模型，才選得到。'),
      findsOneWidget,
    );
    expect(find.text('無法保存進度，請確認儲存空間後重試。'), findsNothing);
    expect(find.byType(AiConnectionSettingsDialog), findsOneWidget);
    expect(store.keys.values, isNot(contains('orphan-key')));
  });

  testWidgets('重複加入寫死名稱只會打開，空白不會多一列', (tester) async {
    await open(tester);
    await tester.enterText(
      find.byKey(const ValueKey('ai-model-add-field-openai')),
      '  gpt-6.1-terra  ',
    );
    await tester.pump();
    final Finder addModel = find.byKey(const ValueKey('ai-model-add-openai'));
    await tester.ensureVisible(addModel);
    await tester.tap(addModel);
    await tester.pump();
    expect(find.text('OpenAI/gpt-6.1-terra'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ai-model-remove-openai-gpt-6.1-terra')),
      findsNothing,
    );
    expect(
      tester
          .widget<Switch>(
            find.byKey(const ValueKey('ai-model-switch-openai-gpt-6.1-terra')),
          )
          .value,
      isTrue,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ai-model-openai-gpt-6.1-terra')),
        matching: find.text('預設'),
      ),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const ValueKey('ai-model-add-field-openai')),
      '   ',
    );
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('ai-model-add-openai')))
          .onPressed,
      isNull,
    );
    expect(networkCalls, 0);
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
    expect(find.textContaining('Gemini 免費與付費'), findsOneWidget);
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
    final model = find.byKey(const ValueKey('ai-model-add-field-custom'));
    await tester.ensureVisible(model);
    await tester.showKeyboard(model);
    await tester.tap(model);
    await tester.pumpAndSettle();
    final Finder testConnection = find.byKey(const ValueKey('ai-test-custom'));
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
    final Finder testConnection = find.byKey(const ValueKey('ai-test-openai'));
    await tester.ensureVisible(testConnection);
    await tester.tap(testConnection);
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
    expect(tester.widget<AppActionButton>(testConnection).loading, isFalse);
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
    final Finder testConnection = find.byKey(const ValueKey('ai-test-custom'));
    await tester.ensureVisible(testConnection);
    await tester.tap(testConnection);
    await tester.pumpAndSettle();
    expect(find.text('等候服務回應逾時，請稍後重試或確認模型是否可用。'), findsOneWidget);
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
        provider: AiProvider.custom,
        configs: {AiProvider.custom: connectionConfig},
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
    final Finder testConnection = find.byKey(const ValueKey('ai-test-custom'));
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
      provider: AiProvider.custom,
      configs: {AiProvider.custom: connectionConfig},
    );
    throwOnConnection = true;
    await open(tester);
    final Finder testConnection = find.byKey(const ValueKey('ai-test-custom'));
    await tester.ensureVisible(testConnection);
    await tester.tap(testConnection);
    await tester.pumpAndSettle();
    expect(find.text('這次沒有完成，內容已保留，請再試一次。'), findsOneWidget);
    expect(find.text('服務未回傳完整可用內容，請重試或確認模型設定。'), findsNothing);
  });

  testWidgets('協定選單跟輸入框一樣寬', (tester) async {
    await open(tester);
    final Finder field = find.byKey(const ValueKey('ai-protocol-field'));
    await tester.ensureVisible(field);
    final double fieldWidth = tester.getSize(field).width;
    await tester.tap(field);
    await tester.pumpAndSettle();
    final double itemWidth = tester
        .getSize(find.widgetWithText(MenuItemButton, 'Claude Messages'))
        .width;
    expect(itemWidth, greaterThan(fieldWidth - 24));
  });
}
