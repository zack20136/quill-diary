import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/session_lifecycle_binding.dart';
import 'package:quill_diary/features/session/session_timeout_policy.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/session/state/session_lock_reason.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

import '../helpers/fake_app_lock_service.dart';
import '../helpers/fake_session_vault_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final File preferencesFile = File(
    '${Directory.systemTemp.path}/session_lifecycle_binding_test_prefs.json',
  );

  tearDown(() async {
    if (preferencesFile.existsSync()) {
      await preferencesFile.delete();
    }
  });

  bindingOverrides({
    required FakeSessionVaultRepository repository,
    required FakeAppLockService appLock,
  }) {
    return [
      vaultRepositoryProvider.overrideWithValue(repository),
      appLockServiceProvider.overrideWithValue(appLock),
      userPreferencesProvider.overrideWithValue(
        UserPreferences(storageFile: preferencesFile),
      ),
    ];
  }

  Future<void> flushAsyncLifecycleWork(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  void armInactivityWatchdog(AppSessionController controller) {
    controller.inactivityWatchdog.foregroundSettleDelay = Duration.zero;
  }

  final UnlockedVaultSession sampleSession = UnlockedVaultSession(
    vaultId: 'vlt_binding_test',
    trustedDevice: true,
    recoveryWrapKey: List<int>.filled(32, 9),
    deviceSlotId: 'dev_slot',
  );

  testWidgets('背景逾時後 resumed 會 post-frame 觸發 unlock', (
    WidgetTester tester,
  ) async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: bindingOverrides(
          repository: repository,
          appLock: FakeAppLockService(unlockMode: AppUnlockMode.none),
        ),
        child: const _BindingHost(),
      ),
    );
    await tester.pump();
    container = ProviderScope.containerOf(
      tester.element(find.byType(_BindingHost)),
    );

    final AppSessionController controller = container.read(
      appSessionProvider.notifier,
    );
    controller.activateSession(sampleSession);
    armInactivityWatchdog(controller);

    DateTime fakeNow = DateTime.utc(2026, 5, 19, 12, 0);
    controller.inactivityWatchdog.clock = () => fakeNow;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    fakeNow = fakeNow.add(defaultSessionTimeout + const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flushAsyncLifecycleWork(tester);
    await tester.pump(const Duration(milliseconds: 50));

    expect(container.read(appSessionProvider).status, AppLockStatus.unlocked);
    expect(repository.openTrustedSessionCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('背景 timer 已先鎖定時，resumed 仍會自動重新驗證', (WidgetTester tester) async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: bindingOverrides(
          repository: repository,
          appLock: FakeAppLockService(unlockMode: AppUnlockMode.none),
        ),
        child: const _BindingHost(resumeUnlockDelay: Duration.zero),
      ),
    );
    await tester.pump();
    container = ProviderScope.containerOf(
      tester.element(find.byType(_BindingHost)),
    );

    final AppSessionController controller = container.read(
      appSessionProvider.notifier,
    );
    controller.activateSession(sampleSession);
    armInactivityWatchdog(controller);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(defaultSessionTimeout + const Duration(seconds: 1));
    await flushAsyncLifecycleWork(tester);

    final AppSessionState lockedState = container.read(appSessionProvider);
    expect(lockedState.status, AppLockStatus.locked);
    expect(lockedState.lockReason, SessionLockReason.inactivity);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flushAsyncLifecycleWork(tester);

    expect(container.read(appSessionProvider).status, AppLockStatus.unlocked);
    expect(repository.openTrustedSessionCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('resumed 自動驗證若取消，維持 locked 且同次 resumed 不立刻重試', (
    WidgetTester tester,
  ) async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      openTrustedSessionResult: const DeviceKeyUserCancelledException(),
    );
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: bindingOverrides(
          repository: repository,
          appLock: FakeAppLockService(unlockMode: AppUnlockMode.deviceLock),
        ),
        child: const _BindingHost(resumeUnlockDelay: Duration.zero),
      ),
    );
    await tester.pump();
    container = ProviderScope.containerOf(
      tester.element(find.byType(_BindingHost)),
    );

    final AppSessionController controller = container.read(
      appSessionProvider.notifier,
    );
    controller.activateSession(sampleSession);
    armInactivityWatchdog(controller);

    DateTime fakeNow = DateTime.utc(2026, 5, 19, 12, 0);
    controller.inactivityWatchdog.clock = () => fakeNow;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    fakeNow = fakeNow.add(defaultSessionTimeout + const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flushAsyncLifecycleWork(tester);

    final AppSessionState state = container.read(appSessionProvider);
    expect(state.status, AppLockStatus.locked);
    expect(state.lockReason, SessionLockReason.inactivity);
    expect(repository.openTrustedSessionCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('authFailed 狀態 resumed 時仍會再次主動驗證', (WidgetTester tester) async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      openTrustedSessionResults: <Object?>[
        const DeviceKeyAuthFailedException('bio failed'),
        sampleSession,
      ],
    );
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: bindingOverrides(
          repository: repository,
          appLock: FakeAppLockService(unlockMode: AppUnlockMode.biometric),
        ),
        child: const _BindingHost(resumeUnlockDelay: Duration.zero),
      ),
    );
    await tester.pump();
    container = ProviderScope.containerOf(
      tester.element(find.byType(_BindingHost)),
    );

    final AppSessionController controller = container.read(
      appSessionProvider.notifier,
    );
    controller.activateSession(sampleSession);
    armInactivityWatchdog(controller);
    await controller.expireFromInactivity();
    await controller.unlock(source: UnlockRequestSource.lifecycleResume);

    expect(
      container.read(appSessionProvider).lockReason,
      SessionLockReason.authFailed,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flushAsyncLifecycleWork(tester);

    expect(container.read(appSessionProvider).status, AppLockStatus.unlocked);
    expect(repository.openTrustedSessionCalls, 2);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _BindingHost extends ConsumerStatefulWidget {
  const _BindingHost({this.resumeUnlockDelay = Duration.zero});

  final Duration resumeUnlockDelay;

  @override
  ConsumerState<_BindingHost> createState() => _BindingHostState();
}

class _BindingHostState extends ConsumerState<_BindingHost> {
  late final SessionLifecycleBinding binding;

  @override
  void initState() {
    super.initState();
    binding = SessionLifecycleBinding(
      ref,
      resumeUnlockDelay: widget.resumeUnlockDelay,
    );
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
