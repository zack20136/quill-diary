import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_lock_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_lock_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_lock_diary/features/session/providers/session_providers.dart';
import 'package:quill_lock_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_lock_diary/features/session/session_messages.dart';
import 'package:quill_lock_diary/features/session/session_timeout_policy.dart';
import 'package:quill_lock_diary/features/session/state/app_session_state.dart';
import 'package:quill_lock_diary/features/session/state/resume_unlock_action.dart';
import 'package:quill_lock_diary/features/session/state/unlock_result.dart';
import 'package:quill_lock_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_lock_diary/shared/providers/core_providers.dart';

import '../helpers/fake_app_lock_service.dart';
import '../helpers/fake_vault_repository.dart';

void main() {
  final RecoveryMetadata metadata = RecoveryMetadata(
    vaultId: 'vlt_controller_test',
    recoveryEnabled: true,
    recoveryKeyVersion: 1,
    recoveryKeyHint: 'ABCD',
    createdAt: DateTime.parse('2026-05-19T00:00:00Z'),
    kdf: KdfDescriptor.argon2idRecovery(
      saltBytes: Uint8List.fromList(List<int>.filled(16, 2)),
    ),
  );

  final UnlockedVaultSession sampleSession = UnlockedVaultSession(
    vaultId: metadata.vaultId,
    trustedDevice: true,
    recoveryWrapKey: List<int>.filled(32, 9),
    deviceSlotId: 'dev_slot',
  );

  ProviderContainer buildContainer(
    FakeVaultRepository repository, {
    FakeAppLockService? appLock,
  }) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        vaultRepositoryProvider.overrideWithValue(repository),
        appLockServiceProvider.overrideWithValue(appLock ?? FakeAppLockService()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('unlock 成功時還原 trusted session', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    final UnlockOutcome outcome = await controller.unlock();

    expect(outcome, UnlockOutcome.success);
    expect(container.read(appSessionProvider).status, AppLockStatus.unlocked);
    expect(container.read(appSessionProvider).session, sampleSession);
    expect(repository.ensureIndexReadyCalls, 1);
  });

  test('unlock 失敗時維持 locked', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      openTrustedSessionResult: const DeviceKeyUserCancelledException(),
    );
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    final UnlockOutcome outcome = await controller.unlock();

    expect(outcome, UnlockOutcome.failed);
    expect(container.read(appSessionProvider).status, AppLockStatus.locked);
    expect(repository.clearTrustedDeviceAccessCalls, 0);
  });

  test('lock 會清除 session 並標記為 locked', () async {
    final FakeVaultRepository repository = FakeVaultRepository();
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    await controller.lock();

    final AppSessionState state = container.read(appSessionProvider);
    expect(state.status, AppLockStatus.locked);
    expect(state.session, isNull);
    expect(state.message, kAppLockedMessage);
    expect(repository.closeUnlockedResourcesCalls, 1);
  });

  test('unlockWithRecovery 成功時進入 unlocked', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      unlockWithRecoveryKeyResult: sampleSession,
    );
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    await controller.unlockWithRecovery('RECOVERY-KEY');

    final AppSessionState state = container.read(appSessionProvider);
    expect(state.status, AppLockStatus.unlocked);
    expect(state.session, sampleSession);
    expect(repository.ensureIndexReadyCalls, 1);
  });

  test('unlockWithRecovery 失敗時進入 recoveryRequired', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      unlockWithRecoveryKeyResult: StateError('bad recovery key'),
    );
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    await expectLater(
      controller.unlockWithRecovery('BAD-KEY'),
      throwsA(isA<StateError>()),
    );

    final AppSessionState state = container.read(appSessionProvider);
    expect(state.status, AppLockStatus.recoveryRequired);
    expect(state.session, isNull);
  });

  test('runSensitiveTask 未解鎖時拋錯', () async {
    final FakeVaultRepository repository = FakeVaultRepository();
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    expect(
      () => controller.runSensitiveTask((UnlockedVaultSession session) async => session.vaultId),
      throwsA(isA<StateError>()),
    );
  });

  test('runSensitiveTask 執行期間延後 closeUnlockedResources', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    DateTime fakeNow = DateTime.utc(2026, 5, 19, 12, 0);
    controller.clock = () => fakeNow;

    final Completer<String> gate = Completer<String>();
    final Future<String> task = controller.runSensitiveTask((UnlockedVaultSession session) async {
      await gate.future;
      return session.vaultId;
    });

    await controller.handleLifecycleChange(AppLifecycleState.paused);
    fakeNow = fakeNow.add(defaultSessionTimeout + const Duration(seconds: 1));
    await controller.handleLifecycleChange(AppLifecycleState.resumed);
    expect(repository.closeUnlockedResourcesCalls, 0);

    gate.complete('ok');
    await task;
    expect(repository.closeUnlockedResourcesCalls, 1);
  });

  test('reset 會回到 uninitialized 並關閉資源', () async {
    final FakeVaultRepository repository = FakeVaultRepository();
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    await controller.reset();

    expect(container.read(appSessionProvider).status, AppLockStatus.uninitialized);
    expect(repository.closeUnlockedResourcesCalls, 1);
  });

  test('無解鎖模式：背景逾時後自動以 plain trusted 解鎖', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    final FakeAppLockService appLock = FakeAppLockService(
      unlockMode: AppUnlockMode.none,
    );
    final ProviderContainer container = buildContainer(repository, appLock: appLock);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    DateTime fakeNow = DateTime.utc(2026, 5, 19, 12, 0);
    controller.clock = () => fakeNow;

    await controller.handleLifecycleChange(AppLifecycleState.paused);
    fakeNow = fakeNow.add(defaultSessionTimeout + const Duration(seconds: 1));
    await controller.handleLifecycleChange(AppLifecycleState.resumed);

    final AppSessionState state = container.read(appSessionProvider);
    expect(state.status, AppLockStatus.unlocked);
    expect(repository.openTrustedSessionCalls, 1);
  });

  test('裝置螢幕鎖模式：背景逾時後維持 locked 並標記 keystoreUnlock', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    final FakeAppLockService appLock = FakeAppLockService(
      unlockMode: AppUnlockMode.deviceLock,
    );
    final ProviderContainer container = buildContainer(repository, appLock: appLock);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    DateTime fakeNow = DateTime.utc(2026, 5, 19, 12, 0);
    controller.clock = () => fakeNow;

    await controller.handleLifecycleChange(AppLifecycleState.paused);
    fakeNow = fakeNow.add(defaultSessionTimeout + const Duration(seconds: 1));
    await controller.handleLifecycleChange(AppLifecycleState.resumed);

    final AppSessionState state = container.read(appSessionProvider);
    expect(state.status, AppLockStatus.locked);
    expect(state.resumeAction, ResumeUnlockAction.keystoreUnlock);
    expect(repository.openTrustedSessionCalls, 0);
  });

  test('生物驗證模式：背景逾時後維持 locked 並標記 keystoreUnlock', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    final FakeAppLockService appLock = FakeAppLockService(
      unlockMode: AppUnlockMode.biometric,
      canUseDeviceCredentialResult: true,
    );
    final ProviderContainer container = buildContainer(repository, appLock: appLock);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    DateTime fakeNow = DateTime.utc(2026, 5, 19, 12, 0);
    controller.clock = () => fakeNow;

    await controller.handleLifecycleChange(AppLifecycleState.paused);
    fakeNow = fakeNow.add(defaultSessionTimeout + const Duration(seconds: 1));
    await controller.handleLifecycleChange(AppLifecycleState.resumed);

    final AppSessionState state = container.read(appSessionProvider);
    expect(state.status, AppLockStatus.locked);
    expect(state.resumeAction, ResumeUnlockAction.keystoreUnlock);
    expect(repository.openTrustedSessionCalls, 0);
  });

  test('背景未逾時時不鎖定', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    DateTime fakeNow = DateTime.utc(2026, 5, 19, 12, 0);
    controller.clock = () => fakeNow;

    await controller.handleLifecycleChange(AppLifecycleState.paused);
    fakeNow = fakeNow.add(const Duration(minutes: 1));
    await controller.handleLifecycleChange(AppLifecycleState.resumed);

    expect(container.read(appSessionProvider).status, AppLockStatus.unlocked);
    expect(repository.openTrustedSessionCalls, 0);
  });
}
