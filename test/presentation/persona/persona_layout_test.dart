import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/persona/persona_controller.dart';
import 'package:quill_diary/application/persona/persona_material.dart';
import 'package:quill_diary/application/persona/persona_providers.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_stored_settings.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_privacy.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/presentation/ai/ai_message_view.dart';
import 'package:quill_diary/presentation/people/pages/person_detail_page.dart';
import 'package:quill_diary/presentation/persona/persona_material_dialogs.dart';
import 'package:quill_diary/presentation/persona/persona_page.dart';
import 'package:quill_diary/presentation/persona/persona_summary_section.dart';
import 'package:quill_diary/presentation/persona/persona_trial_page.dart';
import 'package:quill_diary/shared/presentation/private_text_spans.dart';
import 'package:quill_diary/shared/presentation/widgets/private_text.dart';

import '../../helpers/ai/ai_test_helpers.dart';
import '../../helpers/ai/people_chat_repository.dart';
import '../../helpers/persona/persona_fixtures.dart';
import '../../helpers/presentation/persona/persona_test_controller.dart';
import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

class _Preferences extends UserPreferences {
  @override
  Future<AppLanguage> get appLocale async => AppLanguage.zh;
  @override
  Future<PersonalizationPreferences> loadPersonalizationPreferences() async =>
      PersonalizationPreferences.defaults;
}

/// 從列表左側內距拖曳，避開內嵌原文框攔截置中的拖曳手勢。
Future<void> _dragListFromEdge(
  WidgetTester tester,
  Finder list,
  double dy,
) async {
  final rect = tester.getRect(list);
  final gesture = await tester.startGesture(
    Offset(rect.left + 4, rect.center.dy),
  );
  await gesture.moveBy(Offset(0, dy));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Inter', 'NotoSansTC', 'MaterialIcons']) {
      await (FontLoader(family)..addFont(
            rootBundle.load(
              family == 'MaterialIcons'
                  ? 'fonts/MaterialIcons-Regular.otf'
                  : 'assets/fonts/$family-Regular.ttf',
            ),
          ))
          .load();
    }
  });
  final person = personaPerson('測試王小明');
  final peer = personaPerson('阿華');
  final now = DateTime.utc(2026, 11, 6, 8);
  final session = const UnlockedVaultSession(
    vaultId: 'vault',
    trustedDevice: true,
  );
  final config = testChatDiarySession().connectionConfig;
  final entries = [
    for (var i = 0; i < 3; i++)
      DiaryEntry(
        id: generateEntryId(),
        vaultId: 'vault',
        title: ['一起去圖書館', '午後散步', '搜尋加入的其他日記'][i],
        date: const DateOnly('2026-11-04'),
        createdAt: now,
        updatedAt: now,
        markdownBody: i == 0
            ? '今天和小明去圖書館看書，借了一本旅遊書，覺得很充實。'
            : '今天和小明去公園散步，天氣很好，之後去喝咖啡。',
      ),
  ];
  final summaries = [
    for (final e in entries.take(2))
      DiaryEntrySummary(
        id: e.id,
        vaultId: e.vaultId,
        filePath: '',
        title: e.title,
        previewText: '',
        date: e.date,
        createdAt: now,
        updatedAt: now,
        tags: [],
        wordCount: 20,
        charCount: 20,
        attachmentCount: 0,
      ),
  ];
  for (final variant in [(320.0, 2.0, Brightness.dark)]) {
    final (width, scale, brightness) = variant;
    testWidgets('分身各階段在 ${width.toInt()} 寬與 $scale 字級仍可操作', (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final record = personaDraftRecord('vault', person.id);
      record.draft!.diaries.addAll(
        entries.map(
          (e) => PersonaDiarySource(entryId: e.id, bodyHash: '0' * 64),
        ),
      );
      late PersonaTestController controller;
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('qa-canvas'),
          child: widgetTestApp(
            brightness: brightness,
            center: false,
            wrapScaffold: false,
            overrides: [
              effectiveAppSessionProvider.overrideWith(
                (ref) async => AppSessionState(
                  status: AppLockStatus.unlocked,
                  session: session,
                ),
              ),
              personDetailProvider(person.id)
                  .overrideWith((ref) async => person),
              peopleListProvider.overrideWith(
                (ref) => AsyncData([person, peer]),
              ),
              personRelatedEntriesProvider(person.id)
                  .overrideWith((ref) async => summaries),
              userPreferencesProvider.overrideWithValue(_Preferences()),
              aiSettingsStoreProvider.overrideWithValue(
                OverviewAiSettingsStore()
                  ..chatDiaryPrompts = const ChatDiaryPromptSettings(
                    guidanceOverride: '分身測試引導',
                  ),
              ),
              personaControllerProvider(person.id).overrideWith((ref) {
                controller = PersonaTestController(ref, person.id, record);
                controller.entries.addEntries(
                  entries.map((e) => MapEntry(e.id, e)),
                );
                ref.onDispose(controller.dispose);
                return controller;
              }),
            ],
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: PersonaPage(personId: person.id),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.byTooltip(testL10n.personaCancelUpdate), findsOneWidget);
      expect(find.byTooltip(testL10n.personaDelete), findsNothing);
      await tester.scrollUntilVisible(
        find.byType(FilterChip),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.getTopLeft(find.text(testL10n.personaChooseFile)).dy,
        lessThan(tester.getTopLeft(find.byType(TextField)).dy),
      );
      expect(find.byTooltip(testL10n.personaChatExportHelp), findsOneWidget);
      await tester.tap(find.byType(FilterChip));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(entries.last.title!),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(entries.last.title!), findsOneWidget);
      controller.draft!.step = PersonaStep.confirmation;
      controller.preview = PersonaGenerationContext(
        personaId: record.personaId,
        updateTarget: PersonaUpdateTarget.both,
        modelTarget: PersonaUpdateTarget.memory,
        fallbackCards: personaCandidates(),
        baseUpdatedAt: controller.draft!.baseUpdatedAt,
        session: session,
        connection: config,
        instructions: '只生成材料支持的記憶與語氣，不新增經歷。',
        extractionInstructions: '保留原文歸屬與人物代號。',
        registry: PersonaTokenRegistry([person], hideNames: true),
        blocks: [
          for (var i = 0; i < entries.length; i++)
            PersonaMaterial.diary(
              label: '日記 ${i + 1}',
              date: entries[i].date.value,
              text:
                  entries[i].markdownBody.replaceAll('小明', '⟦P01⟧') +
                  personaHiddenText,
            ),
        ],
        baseline: const {},
        subject: '⟦P01⟧',
        selectionSignature: 'fixture',
      );
      controller.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.textContaining('"source"'), findsNothing);
      expect(find.text(config.effectiveBaseUrl), findsNothing);
      // 內嵌原文框會攔截置中拖曳，直接捲到底部讓日記段落建立。
      final confirmationScroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('persona-confirmation')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      confirmationScroll.position.jumpTo(
        confirmationScroll.position.maxScrollExtent,
      );
      await tester.pumpAndSettle();
      expect(find.text('日記 1'), findsOneWidget);
      final maskedMaterial = tester
          .widgetList<PrivateText>(find.byType(PrivateText))
          .firstWhere(
            (text) =>
                text.text.contains('⟦P01⟧') &&
                text.text.contains(personaHiddenText),
          );
      expect(
        maskedMaterial.ranges.map((range) => (range.start, range.end)).toList(),
        [
          ...privacyTokenRanges(maskedMaterial.text)
              .map((range) => (range.start, range.end)),
          (
            maskedMaterial.text.indexOf(personaHiddenText),
            maskedMaterial.text.length,
          ),
        ],
      );
      confirmationScroll.position.jumpTo(0);
      await tester.pumpAndSettle();
      final modelTag = find.byKey(const ValueKey('ai-model-field'));
      await tester.tap(modelTag);
      await tester.pumpAndSettle();
      final modelMenu = find.byKey(const ValueKey('ai-model-menu'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(modelMenu, findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, -2500));
      await tester.pumpAndSettle();
      expect(find.text(testL10n.personaPrivacyHint), findsNothing);
      controller.draft!.step = PersonaStep.review;
      controller.draft!.candidate = personaCandidates(
        memory: '2026-11-04｜與日記作者去圖書館，借了一本旅遊書。\n時間不明｜一起去公園散步，之後喝咖啡。',
        tone: '使用自然、中性的日常語氣，不刻意加入特定口頭禪。',
      );
      controller.draft!.candidate![PersonaCardKind.memory] = PersonaCandidate(
        text:
            '2026-11-04｜與日記作者去圖書館借旅遊書。\n時間不明｜與⟦P01⟧散步後喝咖啡。\n${List.filled(20, '時間不明｜一起去公園散步。').join('\n')}',
        tokens: {'⟦P01⟧': peer.id},
      );
      controller.notifyListeners();
      await tester.pumpAndSettle();
      final reviewList = find.byKey(const ValueKey('persona-review'));
      for (
        var i = 0;
        i < 40 && find.text(testL10n.personaMemory).evaluate().isEmpty;
        i++
      ) {
        await _dragListFromEdge(tester, reviewList, -150);
      }
      expect(find.text(testL10n.personaMemory), findsOneWidget);
      final memoryEditor = tester.widget<TextFormField>(
        find.byType(TextFormField).last,
      );
      expect(memoryEditor.controller!.text, contains('阿華'));
      expect(memoryEditor.controller!.text, isNot(contains('⟦P01⟧')));
      memoryEditor.controller!.selection = const TextSelection.collapsed(
        offset: 0,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.showKeyboard(find.byType(TextFormField).last);
      await tester.pumpAndSettle();
      tester.view.resetViewInsets();
      controller.record = PersonaRecord(
        vaultId: 'vault',
        personId: person.id,
        personaId: record.personaId,
        cards: {
          for (final kind in PersonaCardKind.values)
            kind: PersonaCard(
              text: controller.draft!.candidate![kind]!.text,
              tokens: controller.draft!.candidate![kind]!.tokens,
              updatedAt: now,
              selectedDiaryIds: entries.map((e) => e.id).toList(),
            ),
        },
      );
      controller.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text(testL10n.personaBaseLabel), findsOneWidget);
      expect(find.byTooltip(testL10n.personaCancelUpdate), findsNothing);
      expect(find.byTooltip(testL10n.personaDelete), findsOneWidget);
      await tester.tap(find.text(testL10n.personaBaseLabel));
      await tester.pumpAndSettle();
      expect(find.textContaining('分身測試引導'), findsOneWidget);
      final saved = controller.record!;
      controller.record = saved.withDraft(
        PersonaDraft(
          target: PersonaUpdateTarget.both,
          baseUpdatedAt: {
            for (final card in saved.cards!.entries)
              card.key: card.value.updatedAt,
          },
        ),
      );
      controller.notifyListeners();
      await tester.pumpAndSettle();
      final materialsList = find.byType(CustomScrollView);
      for (
        var i = 0;
        i < 40 &&
            tester
                    .getRect(find.text(testL10n.personaIncludeCurrentMemory))
                    .bottom >
                tester.getRect(materialsList).bottom;
        i++
      ) {
        await _dragListFromEdge(tester, materialsList, -200);
      }
      await tester.tap(find.text(testL10n.personaIncludeCurrentMemory));
      await tester.pumpAndSettle();
      final mask = tester
          .widget<TextField>(
            find.descendant(
              of: find.byType(PersonaMaskDialog),
              matching: find.byType(TextField),
            ),
          )
          .controller!;
      final visibleName = mask.text.indexOf('阿華');
      expect(visibleName, isNonNegative);
      mask.selection = TextSelection(
        baseOffset: visibleName,
        extentOffset: visibleName + 1,
      );
      await tester.pump();
      await tester.tap(find.byTooltip(testL10n.aiHideSelection));
      await tester.pump();
      final rawName = saved.cards![PersonaCardKind.memory]!.text.indexOf(
        '⟦P01⟧',
      );
      final hidden =
          controller.draft!.cardHiddenRanges[PersonaCardKind.memory]!.single;
      expect([hidden.start, hidden.end], [rawName, rawName + '⟦P01⟧'.length]);
      await tester.tap(find.text(testL10n.personaChecked));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('試聊未填 API Key 仍可輸入，補齊設定後才啟用送出', (tester) async {
    final connection = const AiConnectionConfig(
      provider: AiProvider.openai,
      model: 'test-model',
    ).captureRequestSnapshot();
    final settings = OverviewAiSettingsStore();
    var calls = 0;
    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        wrapScaffold: false,
        overrides: [
          userPreferencesProvider.overrideWithValue(_Preferences()),
          effectiveAppSessionProvider.overrideWith(
            (_) async => AppSessionState(
              status: AppLockStatus.unlocked,
              session: session,
            ),
          ),
          aiSettingsStoreProvider.overrideWithValue(settings),
          aiClientFactoryProvider.overrideWithValue((config, _) {
            calls++;
            return FakeAiClient(config);
          }),
        ],
        child: PersonaTrialPage(
          personId: person.id,
          personaId: generatePersonaId(),
          cards: personaCandidates(),
          connection: connection,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '先準備試聊文字');
    await tester.pump();
    final send = find.widgetWithIcon(IconButton, Icons.arrow_upward_rounded);
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    settings.keys['openai'] = 'synthetic-key';
    ProviderScope.containerOf(tester.element(find.byType(PersonaTrialPage)))
        .invalidate(aiConnectionReadyProvider(connection));
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(send).onPressed, isNotNull);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '先準備試聊文字',
    );
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('試聊沿用聊天版面、聊天氣泡與獨立的輸入停止操作', (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = FakeAiClient(config)..output = '那本旅遊書有沒有什麼讓你很想去的地方？';
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('qa-canvas'),
        child: widgetTestApp(
          center: false,
          wrapScaffold: false,
          overrides: [
            effectiveAppSessionProvider.overrideWith(
              (ref) async => AppSessionState(
                status: AppLockStatus.unlocked,
                session: session,
              ),
            ),
            userPreferencesProvider.overrideWithValue(_Preferences()),
            aiSettingsStoreProvider.overrideWithValue(
              OverviewAiSettingsStore(),
            ),
            vaultRepositoryProvider.overrideWithValue(
              PeopleChatRepository([person]),
            ),
            aiClientFactoryProvider.overrideWithValue((_, _) => client),
          ],
          child: PersonaTrialPage(
            personId: person.id,
            personaId: generatePersonaId(),
            cards: personaCandidates(),
            connection: config,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gate = Completer<void>();
    client.response = () async* {
      yield '先看到這句';
      await gate.future;
      yield '不該出現';
    };
    await tester.enterText(find.byType(TextField), '今天借了一本旅遊書。');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('persona-trial-composer')),
      findsOneWidget,
    );
    final send = find.byIcon(Icons.arrow_upward_rounded);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(of: send, matching: find.byType(IconButton)),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(send);
    await tester.pump();
    await tester.pump();
    expect(find.byType(AiMessageView), findsWidgets);
    expect(find.textContaining('今天借了一本旅遊書'), findsOneWidget);
    expect(find.textContaining('先看到這句'), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.stop_rounded));
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('不該出現'), findsNothing);
    expect(find.textContaining('先看到這句'), findsNothing);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    expect(find.byType(AiMessageView), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.textContaining('今天借了一本旅遊書'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.scheduleForcedFrame();
    await tester.pump();
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.textContaining('今天借了一本旅遊書'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.textContaining('今天借了一本旅遊書'), findsOneWidget);
  });

  testWidgets('人物分身摘要只保留狀態、上次更新與管理入口', (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final record = PersonaRecord(
      vaultId: 'vault',
      personId: person.id,
      personaId: generatePersonaId(),
      cards: {
        for (final kind in PersonaCardKind.values)
          kind: PersonaCard(
            text: '已儲存內容',
            updatedAt: now,
            selectedDiaryIds: entries.map((e) => e.id).toList(),
          ),
      },
    );
    late PersonaTestController controller;
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('qa-canvas'),
        child: widgetTestApp(
          center: false,
          wrapScaffold: false,
          overrides: [
            personDetailProvider(person.id).overrideWith((ref) async => person),
            personRelatedEntriesProvider(person.id)
                .overrideWith((ref) async => summaries),
            peopleMentionStatsMapProvider.overrideWith((ref) async => {}),
            personaRecordProvider(person.id)
                .overrideWith((ref) async => record),
            personaControllerProvider(person.id).overrideWith((ref) {
              controller = PersonaTestController(ref, person.id, record);
              ref.onDispose(controller.dispose);
              return controller;
            }),
          ],
          child: PersonDetailPage(personId: person.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(testL10n.personaManage));
    await tester.pumpAndSettle();
    final summary = find.byType(PersonaSummarySection);
    expect(
      find.descendant(of: summary, matching: find.byType(OutlinedButton)),
      findsNothing,
    );
    expect(
      find.descendant(of: summary, matching: find.byType(FilledButton)),
      findsNothing,
    );
    expect(find.textContaining('上次更新：'), findsOneWidget);
    controller.record = record.withDraft(
      PersonaDraft(
        target: PersonaUpdateTarget.both,
        baseUpdatedAt: {
          for (final card in record.cards!.entries)
            card.key: card.value.updatedAt,
        },
      ),
    );
    controller.busy = true;
    controller.notifyListeners();
    await tester.pump();
    expect(find.textContaining('上次更新：'), findsNothing);
    expect(
      find.descendant(of: summary, matching: find.byType(TextButton)),
      findsOneWidget,
    );
    expect(find.text(testL10n.personaManage), findsOneWidget);
    expect(find.text(testL10n.aiStopGeneration), findsNothing);
    controller.busy = false;
    controller.notifyListeners();
    await tester.pumpAndSettle();
  });
}
