import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/unlock_mode_change_service.dart';
import 'package:quill_diary/infrastructure/security/unlock_mode_policy.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../helpers/vault_test_harness.dart';

void main() {
  late VaultTestHarness harness;

  setUp(() async {
    harness = await VaultTestHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('未解鎖時 precheck 失敗由 UI 層處理，service 需已解鎖 session', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    final UnlockModeChangeService service = UnlockModeChangeService(
      appLock: harness.appLockService,
      vaultRepository: harness.repository,
    );

    final UnlockModeChangeOutcome outcome = await service.apply(
      mode: AppUnlockMode.deviceLock,
      session: setup.session,
    );

    expect(outcome, isA<UnlockModeChangeSucceededWithSession>());
    expect(await harness.appLockService.getUnlockMode(), AppUnlockMode.deviceLock);
  });

  test('無螢幕鎖時無法 migrate 至 deviceLock', () async {
    final RecoverySetupResult setup = await harness.repository.setupRecoveryKey();
    harness.appLockService.canUseDeviceCredentialResult = false;
    final UnlockModeChangeService service = UnlockModeChangeService(
      appLock: harness.appLockService,
      vaultRepository: harness.repository,
    );

    final UnlockModeChangeOutcome outcome = await service.apply(
      mode: AppUnlockMode.deviceLock,
      session: setup.session,
    );

    expect(outcome, isA<UnlockModeChangeMessage>());
    expect(
      (outcome as UnlockModeChangeMessage).message,
      UnlockModeCapabilityFailure.requiresDeviceLock.message,
    );
    expect(await harness.appLockService.getUnlockMode(), AppUnlockMode.none);
  });
}
