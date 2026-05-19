import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_lock_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_lock_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_lock_diary/features/session/providers/session_providers.dart';
import 'package:quill_lock_diary/features/session/session_messages.dart';
import 'package:quill_lock_diary/features/session/state/app_session_state.dart';
import 'package:quill_lock_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_lock_diary/shared/providers/core_providers.dart';

import '../helpers/fake_app_lock_service.dart';
import '../helpers/fake_vault_repository.dart';

void main() {
  final RecoveryMetadata metadata = RecoveryMetadata(
    vaultId: 'vlt_test_startup',
    recoveryEnabled: true,
    recoveryKeyVersion: 2,
    recoveryKeyHint: 'UVWX',
    createdAt: DateTime.parse('2026-05-19T00:00:00Z'),
    kdf: KdfDescriptor.argon2idRecovery(
      saltBytes: Uint8List.fromList(List<int>.filled(16, 7)),
    ),
  );

  final UnlockedVaultSession sampleSession = UnlockedVaultSession(
    vaultId: metadata.vaultId,
    trustedDevice: true,
    recoveryWrapKey: List<int>.filled(32, 3),
    deviceSlotId: 'dev_android_keystore_plain_${metadata.vaultId}',
  );

  ProviderContainer buildContainer({
    required bool supportedPlatform,
    required FakeVaultRepository repository,
    FakeAppLockService? appLock,
  }) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        supportedPlatformProvider.overrideWithValue(supportedPlatform),
        vaultRepositoryProvider.overrideWithValue(repository),
        appLockServiceProvider.overrideWithValue(
          appLock ?? FakeAppLockService(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('非 Android 平台回傳 fatalError', () async {
    final FakeVaultRepository repository = FakeVaultRepository();
    final ProviderContainer container = buildContainer(
      supportedPlatform: false,
      repository: repository,
    );

    final AppSessionState state = await container.read(appStartupProvider.future);
    expect(state.status, AppLockStatus.fatalError);
    expect(state.message, kAndroidOnlyMessage);
  });

  test('尚未建立 Recovery Key 時進入 unlocked', () async {
    final FakeVaultRepository repository = FakeVaultRepository(metadata: null);
    final ProviderContainer container = buildContainer(
      supportedPlatform: true,
      repository: repository,
    );

    final AppSessionState state = await container.read(appStartupProvider.future);
    expect(state.status, AppLockStatus.unlocked);
    expect(state.message, kStartupNeedsRecoveryKeyMessage);
  });

  test('有 metadata 但無 trusted device 時進入 recoveryRequired', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      metadata: metadata,
      hasTrustedDevice: false,
    );
    final ProviderContainer container = buildContainer(
      supportedPlatform: true,
      repository: repository,
    );

    final AppSessionState state = await container.read(appStartupProvider.future);
    expect(state.status, AppLockStatus.recoveryRequired);
    expect(state.message, kStartupNeedsTrustedDeviceMessage);
  });

  test('trusted session 還原成功時進入 unlocked', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      metadata: metadata,
      hasTrustedDevice: true,
      openTrustedSessionResult: sampleSession,
    );
    final ProviderContainer container = buildContainer(
      supportedPlatform: true,
      repository: repository,
    );

    final AppSessionState state = await container.read(appStartupProvider.future);
    expect(state.status, AppLockStatus.unlocked);
    expect(state.session?.vaultId, metadata.vaultId);
  });

  test('啟動遇到 legacy trusted state 時會進入 recoveryRequired 並清掉 trusted state', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      metadata: metadata,
      hasTrustedDevice: true,
      openTrustedSessionResult: const DeviceKeyLegacyStateException('legacy slot'),
    );
    final ProviderContainer container = buildContainer(
      supportedPlatform: true,
      repository: repository,
    );

    final AppSessionState state = await container.read(appStartupProvider.future);
    expect(state.status, AppLockStatus.recoveryRequired);
    expect(state.message, 'legacy slot');
    expect(repository.clearTrustedDeviceAccessCalls, 1);
  });

  test('啟動遇到 invalidated trusted state 時會進入 recoveryRequired 並清掉 trusted state', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      metadata: metadata,
      hasTrustedDevice: true,
      openTrustedSessionResult: const DeviceKeyInvalidatedException('invalid key'),
    );
    final ProviderContainer container = buildContainer(
      supportedPlatform: true,
      repository: repository,
    );

    final AppSessionState state = await container.read(appStartupProvider.future);
    expect(state.status, AppLockStatus.recoveryRequired);
    expect(state.message, 'invalid key');
    expect(repository.clearTrustedDeviceAccessCalls, 1);
  });

  test('啟動遇到使用者取消驗證時維持 locked，不清 trusted state', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      metadata: metadata,
      hasTrustedDevice: true,
      openTrustedSessionResult: const DeviceKeyUserCancelledException(),
    );
    final ProviderContainer container = buildContainer(
      supportedPlatform: true,
      repository: repository,
      appLock: FakeAppLockService(biometricEnabled: true),
    );

    final AppSessionState state = await container.read(appStartupProvider.future);
    expect(state.status, AppLockStatus.locked);
    expect(repository.clearTrustedDeviceAccessCalls, 0);
  });

  test('生物驗證失敗時維持 locked', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      metadata: metadata,
      hasTrustedDevice: true,
      openTrustedSessionResult: const DeviceKeyAuthFailedException('bio failed'),
    );
    final ProviderContainer container = buildContainer(
      supportedPlatform: true,
      repository: repository,
      appLock: FakeAppLockService(biometricEnabled: true),
    );

    final AppSessionState state = await container.read(appStartupProvider.future);
    expect(state.status, AppLockStatus.locked);
    expect(state.message, 'bio failed');
    expect(repository.clearTrustedDeviceAccessCalls, 0);
  });

  test('trusted 資料不一致時進入 recoveryRequired 並清除', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      metadata: metadata,
      hasTrustedDevice: true,
      openTrustedSessionResult: StateError('受信任裝置資料不一致'),
    );
    final ProviderContainer container = buildContainer(
      supportedPlatform: true,
      repository: repository,
    );

    final AppSessionState state = await container.read(appStartupProvider.future);
    expect(state.status, AppLockStatus.recoveryRequired);
    expect(repository.clearTrustedDeviceAccessCalls, 1);
  });

  test('initialize 失敗時回傳 fatalError', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      metadata: metadata,
      initializeError: Exception('disk failure'),
    );
    final ProviderContainer container = buildContainer(
      supportedPlatform: true,
      repository: repository,
    );

    final AppSessionState state = await container.read(appStartupProvider.future);
    expect(state.status, AppLockStatus.fatalError);
    expect(state.message, contains('disk failure'));
  });

  test('openTrustedSession 非預期錯誤時回傳 fatalError', () async {
    final FakeVaultRepository repository = FakeVaultRepository(
      metadata: metadata,
      hasTrustedDevice: true,
      openTrustedSessionResult: Exception('unexpected keystore'),
    );
    final ProviderContainer container = buildContainer(
      supportedPlatform: true,
      repository: repository,
    );

    final AppSessionState state = await container.read(appStartupProvider.future);
    expect(state.status, AppLockStatus.fatalError);
    expect(state.message, contains('unexpected keystore'));
  });
}
