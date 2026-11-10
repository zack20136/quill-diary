import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/persona/persona_providers.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_companion_bar.dart';

import '../../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('夥伴面板可選預設，外部點擊、Esc、背景與鎖定會關閉', (tester) async {
    var locked = false;
    var selectedDefault = false;
    final container = ProviderContainer(
      overrides: [
        effectiveAppSessionProvider.overrideWith(
          (ref) async => AppSessionState(
            status: locked ? AppLockStatus.locked : AppLockStatus.unlocked,
            session: locked
                ? null
                : const UnlockedVaultSession(
                    vaultId: 'vault',
                    trustedDevice: true,
                  ),
          ),
        ),
        savedPersonasProvider.overrideWith((ref) async => []),
        peopleListProvider.overrideWith((ref) => const AsyncData([])),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: widgetTestApp(
          center: false,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: ChatDiaryCompanionBar(
              current: null,
              name: null,
              enabled: true,
              onSelected: (persona) async {
                selectedDefault = persona == null;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tag = find.byKey(const ValueKey('chat-companion-bar'));
    final menu = find.byKey(const ValueKey('chat-companion-choices'));
    Future<void> open() async {
      await tester.tap(tag);
      await tester.pumpAndSettle();
      expect(menu, findsOneWidget);
    }

    await open();
    expect(find.byType(ListTile), findsOneWidget);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(selectedDefault, isTrue);
    expect(menu, findsNothing);
    await open();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    await open();
    await tester.tapAt(const Offset(700, 30));
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    await open();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await open();
    locked = true;
    container.invalidate(effectiveAppSessionProvider);
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
