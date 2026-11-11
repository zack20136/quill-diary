import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/persona/persona_controller.dart';
import 'package:quill_diary/application/persona/persona_material.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/relationship_type.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/domain/persona/persona_privacy.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/persona/persona_material_dialogs.dart';
import 'package:quill_diary/presentation/persona/persona_page.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';
import 'package:quill_diary/shared/presentation/widgets/private_text.dart';

import '../../helpers/ai/ai_test_helpers.dart';
import '../../helpers/persona/persona_fixtures.dart';
import '../../helpers/preferences/in_memory_user_preferences.dart';
import '../../helpers/presentation/persona/persona_test_controller.dart';
import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  for (final (hasRequest, includeTone) in [
    (false, true),
    (true, true),
    (true, false),
  ]) {
    testWidgets(
      '${hasRequest ? '記憶外送' : '全本機保留'}時確認頁顯示勾選舊卡，風格${includeTone ? '納入' : '排除'}',
      (tester) async {
        tester.view.physicalSize = const Size(520, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final person = personaPerson('小明');
        final peer = personaPerson('小華');
        const memory = '既有記憶與秘密資料';
        final cards = {
          PersonaCardKind.memory: PersonaCard(
            text: memory,
            updatedAt: DateTime.utc(2026),
            selectedDiaryIds: [],
          ),
          PersonaCardKind.tone: PersonaCard(
            text: '會用⟦P01⟧的稱呼',
            tokens: {'⟦P01⟧': peer.id},
            updatedAt: DateTime.utc(2026),
            selectedDiaryIds: [],
          ),
        };
        final record = PersonaRecord(
          vaultId: 'vault',
          personId: person.id,
          personaId: generatePersonaId(),
          cards: cards,
          draft: PersonaDraft(
            target: PersonaUpdateTarget.both,
            step: PersonaStep.confirmation,
            baseUpdatedAt: {
              for (final card in cards.entries) card.key: card.value.updatedAt,
            },
            includeCurrent: {
              PersonaCardKind.memory: true,
              PersonaCardKind.tone: includeTone,
            },
            cardHiddenRanges: {
              PersonaCardKind.memory: [const PrivateTextRange(5, 9)],
            },
          ),
        );
        const session = UnlockedVaultSession(
          vaultId: 'vault',
          trustedDevice: true,
        );
        final preview = PersonaGenerationContext(
          personaId: record.personaId,
          updateTarget: PersonaUpdateTarget.both,
          modelTarget: hasRequest ? PersonaUpdateTarget.memory : null,
          fallbackCards: {
            for (final card in cards.entries)
              card.key: PersonaCandidate(
                text: card.key == PersonaCardKind.tone && !includeTone
                    ? testL10n.personaNeutralTone
                    : card.value.text,
                tokens: card.value.tokens,
              ),
          },
          baseUpdatedAt: record.draft!.baseUpdatedAt,
          session: session,
          connection: hasRequest
              ? testChatDiarySession().connectionConfig
              : null,
          instructions: hasRequest ? '本次只整理記憶' : '',
          extractionInstructions: '',
          registry: PersonaTokenRegistry([person, peer], hideNames: true),
          blocks: const [],
          baseline: hasRequest ? {'memory': '既有記憶與$personaHiddenText'} : {},
          subject: '⟦P02⟧',
          selectionSignature: 'fixture',
        );
        final baseline = jsonEncode(preview.baseline);
        await tester.pumpWidget(
          widgetTestApp(
            center: false,
            wrapScaffold: false,
            overrides: [
              effectiveAppSessionProvider.overrideWith(
                (_) async => const AppSessionState(
                  status: AppLockStatus.unlocked,
                  session: session,
                ),
              ),
              peopleListProvider.overrideWith((_) => AsyncData([person, peer])),
              personDetailProvider(person.id).overrideWith((_) async => person),
              personaControllerProvider(person.id).overrideWith((ref) {
                final controller = PersonaTestController(ref, person.id, record)
                  ..preview = preview;
                ref.onDispose(controller.dispose);
                return controller;
              }),
            ],
            child: PersonaPage(personId: person.id),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            hasRequest
                ? testL10n.personaIncludedContentTitle(testL10n.personaMemory)
                : testL10n.personaRetainedContentTitle(testL10n.personaMemory),
          ),
          findsOneWidget,
        );
        expect(
          find.text(testL10n.personaRetainedContentTitle(testL10n.personaTone)),
          includeTone ? findsOneWidget : findsNothing,
        );
        final visible = tester
            .widgetList<PrivateText>(find.byType(PrivateText))
            .map((widget) => widget.text)
            .toList();
        expect(
          visible,
          contains(hasRequest ? '既有記憶與$personaHiddenText' : memory),
        );
        expect(visible.contains('會用小華的稱呼'), includeTone);
        if (hasRequest) {
          expect(visible.any((text) => text.contains('秘密資料')), isFalse);
        } else {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          await tester.pumpAndSettle();
          expect(find.byType(PrivateText), findsNothing);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
          expect(find.text(memory), findsOneWidget);
        }
        expect(jsonEncode(preview.baseline), baseline);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('帶入舊記憶預設未勾，勾選可作為本次材料並保存選擇', (tester) async {
    final person = personaPerson('小明');
    final cards = {
      for (final kind in PersonaCardKind.values)
        kind: PersonaCard(
          text: '本機舊內容',
          updatedAt: DateTime.utc(2026),
          selectedDiaryIds: [],
        ),
    };
    final record = PersonaRecord(
      vaultId: 'vault',
      personId: person.id,
      personaId: generatePersonaId(),
      cards: cards,
      draft: PersonaDraft(
        target: PersonaUpdateTarget.memory,
        baseUpdatedAt: {
          PersonaCardKind.memory: cards[PersonaCardKind.memory]!.updatedAt,
        },
      ),
    );
    late PersonaTestController controller;
    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        wrapScaffold: false,
        overrides: [
          effectiveAppSessionProvider.overrideWith(
            (ref) async => const AppSessionState(
              status: AppLockStatus.unlocked,
              session: UnlockedVaultSession(
                vaultId: 'vault',
                trustedDevice: true,
              ),
            ),
          ),
          personDetailProvider(person.id).overrideWith((ref) async => person),
          personRelatedEntriesProvider(person.id)
              .overrideWith((ref) async => []),
          personaControllerProvider(person.id).overrideWith((ref) {
            controller = PersonaTestController(ref, person.id, record);
            ref.onDispose(controller.dispose);
            return controller;
          }),
        ],
        child: PersonaPage(personId: person.id),
      ),
    );
    await tester.pumpAndSettle();
    final checkbox = find.byKey(
      const ValueKey('persona-include-current-memory'),
    );
    await tester.ensureVisible(checkbox);
    expect(tester.widget<Checkbox>(checkbox).value, isFalse);
    expect(controller.hasMaterials, isFalse);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
    expect(controller.hasMaterials, isTrue);
    expect(controller.draft!.toJson()['include_current'], {'memory': true});
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(controller.hasMaterials, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('分身初始化遇到不可讀 AI 設定時可開啟設定重建，再回到原草稿', (tester) async {
    final person = personaPerson('測試人物');
    final settings = OverviewAiSettingsStore()..failReads = true;
    await settings.saveApiKey(settings.settings.activeConfig, '測試金鑰');
    final record = personaDraftRecord('vault', person.id);
    const session = UnlockedVaultSession(vaultId: 'vault', trustedDevice: true);
    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        wrapScaffold: false,
        overrides: [
          userPreferencesProvider.overrideWithValue(InMemoryUserPreferences()),
          aiSettingsStoreProvider.overrideWithValue(settings),
          effectiveAppSessionProvider.overrideWith(
            (_) async => const AppSessionState(
              status: AppLockStatus.unlocked,
              session: session,
            ),
          ),
          peopleCatalogProvider.overrideWith(
            (_) async => PeopleCatalog.empty(),
          ),
          personDetailProvider(person.id).overrideWith((_) async => person),
          personRelatedEntriesProvider(person.id).overrideWith((_) async => []),
          personaControllerProvider(person.id).overrideWith((ref) {
            final controller = PersonaTestController(ref, person.id, record);
            ref.onDispose(controller.dispose);
            return controller;
          }),
        ],
        child: PersonaPage(personId: person.id),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(testL10n.aiErrorSettings), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PersonaPage)),
    );
    container.read(appSessionProvider.notifier).activateSession(session);
    await tester.tap(find.text(testL10n.aiOpenSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.text(testL10n.aiSettingsReset));
    await tester.pumpAndSettle();
    await tester.tap(find.text(testL10n.aiSettingsReset).last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, testL10n.aiSaveSettings),
    );
    await tester.pumpAndSettle();
    expect(settings.failReads, isFalse);
    expect(find.text(testL10n.aiErrorSettings), findsNothing);
    expect(
      container.read(personaControllerProvider(person.id)).record,
      same(record),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (locale, width, scale) in [
    (appZhLocale, 520.0, 1.0),
    (appEnLocale, 320.0, 2.0),
  ]) {
    testWidgets('${locale.languageCode} 確認頁提示詞可收合、姓名保留代號邊界，返回不清材料', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, scale == 1 ? 1200 : 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final l10n = lookupAppLocalizations(locale);
      final person = personaPerson('小明🙂');
      final personResult = Completer<Person?>();
      final settings = OverviewAiSettingsStore();
      final record = personaDraftRecord('vault', person.id);
      final source = PersonaChatSource(
        importId: 'pim_fixture',
        hidden: {
          'message': [const PrivateTextRange(0, 2)],
        },
      );
      record.draft!.chats.add(source);
      record.draft!.step = PersonaStep.confirmation;
      const session = UnlockedVaultSession(
        vaultId: 'vault',
        trustedDevice: true,
      );
      final preview = PersonaGenerationContext(
        personaId: record.personaId,
        updateTarget: PersonaUpdateTarget.both,
        modelTarget: PersonaUpdateTarget.both,
        fallbackCards: personaCandidates(),
        baseUpdatedAt: record.draft!.baseUpdatedAt,
        session: session,
        connection: const AiConnectionConfig(
          provider: AiProvider.openai,
          model: 'test-model',
        ).captureRequestSnapshot(),
        instructions: '測試指示',
        extractionInstructions: '測試分批指示',
        registry: PersonaTokenRegistry([person], hideNames: true),
        blocks: const [
          PersonaMaterial.diary(
            label: '日記範例',
            date: '2026-11-07',
            text: '日記中的合成內容',
          ),
          PersonaMaterial.chat(
            label: '匯入的聊天 1',
            date: '2026-11-09T08:00:00',
            text: '隔天聊天',
            speakerRole: PersonaSpeakerRole.user,
            speaker: 'user',
            styleText: '',
          ),
          PersonaMaterial.chat(
            label: '匯入的聊天 2',
            date: '2026-11-08T10:00:00',
            text: '晚點$personaHiddenText',
            speakerRole: PersonaSpeakerRole.personaSubject,
            speaker: '⟦P07⟧',
            styleText: '晚點',
          ),
          PersonaMaterial.chat(
            label: '匯入的聊天 1',
            date: '2026-11-08T10:05:00',
            text: '和⟦P07⟧碰面',
            speakerRole: PersonaSpeakerRole.other,
            speaker: '⟦P08⟧',
            styleText: '',
          ),
          PersonaMaterial.chat(
            label: '匯入的聊天 1',
            date: '2026-11-08T09:12:00',
            text: '早安',
            speakerRole: PersonaSpeakerRole.user,
            speaker: 'user',
            styleText: '',
          ),
        ],
        baseline: const {},
        subject: '⟦P07⟧',
        selectionSignature: 'fixture',
      );
      final request = jsonEncode(preview.requestMaterials);
      await tester.pumpWidget(
        widgetTestApp(
          locale: locale,
          center: false,
          wrapScaffold: false,
          overrides: [
            userPreferencesProvider.overrideWithValue(
              InMemoryUserPreferences(),
            ),
            aiSettingsStoreProvider.overrideWithValue(settings),
            effectiveAppSessionProvider.overrideWith(
              (_) async => const AppSessionState(
                status: AppLockStatus.unlocked,
                session: session,
              ),
            ),
            personDetailProvider(person.id)
                .overrideWith((_) => personResult.future),
            personRelatedEntriesProvider(person.id)
                .overrideWith((_) async => []),
            personaControllerProvider(person.id).overrideWith((ref) {
              final controller = PersonaTestController(ref, person.id, record)
                ..preview = preview;
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
      );
      await tester.pumpAndSettle();
      final prompt = find.byKey(const ValueKey('persona-system-prompt'));
      final promptText = find.descendant(
        of: prompt,
        matching: find.byType(PrivateText),
      );
      expect(promptText, findsNothing);
      await tester.tap(find.text(l10n.personaSystemPrompt));
      await tester.pumpAndSettle();
      expect(tester.widget<PrivateText>(promptText).text, preview.instructions);
      await tester.tap(find.text(l10n.personaSystemPrompt));
      await tester.pumpAndSettle();
      expect(promptText, findsNothing);
      expect(find.text(l10n.personaSpeakerNamePreviewHint), findsNothing);
      expect(
        find.textContaining('${l10n.personaRoleFriend} · ⟦P07⟧'),
        findsOneWidget,
      );
      personResult.complete(person);
      await tester.pumpAndSettle();
      expect(find.text(l10n.personaSpeakerNamePreviewHint), findsOneWidget);
      final metadata = tester.widgetList<PrivateText>(find.byType(PrivateText));
      final named = metadata.singleWhere(
        (widget) =>
            widget.text.contains('${l10n.personaRoleFriend} · ${person.name}'),
      );
      final nameRange = named.ranges.single;
      expect(named.text.substring(nameRange.start, nameRange.end), person.name);
      final other = metadata.singleWhere(
        (widget) => widget.text.contains('${l10n.personaRoleOther} · ⟦P08⟧'),
      );
      expect(
        other.text.substring(
          other.ranges.single.start,
          other.ranges.single.end,
        ),
        '⟦P08⟧',
      );
      expect(
        find.textContaining('${l10n.personaRoleUser} · user'),
        findsNothing,
      );
      expect(
        find.textContaining('${l10n.personaRoleUser} · 09:12'),
        findsOneWidget,
      );
      expect(find.text('和⟦P07⟧碰面'), findsOneWidget);
      expect(find.text('2026-11-08'), findsOneWidget);
      final day = find.ancestor(
        of: find.text('2026-11-08'),
        matching: find.byType(AppCard),
      );
      expect(
        find.descendant(of: day, matching: find.text('早安')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: day, matching: find.text('晚點$personaHiddenText')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text('早安')).dy,
        lessThan(tester.getTopLeft(find.text('晚點$personaHiddenText')).dy),
      );
      expect(find.textContaining('09:12'), findsOneWidget);
      final hidden = tester
          .widgetList<PrivateText>(find.byType(PrivateText))
          .singleWhere((widget) => widget.text == '晚點$personaHiddenText');
      expect(hidden.ranges, isNotEmpty);
      await tester.scrollUntilVisible(
        find.text('2026-11-09'),
        150,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('persona-confirmation')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('2026-11-09'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('日記範例'),
        150,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('persona-confirmation')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        tester.getTopLeft(find.text('2026-11-09')).dy,
        lessThan(tester.getTopLeft(find.text('日記範例')).dy),
      );
      expect(jsonEncode(preview.requestMaterials), request);
      expect(preview.subject, '⟦P07⟧');
      final back = find.widgetWithText(
        OutlinedButton,
        l10n.personaBackMaterials,
      );
      final advance = find.byKey(const ValueKey('persona-primary'));
      expect(tester.widget<FilledButton>(advance).onPressed, isNull);
      settings.keys['openai'] = 'synthetic-key';
      ProviderScope.containerOf(tester.element(find.byType(PersonaPage)))
          .invalidate(aiConnectionReadyProvider(preview.connection!));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(advance).onPressed, isNotNull);
      expect(tester.getRect(back).left, closeTo(16, 0.1));
      expect(tester.getRect(advance).right, closeTo(width - 16, 0.1));
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(record.draft!.step, PersonaStep.materials);
      expect(
        find.descendant(of: advance, matching: find.text(l10n.personaNext)),
        findsOneWidget,
      );
      expect(record.draft!.chats.single, same(source));
      expect(source.hidden['message']!.single.start, 0);
      expect(source.hidden['message']!.single.end, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('套用聊天編輯會刪除指定與清空的訊息，保留其他日期，取消不套用變更', (tester) async {
    final person = personaPerson('小明');
    final record = personaDraftRecord('vault', person.id);
    final chat = parsePersonaLineChat(
      '2026/11/08\n09:12\t我\t早安，想去旅行\n09:13\t我\t多餘的訊息\n09:14\t小明\t> 引用原文\n自己的話\n2026/11/09\n09:00\t小明\t隔天的訊息',
      vaultId: record.vaultId,
      personId: person.id,
      personaId: record.personaId,
    );
    chat.speakers[0].role = PersonaSpeakerRole.user;
    chat.speakers[1].role = PersonaSpeakerRole.personaSubject;
    final source = PersonaChatSource(
      importId: chat.importId,
      excluded: {chat.messages.first.id},
      hidden: {
        chat.messages.first.id: [const PrivateTextRange(0, 2)],
        chat.messages[1].id: [const PrivateTextRange(0, 2)],
      },
    );
    record.draft!.chats.add(source);
    late PersonaTestController controller;
    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        wrapScaffold: false,
        overrides: [
          effectiveAppSessionProvider.overrideWith(
            (ref) async => const AppSessionState(
              status: AppLockStatus.unlocked,
              session: UnlockedVaultSession(
                vaultId: 'vault',
                trustedDevice: true,
              ),
            ),
          ),
          personDetailProvider(person.id).overrideWith((ref) async => person),
          personRelatedEntriesProvider(person.id)
              .overrideWith((ref) async => []),
          personaControllerProvider(person.id).overrideWith((ref) {
            controller = PersonaTestController(ref, person.id, record);
            controller.imports[chat.importId] = chat;
            ref.onDispose(controller.dispose);
            return controller;
          }),
        ],
        child: PersonaPage(personId: person.id),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('納入 3 則訊息'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(find.text('納入 3 則訊息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編輯').first);
    await tester.pumpAndSettle();
    expect(find.text(testL10n.personaChecked), findsNothing);
    await tester.tap(find.byTooltip(testL10n.commonActionDelete).first);
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(PersonaChatDateEditorDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.first, ' \n ');
    await tester.enterText(fields.last, '> 原文\n自己的話');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text(testL10n.commonActionApply));
    await tester.pumpAndSettle();
    final saved = controller.imports[chat.importId]!;
    expect(saved.messages.map((message) => message.id), ['m3', 'm4']);
    expect(saved.messages.first.text, '> 原文\n自己的話');
    expect(saved.messages.first.quoteRanges.single.end, 4);
    expect(saved.messages.last.text, '隔天的訊息');
    expect(source.hidden, isEmpty);
    expect(source.excluded, isEmpty);
    expect(find.text('納入 2 則訊息'), findsWidgets);
    await tester.tap(find.text('編輯').first);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(fields).controller!.text, '> 原文\n自己的話');
    await tester.enterText(fields, '取消的內容');
    await tester.tap(find.byTooltip(testL10n.commonActionDelete));
    await tester.pumpAndSettle();
    expect(fields, findsNothing);
    expect(find.text(testL10n.personaNoChatMessages), findsOneWidget);
    await tester.tap(find.text(testL10n.commonActionCancel));
    await tester.pumpAndSettle();
    expect(controller.imports[chat.importId], same(saved));
    expect(
      controller.imports[chat.importId]!.messages.first.text,
      '> 原文\n自己的話',
    );
    await tester.tap(find.text('編輯').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(testL10n.commonActionDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(testL10n.commonActionApply));
    await tester.pumpAndSettle();
    expect(controller.imports[chat.importId]!.messages.single.text, '隔天的訊息');
    expect(find.text('2026-11-08'), findsNothing);
    await tester.tap(find.text('編輯'));
    await tester.pumpAndSettle();
    await tester.enterText(fields, '');
    await tester.tap(find.text(testL10n.commonActionApply));
    await tester.pumpAndSettle();
    expect(controller.imports[chat.importId]!.messages, isEmpty);
    expect(controller.hasMaterials, isFalse);
    expect(find.text(testL10n.personaNoChatMessages), findsOneWidget);
    expect(find.text('編輯'), findsNothing);
    await tester.tap(find.text(testL10n.personaFromDate));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('只審閱這次的目標，還原修改前文字且窄螢幕大字可操作', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final person = personaPerson('小明');
    final cards = {
      for (final kind in PersonaCardKind.values)
        kind: PersonaCard(
          text: kind == PersonaCardKind.memory ? '目前記憶' : '目前語氣',
          updatedAt: DateTime.utc(2026),
          selectedDiaryIds: [],
        ),
    };
    final record = PersonaRecord(
      vaultId: generateVaultId(),
      personId: person.id,
      personaId: generatePersonaId(),
      cards: cards,
      draft: PersonaDraft(
        target: PersonaUpdateTarget.memory,
        step: PersonaStep.review,
        baseUpdatedAt: {
          PersonaCardKind.memory: cards[PersonaCardKind.memory]!.updatedAt,
        },
        candidate: {PersonaCardKind.memory: PersonaCandidate(text: '候選記憶')},
      ),
    );
    late PersonaTestController controller;
    await tester.pumpWidget(
      widgetTestApp(
        center: false,
        wrapScaffold: false,
        overrides: [
          effectiveAppSessionProvider.overrideWith(
            (ref) async => const AppSessionState(
              status: AppLockStatus.unlocked,
              session: UnlockedVaultSession(
                vaultId: 'vault',
                trustedDevice: true,
              ),
            ),
          ),
          personDetailProvider(person.id).overrideWith((ref) async => person),
          personRelatedEntriesProvider(person.id)
              .overrideWith((ref) async => []),
          personaControllerProvider(person.id).overrideWith((ref) {
            controller = PersonaTestController(ref, person.id, record);
            ref.onDispose(controller.dispose);
            return controller;
          }),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(1.6),
          ),
          child: PersonaPage(personId: person.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '😀' * 4001);
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('persona-primary')))
          .onPressed,
      isNull,
    );
    expect(find.text(testL10n.personaInvalidCard), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '手動修改');
    await tester.pump();
    expect(controller.draft!.candidate![PersonaCardKind.memory]!.text, '手動修改');
    expect(controller.record!.cards![PersonaCardKind.tone]!.text, '目前語氣');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final compare = find.text(testL10n.personaCompareWithCurrent);
    await tester.ensureVisible(compare);
    await tester.drag(
      find.byKey(const ValueKey('persona-review')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(compare);
    await tester.pumpAndSettle();
    expect(find.text('目前記憶'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.text('目前記憶'), findsNothing);
    expect(find.text(testL10n.personaRetainCurrent), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.ensureVisible(compare);
    await tester.drag(
      find.byKey(const ValueKey('persona-review')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(compare);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(testL10n.personaRetainCurrent));
    await tester.tap(find.text(testL10n.personaRetainCurrent));
    await tester.pumpAndSettle();
    expect(controller.draft!.candidate![PersonaCardKind.memory]!.text, '目前記憶');
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      '目前記憶',
    );
    expect(find.byKey(const ValueKey('persona-primary')), findsOneWidget);
    expect(tester.takeException(), isNull);
    controller.record = record.withDraft(
      PersonaDraft(
        target: PersonaUpdateTarget.memory,
        baseUpdatedAt: {
          PersonaCardKind.memory: cards[PersonaCardKind.memory]!.updatedAt,
        },
      ),
    );
    controller.notifyListeners();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('persona-primary')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
