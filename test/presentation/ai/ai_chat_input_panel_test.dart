import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/relationship_type.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/presentation/ai/ai_chat_input_panel.dart';
import 'package:quill_diary/presentation/people/widgets/person_composer_dialog.dart';
import 'package:quill_diary/presentation/people/widgets/person_suggestion_panel.dart';
import 'package:quill_diary/shared/presentation/private_text_controller.dart';

import '../../helpers/diary_organization/organization_test_scope.dart';
import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

const _field = ValueKey('chat-diary-composer');

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

Future<({PrivateTextController composer, FocusNode focus})> _pumpInput(
  WidgetTester tester,
  ProviderContainer container, {
  ValueListenable<bool>? busy,
  Brightness brightness = Brightness.light,
}) async {
  final composer = PrivateTextController();
  final focus = FocusNode();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    composer.dispose();
    focus.dispose();
  });
  Widget panel(bool isBusy) => AiChatInputPanel(
    composerKey: _field,
    isBusy: isBusy,
    canSend: true,
    composerController: composer,
    composerFocusNode: focus,
    onOpenSettings: () {},
    onSend: () {},
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: widgetTestApp(
        brightness: brightness,
        center: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: busy == null
              ? panel(false)
              : ValueListenableBuilder<bool>(
                  valueListenable: busy,
                  builder: (_, value, _) => panel(value),
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (composer: composer, focus: focus);
}

ProviderContainer _container({
  List<Person> people = const [],
  VoidCallback? onCatalogRead,
  VoidCallback? onCatalogDispose,
}) => ProviderContainer(
  overrides: [
    effectiveAppSessionProvider.overrideWith(
      (ref) async => const AppSessionState(
        status: AppLockStatus.unlocked,
        session: UnlockedVaultSession(vaultId: 'vault', trustedDevice: true),
      ),
    ),
    peopleCatalogProvider.overrideWith((ref) async {
      onCatalogRead?.call();
      ref.onDispose(() => onCatalogDispose?.call());
      return PeopleCatalog(
        relationshipTypes: defaultBuiltinRelationshipTypes(),
        people: people,
      );
    }),
  ],
);

void main() {
  testWidgets('人物建議延後載入，選取別名後插入日記稱呼並保留私密區間', (tester) async {
    var reads = 0;
    var disposals = 0;
    final now = DateTime(2026);
    final container = _container(
      people: [
        Person(
          id: 'ming',
          name: '王小明',
          aliases: ['小明', '阿明同學'],
          mentionName: '阿明同學',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      onCatalogRead: () => reads++,
      onCatalogDispose: () => disposals++,
    );
    addTearDown(container.dispose);
    final input = await _pumpInput(tester, container);
    expect(reads, 0);
    expect(container.exists(peopleMentionStatsMapProvider), isFalse);
    await tester.tap(find.byKey(_field));
    input.composer.setDocument('秘密 @小 尾巴', const [
      PrivateTextRange(0, 2),
      PrivateTextRange(3, 5),
      PrivateTextRange(6, 8),
    ]);
    input.composer.selection = const TextSelection.collapsed(offset: 5);
    await tester.pumpAndSettle();
    expect(reads, 1);
    await tester.tap(find.widgetWithText(FilterChip, '阿明同學'));
    await tester.pumpAndSettle();
    expect(input.composer.text, '秘密 阿明同學 尾巴');
    expect(input.composer.selection.baseOffset, 7);
    expect(input.composer.privateRanges.map((r) => (r.start, r.end)), [
      (0, 2),
      (3, 7),
      (8, 10),
    ]);
    expect(input.focus.hasFocus, isTrue);
    expect(find.byType(PersonSuggestionPanel), findsNothing);
    expect(disposals, 1);
    expect(container.exists(peopleMentionStatsMapProvider), isFalse);
  });

  testWidgets('全形 ＠ 支援方向鍵與 Enter 選取，Esc 關閉建議', (tester) async {
    final now = DateTime(2026);
    final container = _container(
      people: [
        for (var i = 0; i < 3; i++)
          Person(id: '$i', name: '朋友$i', createdAt: now, updatedAt: now),
      ],
    );
    addTearDown(container.dispose);
    final input = await _pumpInput(tester, container);
    await tester.enterText(find.byKey(_field), '＠');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(input.composer.text, '朋友1');
    await tester.enterText(find.byKey(_field), '@');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(PersonSuggestionPanel), findsNothing);
    expect(input.composer.text, '@');
  });

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} 窄畫面大字與鍵盤下人物可橫向捲動，忙碌時收起', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final now = DateTime(2026);
      final container = _container(
        people: [
          for (var i = 0; i < 6; i++)
            Person(id: '$i', name: '測試朋友$i', createdAt: now, updatedAt: now),
        ],
      );
      addTearDown(container.dispose);
      final busy = ValueNotifier(false);
      addTearDown(busy.dispose);
      await _pumpInput(tester, container, busy: busy, brightness: brightness);
      await tester.enterText(find.byKey(_field), '@');
      await tester.pumpAndSettle();
      final surface = find.byKey(const ValueKey('ai-composer-surface'));
      final suggestions = find.byType(PersonSuggestionPanel);
      expect(
        tester.getRect(suggestions).top,
        tester.getRect(surface).bottom + 8,
      );
      expect(tester.getRect(suggestions).left, tester.getRect(surface).left);
      expect(tester.getRect(suggestions).right, tester.getRect(surface).right);
      await tester.drag(
        find.byType(PersonSuggestionPanel),
        const Offset(-1000, 0),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilterChip, '測試朋友5').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      busy.value = true;
      await tester.pump();
      expect(find.byType(PersonSuggestionPanel), findsNothing);
      expect(tester.widget<TextField>(find.byKey(_field)).enabled, isFalse);
    });
  }

  testWidgets('查無人物可取消或儲存新增，成功後回填原查詢', (tester) async {
    final scope = (await tester.runAsync(
      () => OrganizationTestScope.create(),
    ))!;
    addTearDown(() => tester.runAsync(scope.dispose));
    final input = await _pumpInput(tester, scope.container);
    await tester.enterText(find.byKey(_field), '遇到@新朋友');
    await tester.pumpAndSettle();
    final create = find.widgetWithText(
      TextButton,
      testZhL10n.editorMentionCreatePerson,
    );
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '姓名'))
          .controller!
          .text,
      '新朋友',
    );
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(input.composer.text, '遇到@新朋友');
    await tester.tap(find.byKey(_field));
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存'));
    await _waitForUi(tester, () => !input.composer.text.contains('@'));
    await tester.pumpAndSettle();
    expect(input.composer.text, '遇到新朋友');
    expect(input.focus.hasFocus, isTrue);
    final people = await tester.runAsync(
      () => scope.harness.repository.readPeopleCatalog(scope.setup.session),
    );
    expect(people!.people.single.name, '新朋友');
    expect(tester.takeException(), isNull);
  });

  testWidgets('新增人物遇到背景或輸入區移除會關閉，過期的查詢不回填', (tester) async {
    final scope = (await tester.runAsync(
      () => OrganizationTestScope.create(),
    ))!;
    addTearDown(() => tester.runAsync(scope.dispose));
    final input = await _pumpInput(tester, scope.container);
    await tester.enterText(find.byKey(_field), '@新朋友');
    await tester.pumpAndSettle();
    final create = find.widgetWithText(
      TextButton,
      testZhL10n.editorMentionCreatePerson,
    );
    await tester.tap(create);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.byType(PersonComposerDialog), findsNothing);
    expect(find.byType(PersonSuggestionPanel), findsNothing);
    expect(input.composer.text, '@新朋友');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(_field), '@新朋友');
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    final route = ModalRoute.of(
      tester.element(find.byType(PersonComposerDialog)),
    )!;
    input.composer.text = '已改成其他訊息';
    final now = DateTime(2026);
    route.navigator!.pop(
      Person(id: 'late', name: '晚到的人物', createdAt: now, updatedAt: now),
    );
    await tester.pumpAndSettle();
    expect(input.composer.text, '已改成其他訊息');
    await tester.enterText(find.byKey(_field), '@另一位');
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    final panelContext = tester.element(find.byType(AiChatInputPanel));
    final navigator = Navigator.of(panelContext);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(navigator.mounted, isFalse);
    expect(tester.takeException(), isNull);
  });
}
