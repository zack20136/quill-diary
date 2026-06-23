import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/session_inactivity_watchdog.dart';
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
    bool supportedPlatform = true,
  }) {
    return [
      supportedPlatformProvider.overrideWithValue(supportedPlatform),
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

  void primeUnlockedSession(
    AppSessionController controller,
    UnlockedVaultSession session,
  ) {
    controller.activateSession(session);
    controller.markTrustedUnlockBootstrapFinished();
    controller.armLifecycleResumeUnlock();
  }

  final UnlockedVaultSession sampleSession = UnlockedVaultSession(
    vaultId: 'vlt_binding_test',
    trustedDevice: true,
    recoveryWrapKey: List<int>.filled(32, 9),
    deviceSlotId: 'dev_slot',
  );

  final RecoveryMetadata coldStartMetadata = RecoveryMetadata(
    vaultId: 'vlt_binding_cold_start',
    recoveryEnabled: true,
    recoveryKeyVersion: 1,
    recoveryKeyHint: 'UVWX',
    createdAt: DateTime.parse('2026-05-19T00:00:00Z'),
    kdf: KdfDescriptor.argon2idRecovery(
      saltBytes: Uint8List.fromList(List<int>.filled(16, 7)),
    ),
  );

  final UnlockedVaultSession coldStartSession = UnlockedVaultSession(
    vaultId: coldStartMetadata.vaultId,
    trustedDevice: true,
    recoveryWrapKey: List<int>.filled(32, 3),
    deviceSlotId:
        'dev_android_keystore_deviceCredential_${coldStartMetadata.vaultId}',
  );

  testWidgets('冷啟動 appStartupProvider 與 lifecycle 競態只 unlock 一次', (
    WidgetTester tester,
  ) async {
    final Completer<UnlockedVaultSession> unlockGate =
        Completer<UnlockedVaultSession>();
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      metadata: coldStartMetadata,
      hasTrustedDevice: true,
      openTrustedSessionResult: unlockGate.future,
    );
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: bindingOverrides(
          repository: repository,
          appLock: FakeAppLockService(unlockMode: AppUnlockMode.deviceLock),
        ),
        child: const _ColdStartBindingHost(resumeUnlockDelay: Duration.zero),
      ),
    );
    await tester.pump();
    container = ProviderScope.containerOf(
      tester.element(find.byType(_ColdStartBindingHost)),
    );

    final Future<AppSessionState> startupFuture = container.read(
      appStartupProvider.future,
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flushAsyncLifecycleWork(tester);

    unlockGate.complete(coldStartSession);
    await startupFuture;
    await flushAsyncLifecycleWork(tester);
    await tester.pump(kSessionForegroundSettleDelay);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flushAsyncLifecycleWork(tester);
    await tester.pump(const Duration(milliseconds: 50));

    expect(repository.openTrustedSessionCalls, 1);
    expect(
      container.read(appSessionProvider.notifier).startupPhase,
      TrustedUnlockStartupPhase.lifecycleResumeArmed,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('bootstrap 期間 paused/resumed 不觸發第二次 unlock', (
    WidgetTester tester,
  ) async {
    final Completer<UnlockedVaultSession> unlockGate =
        Completer<UnlockedVaultSession>();
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      openTrustedSessionResult: unlockGate.future,
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
    expect(controller.trustedUnlockBootstrapActive, isTrue);

    final Future<UnlockOutcome> bootstrapUnlock = controller.unlock();
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flushAsyncLifecycleWork(tester);

    unlockGate.complete(sampleSession);
    await bootstrapUnlock;
    controller.endTrustedUnlockBootstrap();
    await tester.pump();

    expect(
      controller.startupPhase,
      TrustedUnlockStartupPhase.awaitingFirstBackground,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flushAsyncLifecycleWork(tester);
    await tester.pump(const Duration(milliseconds: 50));

    expect(repository.openTrustedSessionCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

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
    primeUnlockedSession(controller, sampleSession);
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
    primeUnlockedSession(controller, sampleSession);
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
    primeUnlockedSession(controller, sampleSession);
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

  testWidgets('手動驗證取消後不因 inactive/resumed 立刻重試', (
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
    primeUnlockedSession(controller, sampleSession);
    await controller.expireFromInactivity();

    final Future<UnlockOutcome> unlockFuture = controller.unlock();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await unlockFuture;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flushAsyncLifecycleWork(tester);

    expect(container.read(appSessionProvider).status, AppLockStatus.locked);
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
    primeUnlockedSession(controller, sampleSession);
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

  testWidgets('manual 鎖定後 resumed 不觸發 openTrustedSession', (
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
    primeUnlockedSession(controller, sampleSession);
    await controller.lock();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flushAsyncLifecycleWork(tester);

    expect(container.read(appSessionProvider).status, AppLockStatus.locked);
    expect(repository.openTrustedSessionCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _BindingHost extends ConsumerStatefulWidget {
  const _BindingHost({
    this.resumeUnlockDelay = Duration.zero,
  });

  final Duration resumeUnlockDelay;

  @override
  ConsumerState<_BindingHost> createState() => _BindingHostState();
}

class _ColdStartBindingHost extends ConsumerStatefulWidget {
  const _ColdStartBindingHost({
    this.resumeUnlockDelay = Duration.zero,
  });

  final Duration resumeUnlockDelay;

  @override
  ConsumerState<_ColdStartBindingHost> createState() =>
      _ColdStartBindingHostState();
}

class _ColdStartBindingHostState extends ConsumerState<_ColdStartBindingHost> {
  late final SessionLifecycleBinding binding;

  @override
  void initState() {
    super.initState();
    binding = SessionLifecycleBinding(
      ref,
      resumeUnlockDelay: widget.resumeUnlockDelay,
    );
    binding.attach();
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      ref.read(appStartupProvider.future);
    });
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
