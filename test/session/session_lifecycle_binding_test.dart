import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/session_lifecycle_binding.dart';
import 'package:quill_diary/features/session/session_timeout_policy.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

import '../helpers/fake_app_lock_service.dart';
import '../helpers/fake_session_vault_repository.dart';

void main() {
  final UnlockedVaultSession sampleSession = UnlockedVaultSession(
    vaultId: 'vlt_binding_test',
    trustedDevice: true,
    recoveryWrapKey: List<int>.filled(32, 9),
    deviceSlotId: 'dev_slot',
  );

  testWidgets('背景逾時後 resumed 會 post-frame 觸發 unlock', (WidgetTester tester) async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultRepositoryProvider.overrideWithValue(repository),
          appLockServiceProvider.overrideWithValue(
            FakeAppLockService(unlockMode: AppUnlockMode.none),
          ),
        ],
        child: const _BindingHost(),
      ),
    );
    await tester.pump();
    container = ProviderScope.containerOf(tester.element(find.byType(_BindingHost)));

    final AppSessionController controller = container.read(appSessionProvider.notifier);
    controller.activateSession(sampleSession);

    DateTime fakeNow = DateTime.utc(2026, 5, 19, 12, 0);
    controller.inactivityWatchdog.clock = () => fakeNow;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    fakeNow = fakeNow.add(defaultSessionTimeout + const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 50));

    expect(container.read(appSessionProvider).status, AppLockStatus.unlocked);
    expect(repository.openTrustedSessionCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _BindingHost extends ConsumerStatefulWidget {
  const _BindingHost();

  @override
  ConsumerState<_BindingHost> createState() => _BindingHostState();
}

class _BindingHostState extends ConsumerState<_BindingHost> {
  late final SessionLifecycleBinding binding = SessionLifecycleBinding(ref);

  @override
  void initState() {
    super.initState();
    binding.attach();
  }

  @override
  void dispose() {
    binding.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return binding.wrap(const MaterialApp(home: SizedBox.shrink()));
  }
}
