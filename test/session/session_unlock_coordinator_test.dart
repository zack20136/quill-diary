import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/features/session/application/session_unlock_coordinator.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/session_timeout_policy.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/session/state/resume_unlock_action.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

import '../helpers/fake_app_lock_service.dart';
import '../helpers/fake_vault_repository.dart';

void main() {
  final RecoveryMetadata metadata = RecoveryMetadata(
    vaultId: 'vlt_coordinator_test',
    recoveryEnabled: true,
    recoveryKeyVersion: 1,
    recoveryKeyHint: 'ABCD',
    createdAt: DateTime.parse('2026-05-19T00:00:00Z'),
    kdf: KdfDescriptor.argon2idRecovery(
      saltBytes: List<int>.filled(16, 2),
    ),
  );

  final UnlockedVaultSession sampleSession = UnlockedVaultSession(
    vaultId: metadata.vaultId,
    trustedDevice: true,
    recoveryWrapKey: List<int>.filled(32, 9),
    deviceSlotId: 'dev_slot',
  );

  Future<ProviderContainer> pumpCoordinator(
    WidgetTester tester, {
    required FakeVaultRepository repository,
    FakeAppLockService? appLock,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultRepositoryProvider.overrideWithValue(repository),
          appLockServiceProvider.overrideWithValue(appLock ?? FakeAppLockService()),
        ],
        child: const MaterialApp(home: _CoordinatorHost()),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(_CoordinatorHost)));
  }

  Future<void> triggerAutoTrustedResume(AppSessionController controller) async {
    controller.activateSession(sampleSession);
    DateTime fakeNow = DateTime.utc(2026, 5, 19, 12, 0);
    controller.clock = () => fakeNow;
    await controller.handleLifecycleChange(AppLifecycleState.paused);
    fakeNow = fakeNow.add(defaultSessionTimeout + const Duration(seconds: 1));
    await controller.handleLifecycleChange(AppLifecycleState.resumed);
  }

  testWidgets('autoTrusted resumeAction 觸發 unlock', (WidgetTester tester) async {
    final FakeVaultRepository repository = FakeVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    final FakeAppLockService appLock = FakeAppLockService(unlockMode: AppUnlockMode.none);
    final ProviderContainer container = await pumpCoordinator(
      tester,
      repository: repository,
      appLock: appLock,
    );
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    await triggerAutoTrustedResume(controller);
    await tester.pump();
    await tester.pump();

    expect(container.read(appSessionProvider).status, AppLockStatus.unlocked);
    expect(repository.openTrustedSessionCalls, 1);
  });

  testWidgets('keystoreUnlock resumeAction 觸發 unlock', (WidgetTester tester) async {
    final FakeVaultRepository repository = FakeVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    final FakeAppLockService appLock = FakeAppLockService(
      unlockMode: AppUnlockMode.deviceLock,
    );
    final ProviderContainer container = await pumpCoordinator(
      tester,
      repository: repository,
      appLock: appLock,
    );
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    DateTime fakeNow = DateTime.utc(2026, 5, 19, 12, 0);
    controller.clock = () => fakeNow;
    await controller.handleLifecycleChange(AppLifecycleState.paused);
    fakeNow = fakeNow.add(defaultSessionTimeout + const Duration(seconds: 1));
    await controller.handleLifecycleChange(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(container.read(appSessionProvider).status, AppLockStatus.unlocked);
    expect(repository.openTrustedSessionCalls, 1);
  });

  testWidgets('resumeAction 為 null 時不觸發 unlock', (WidgetTester tester) async {
    final FakeVaultRepository repository = FakeVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    final ProviderContainer container = await pumpCoordinator(tester, repository: repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    await controller.lock();
    await tester.pump();
    await tester.pump();

    expect(container.read(appSessionProvider).resumeAction, isNull);
    expect(repository.openTrustedSessionCalls, 0);
  });

  testWidgets('unlock 失敗時維持 locked', (WidgetTester tester) async {
    final FakeVaultRepository repository = FakeVaultRepository(
      openTrustedSessionResult: const DeviceKeyUserCancelledException(),
    );
    final ProviderContainer container = await pumpCoordinator(tester, repository: repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    await triggerAutoTrustedResume(controller);
    await tester.pump();
    await tester.pump();

    expect(container.read(appSessionProvider).status, AppLockStatus.locked);
    expect(repository.openTrustedSessionCalls, 1);
  });
}

class _CoordinatorHost extends ConsumerStatefulWidget {
  const _CoordinatorHost();

  @override
  ConsumerState<_CoordinatorHost> createState() => _CoordinatorHostState();
}

class _CoordinatorHostState extends ConsumerState<_CoordinatorHost> {
  bool _coordinatorAttached = false;

  @override
  Widget build(BuildContext context) {
    if (!_coordinatorAttached) {
      _coordinatorAttached = true;
      SessionUnlockCoordinator(ref).listen();
    }
    return const SizedBox.shrink();
  }
}
