import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/session/app_session_controller.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/widgets/entry_writing_mode_picker.dart';

import '../../helpers/shared/widget_test_app.dart';

const _session = UnlockedVaultSession(vaultId: 'vault', trustedDevice: true);

class _PickerSession extends AppSessionController {
  @override
  AppSessionState build() =>
      const AppSessionState(status: AppLockStatus.unlocked, session: _session);

  void replace(AppSessionState next) => state = next;
}

void main() {
  late ProviderContainer container;
  late TextEditingController search;
  EntryWritingMode? result;
  int completions = 0;

  Future<void> pumpHost(
    WidgetTester tester, {
    Size size = const Size(360, 800),
    Locale locale = appZhLocale,
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) async {
    result = null;
    completions = 0;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    container = ProviderContainer(
      overrides: [appSessionProvider.overrideWith(_PickerSession.new)],
    );
    addTearDown(container.dispose);
    search = TextEditingController(text: '保留的搜尋');
    addTearDown(search.dispose);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await container.read(effectiveAppSessionProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: widgetTestApp(
          locale: locale,
          brightness: brightness,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(key: const ValueKey('search'), controller: search),
              FilledButton(
                onPressed: () async {
                  result = await showEntryWritingModePicker(
                    tester.element(find.byType(FilledButton)),
                    session: _session,
                  );
                  completions++;
                },
                child: const Text('開啟'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
  }

  void resumeApp(WidgetTester tester) {
    if (tester.binding.lifecycleState == AppLifecycleState.paused) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    }
    if (tester.binding.lifecycleState == AppLifecycleState.hidden) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    }
    if (tester.binding.lifecycleState == AppLifecycleState.inactive) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
  }

  for (final mode in EntryWritingMode.values) {
    testWidgets('點擊 ${mode.name} 卡片留白處會回傳對應模式，連點只完成一次', (tester) async {
      await pumpHost(tester);
      await open(tester);
      final card = find.byKey(ValueKey('entry-writing-mode-${mode.name}'));
      expect(tester.getSize(card).height, greaterThanOrEqualTo(80));
      final point = tester.getTopLeft(card) + const Offset(8, 12);
      await tester.tapAt(point);
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(result, mode);
      expect(completions, 1);
      expect(find.text('開啟'), findsOneWidget);
    });
  }

  for (final wide in [false, true]) {
    for (final cancel in ['outside', 'close', 'back', if (!wide) 'drag']) {
      testWidgets('${wide ? '寬版' : '手機'}以 $cancel 取消時不回傳模式或清除搜尋', (
        tester,
      ) async {
        await pumpHost(
          tester,
          size: wide ? const Size(900, 700) : const Size(360, 800),
        );
        await open(tester);
        switch (cancel) {
          case 'outside':
            await tester.tapAt(const Offset(4, 4));
          case 'close':
            await tester.tap(find.byTooltip('關閉'));
          case 'back':
            await tester.binding.handlePopRoute();
          case 'drag':
            await tester.drag(
              find.byKey(const ValueKey('entry-writing-mode-handle')),
              const Offset(0, 500),
            );
        }
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(completions, 1);
        expect(search.text, '保留的搜尋');
        expect(
          find.byKey(const ValueKey('entry-writing-mode-picker')),
          findsNothing,
        );
      });
    }
  }

  testWidgets('開啟前收起搜尋鍵盤並保留文字', (tester) async {
    await pumpHost(tester);
    await tester.showKeyboard(find.byKey(const ValueKey('search')));
    expect(tester.testTextInput.isVisible, isTrue);
    await open(tester);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(search.text, '保留的搜尋');
    expect(
      find.byKey(const ValueKey('entry-writing-mode-picker')),
      findsOneWidget,
    );
  });

  for (final change in ['locked', 'vault', 'background']) {
    testWidgets('$change 關閉選擇器，晚到點擊不回傳模式', (tester) async {
      await pumpHost(tester);
      await open(tester);
      final lateTap = tester
          .widget<InkWell>(
            find.descendant(
              of: find.byKey(const ValueKey('entry-writing-mode-chat')),
              matching: find.byType(InkWell),
            ),
          )
          .onTap!;
      switch (change) {
        case 'locked':
          (container.read(appSessionProvider.notifier) as _PickerSession)
              .replace(const AppSessionState(status: AppLockStatus.locked));
        case 'vault':
          (container.read(appSessionProvider.notifier) as _PickerSession)
              .replace(
                const AppSessionState(
                  status: AppLockStatus.unlocked,
                  session: UnlockedVaultSession(
                    vaultId: 'other-vault',
                    trustedDevice: true,
                  ),
                ),
              );
        case 'background':
          for (final state in [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
          addTearDown(() => resumeApp(tester));
      }
      await tester.pumpAndSettle();
      lateTap();
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(completions, 1);
      if (change == 'background') {
        resumeApp(tester);
        await tester.pumpAndSettle();
      }
      expect(
        find.byKey(const ValueKey('entry-writing-mode-picker')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(360, 800),
    const Size(900, 700),
    const Size(520, 320),
  ]) {
    for (final locale in [appZhLocale, appEnLocale]) {
      for (final brightness in Brightness.values) {
        testWidgets('$size ${locale.languageCode} $brightness 大字級可捲動並點選兩種方式', (
          tester,
        ) async {
          await pumpHost(
            tester,
            size: size,
            locale: locale,
            brightness: brightness,
            textScale: 1.5,
          );
          await open(tester);
          final wide = size.width >= 600;
          expect(
            find.byType(BottomSheet),
            wide ? findsNothing : findsOneWidget,
          );
          expect(find.byType(Dialog), wide ? findsOneWidget : findsNothing);
          final picker = find.byKey(
            const ValueKey('entry-writing-mode-picker'),
          );
          final rect = tester.getRect(picker);
          expect(rect.width, lessThanOrEqualTo(wide ? 480 : size.width));
          expect(rect.height, lessThanOrEqualTo(size.height * 0.8));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          final l10n = lookupAppLocalizations(locale);
          expect(
            find.text(l10n.entryWritingModeDirectDescription),
            findsOneWidget,
          );
          expect(
            find.text(l10n.entryWritingModeChatDescription),
            findsOneWidget,
          );
          final chat = find.byKey(const ValueKey('entry-writing-mode-chat'));
          await tester.ensureVisible(chat);
          await tester.pumpAndSettle();
          expect(chat.hitTestable(), findsOneWidget);
          await tester.tap(chat);
          await tester.pumpAndSettle();
          expect(result, EntryWritingMode.chat);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
