import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/features/session/session_messages.dart';
import 'package:quill_diary/features/session/session_timeout_policy.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/features/session/state/session_lock_reason.dart';
import 'package:quill_diary/features/session/state/unlock_result.dart';
import 'package:quill_diary/features/settings/providers/personalization_providers.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

import '../helpers/fake_app_lock_service.dart';
import '../helpers/fake_session_vault_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    FakeSessionVaultRepository repository, {
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

  void armControllerClock(AppSessionController controller, DateTime start) {
    final DateTime fakeNow = start;
    controller.inactivityWatchdog.clock = () => fakeNow;
    controller.inactivityWatchdog.foregroundSettleDelay = Duration.zero;
  }

  DateTime advanceClock(AppSessionController controller, Duration delta) {
    final DateTime next =
        controller.inactivityWatchdog.clock().add(delta);
    controller.inactivityWatchdog.clock = () => next;
    return next;
  }

  test('unlock 成功時還原 trusted session', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    final UnlockOutcome outcome = await controller.unlock();

    expect(outcome, UnlockOutcome.success);
    expect(container.read(appSessionProvider).status, AppLockStatus.unlocked);
    expect(container.read(appSessionProvider).session, sampleSession);
    expect(repository.ensureIndexReadyCalls, 1);
    expect(controller.inactivityWatchdog.isArmed, isTrue);
  });

  test('resumeSessionAfterRestore 沿用 prior session 且不觸發 openTrustedSession', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      resumeUnlockedSessionAfterRestoreResult: sampleSession,
    );
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    final AppSessionState state = await controller.resumeSessionAfterRestore(sampleSession);

    expect(state.status, AppLockStatus.unlocked);
    expect(state.session, sampleSession);
    expect(repository.resumeUnlockedSessionAfterRestoreCalls, 1);
    expect(repository.openTrustedSessionCalls, 0);
    expect(repository.ensureIndexReadyCalls, 1);
  });

  test('unlock 失敗時維持 locked 並標記 authFailed', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      openTrustedSessionResult: const DeviceKeyUserCancelledException(),
    );
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    final UnlockOutcome outcome = await controller.unlock();

    expect(outcome, UnlockOutcome.failed);
    final AppSessionState state = container.read(appSessionProvider);
    expect(state.status, AppLockStatus.locked);
    expect(state.lockReason, SessionLockReason.authFailed);
    expect(repository.clearTrustedDeviceAccessCalls, 0);
  });

  test('resume 自動驗證若被系統提前取消，保留 inactivity 狀態供後續重試', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      openTrustedSessionResult: const DeviceKeyUserCancelledException(),
    );
    final FakeAppLockService appLock = FakeAppLockService(
      unlockMode: AppUnlockMode.deviceLock,
    );
    final ProviderContainer container = buildContainer(repository, appLock: appLock);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    await controller.expireFromInactivity();

    final UnlockOutcome outcome = await controller.unlock(
      source: UnlockRequestSource.lifecycleResume,
    );

    final AppSessionState state = container.read(appSessionProvider);
    expect(outcome, UnlockOutcome.failed);
    expect(state.status, AppLockStatus.locked);
    expect(state.lockReason, SessionLockReason.inactivity);
    expect(state.message, kUseDeviceLockToUnlockMessage);
    expect(controller.shouldAutoReauth, isTrue);
  });

  test('resume 自動驗證遇到真正驗證失敗時改為 authFailed', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      openTrustedSessionResult: const DeviceKeyAuthFailedException('bio failed'),
    );
    final FakeAppLockService appLock = FakeAppLockService(
      unlockMode: AppUnlockMode.biometric,
      canUseDeviceCredentialResult: true,
    );
    final ProviderContainer container = buildContainer(repository, appLock: appLock);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    await controller.expireFromInactivity();

    final UnlockOutcome outcome = await controller.unlock(
      source: UnlockRequestSource.lifecycleResume,
    );

    final AppSessionState state = container.read(appSessionProvider);
    expect(outcome, UnlockOutcome.failed);
    expect(state.status, AppLockStatus.locked);
    expect(state.lockReason, SessionLockReason.authFailed);
    expect(state.message, kLockedRetryVerificationMessage);
    expect(controller.shouldAutoReauth, isFalse);
  });

  test('lock 會清除 session 並標記 manual', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository();
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    await controller.lock();

    final AppSessionState state = container.read(appSessionProvider);
    expect(state.status, AppLockStatus.locked);
    expect(state.lockReason, SessionLockReason.manual);
    expect(state.session, isNull);
    expect(state.message, kAppLockedMessage);
    expect(repository.closeUnlockedResourcesCalls, 1);
  });

  test('unlockWithRecovery 成功時進入 unlocked', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
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
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
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
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository();
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    expect(
      () => controller.runSensitiveTask((UnlockedVaultSession session) async => session.vaultId),
      throwsA(isA<StateError>()),
    );
  });

  test('runSensitiveTask 執行期間背景逾時不鎖定也不釋放資源', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    armControllerClock(controller, DateTime.utc(2026, 5, 19, 12, 0));

    final Completer<String> gate = Completer<String>();
    final Future<String> task = controller.runSensitiveTask((UnlockedVaultSession session) async {
      await gate.future;
      return session.vaultId;
    });

    controller.notifyAppBackground();
    advanceClock(controller, defaultSessionTimeout + const Duration(seconds: 1));
    await controller.notifyAppForegroundResumed(onForegroundSettled: () {});
    await controller.expireFromInactivity();

    expect(container.read(appSessionProvider).status, AppLockStatus.unlocked);
    expect(repository.closeUnlockedResourcesCalls, 0);

    gate.complete('ok');
    await task;
    expect(repository.closeUnlockedResourcesCalls, 0);
  });

  test('reset 會回到 uninitialized 並關閉資源', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository();
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    await controller.reset();

    expect(container.read(appSessionProvider).status, AppLockStatus.uninitialized);
    expect(repository.closeUnlockedResourcesCalls, 1);
    expect(controller.inactivityWatchdog.isArmed, isFalse);
  });

  test('背景逾時後標記 inactivity 並應自動 reauth', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    final FakeAppLockService appLock = FakeAppLockService(
      unlockMode: AppUnlockMode.none,
    );
    final ProviderContainer container = buildContainer(repository, appLock: appLock);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    armControllerClock(controller, DateTime.utc(2026, 5, 19, 12, 0));

    controller.notifyAppBackground();
    advanceClock(controller, defaultSessionTimeout + const Duration(seconds: 1));
    await controller.notifyAppForegroundResumed(onForegroundSettled: () {});
    await Future<void>.delayed(Duration.zero);

    final AppSessionState state = container.read(appSessionProvider);
    expect(state.status, AppLockStatus.locked);
    expect(state.lockReason, SessionLockReason.inactivity);
    expect(controller.shouldAutoReauth, isTrue);
    expect(repository.openTrustedSessionCalls, 0);
  });

  test('裝置螢幕鎖模式：背景逾時後標記 inactivity', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    final FakeAppLockService appLock = FakeAppLockService(
      unlockMode: AppUnlockMode.deviceLock,
    );
    final ProviderContainer container = buildContainer(repository, appLock: appLock);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    armControllerClock(controller, DateTime.utc(2026, 5, 19, 12, 0));

    controller.notifyAppBackground();
    advanceClock(controller, defaultSessionTimeout + const Duration(seconds: 1));
    await controller.expireFromInactivity();

    final AppSessionState state = container.read(appSessionProvider);
    expect(state.status, AppLockStatus.locked);
    expect(state.lockReason, SessionLockReason.inactivity);
    expect(state.message, kUseDeviceLockToUnlockMessage);
  });

  test('生物驗證模式：背景逾時後標記 inactivity', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    final FakeAppLockService appLock = FakeAppLockService(
      unlockMode: AppUnlockMode.biometric,
      canUseDeviceCredentialResult: true,
    );
    final ProviderContainer container = buildContainer(repository, appLock: appLock);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    armControllerClock(controller, DateTime.utc(2026, 5, 19, 12, 0));

    controller.notifyAppBackground();
    advanceClock(controller, defaultSessionTimeout + const Duration(seconds: 1));
    await controller.expireFromInactivity();

    final AppSessionState state = container.read(appSessionProvider);
    expect(state.status, AppLockStatus.locked);
    expect(state.lockReason, SessionLockReason.inactivity);
    expect(state.message, kStartupNeedsBiometricMessage);
  });

  test('敏感任務進行中背景逾時不鎖定', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);
    final Completer<void> holdSensitiveTask = Completer<void>();

    controller.activateSession(sampleSession);
    armControllerClock(controller, DateTime.utc(2026, 5, 19, 12, 0));

    unawaited(
      controller.runSensitiveTask((UnlockedVaultSession _) => holdSensitiveTask.future),
    );
    await Future<void>.delayed(Duration.zero);

    controller.notifyAppBackground();
    advanceClock(controller, defaultSessionTimeout + const Duration(seconds: 1));
    await controller.expireFromInactivity();

    expect(container.read(appSessionProvider).status, AppLockStatus.unlocked);
    holdSensitiveTask.complete();
  });

  test('背景未逾時時不鎖定', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    armControllerClock(controller, DateTime.utc(2026, 5, 19, 12, 0));

    controller.notifyAppBackground();
    advanceClock(controller, const Duration(minutes: 1));
    await controller.notifyAppForegroundResumed(onForegroundSettled: () {});

    expect(container.read(appSessionProvider).status, AppLockStatus.unlocked);
    expect(repository.openTrustedSessionCalls, 0);
  });

  test('使用者互動會取消背景逾時', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    final ProviderContainer container = buildContainer(repository);
    final AppSessionController controller = container.read(appSessionProvider.notifier);

    controller.activateSession(sampleSession);
    armControllerClock(controller, DateTime.utc(2026, 5, 19, 12, 0));

    controller.notifyAppBackground();
    controller.notifyUserInteraction();
    advanceClock(controller, defaultSessionTimeout + const Duration(seconds: 1));
    await controller.notifyAppForegroundResumed(onForegroundSettled: () {});
    await Future<void>.delayed(Duration.zero);

    expect(container.read(appSessionProvider).status, AppLockStatus.unlocked);
  });

  test('個人化 1 分鐘逾時設定會套用至背景鎖定', () async {
    final FakeSessionVaultRepository repository = FakeSessionVaultRepository(
      openTrustedSessionResult: sampleSession,
    );
    final FakeAppLockService appLock = FakeAppLockService(
      unlockMode: AppUnlockMode.deviceLock,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        vaultRepositoryProvider.overrideWithValue(repository),
        appLockServiceProvider.overrideWithValue(appLock),
        personalizationPreferencesProvider.overrideWith(
          _OneMinuteSessionTimeoutController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final AppSessionController controller = container.read(appSessionProvider.notifier);
    await container.read(personalizationPreferencesProvider.future);

    controller.activateSession(sampleSession);
    armControllerClock(controller, DateTime.utc(2026, 5, 19, 12, 0));

    controller.notifyAppBackground();
    advanceClock(controller, const Duration(minutes: 1, seconds: 1));
    await controller.expireFromInactivity();

    final AppSessionState state = container.read(appSessionProvider);
    expect(state.status, AppLockStatus.locked);
    expect(state.lockReason, SessionLockReason.inactivity);
  });
}

class _OneMinuteSessionTimeoutController extends PersonalizationPreferencesController {
  @override
  Future<PersonalizationPreferences> build() async {
    return PersonalizationPreferences.defaults.copyWith(
      sessionTimeoutMinutes: SessionBackgroundTimeoutMinutes.one,
    );
  }
}
