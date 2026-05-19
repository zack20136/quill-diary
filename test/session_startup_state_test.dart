import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_lock_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_lock_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_lock_diary/features/session/providers/session_providers.dart';
import 'package:quill_lock_diary/features/session/state/app_session_state.dart';
import 'package:quill_lock_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_lock_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_lock_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_lock_diary/infrastructure/security/app_lock_service.dart';
import 'package:quill_lock_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_lock_diary/shared/providers/core_providers.dart';

class _StubCryptoService implements CryptoService {
  @override
  Future<List<int>> decryptBytes({
    required List<int> headerBytes,
    required List<int> ciphertextBytes,
    required DecryptionContext context,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> decryptMarkdown({
    required List<int> headerBytes,
    required List<int> ciphertextBytes,
    required DecryptionContext context,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<int>> deriveRecoveryWrapKey({
    required String recoveryKey,
    required KdfDescriptor kdf,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EncryptionResult> encryptBytes({
    required String documentId,
    required String vaultId,
    required List<int> plaintextBytes,
    required String contentType,
    required List<int> recoveryWrapKey,
    required KdfDescriptor recoverySlotKdf,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EncryptionResult> encryptMarkdown({
    required String documentId,
    required String vaultId,
    required String markdown,
    required List<int> recoveryWrapKey,
    required KdfDescriptor recoverySlotKdf,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    throw UnimplementedError();
  }

  @override
  ParsedEncryptedDocument parseFileBytes(List<int> fileBytes) {
    throw UnimplementedError();
  }
}

class _FakeAppLockService implements AppLockService {
  _FakeAppLockService({required this.biometricEnabled});

  bool biometricEnabled;

  @override
  Future<bool> isBiometricLockEnabled() async => biometricEnabled;

  @override
  Future<bool> isSessionLocked() async => false;

  @override
  Future<void> lock() async {}

  @override
  Future<void> setBiometricLockEnabled(bool enabled) async {
    biometricEnabled = enabled;
  }

  @override
  Future<bool> unlock() async => true;
}

class _DummyVaultPathStrategy extends VaultPathStrategy {
  @override
  Future<Directory> appRootDirectory() async {
    return Directory.systemTemp.createTempSync('qld_session_test_');
  }
}

class _FakeVaultRepository extends VaultRepository {
  _FakeVaultRepository({
    required this.metadata,
    required this.hasTrustedDevice,
    required this.openTrustedSessionResult,
  }) : super(
          pathStrategy: _DummyVaultPathStrategy(),
          frontMatterCodec: const FrontMatterCodec(),
          cryptoService: _StubCryptoService(),
          indexDatabaseManager: IndexDatabaseManager(_DummyVaultPathStrategy()),
          deviceKeyManager: const UnsupportedDeviceKeyManager(),
          appLockService: const UnsupportedAppLockService(),
        );

  final RecoveryMetadata? metadata;
  final bool hasTrustedDevice;
  final Object openTrustedSessionResult;

  int clearTrustedDeviceAccessCalls = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<RecoveryMetadata?> readRecoveryMetadata() async => metadata;

  @override
  Future<bool> hasTrustedDeviceAccess() async => hasTrustedDevice;

  @override
  Future<UnlockedVaultSession> openTrustedSession() async {
    final Object result = openTrustedSessionResult;
    if (result is UnlockedVaultSession) {
      return result;
    }
    throw result;
  }

  @override
  Future<void> ensureIndexReady(UnlockedVaultSession session) async {}

  @override
  Future<void> closeUnlockedResources() async {}

  @override
  Future<void> clearTrustedDeviceAccess() async {
    clearTrustedDeviceAccessCalls++;
  }
}

void main() {
  final RecoveryMetadata metadata = RecoveryMetadata(
    vaultId: 'vlt_test_legacy',
    recoveryEnabled: true,
    recoveryKeyVersion: 2,
    recoveryKeyHint: 'UVWX',
    createdAt: DateTime.parse('2026-05-19T00:00:00Z'),
    kdf: KdfDescriptor.argon2idRecovery(
      saltBytes: Uint8List.fromList(List<int>.filled(16, 7)),
    ),
  );

  test('啟動遇到 legacy trusted state 時會進入 recoveryRequired 並清掉 trusted state', () async {
    final _FakeVaultRepository repository = _FakeVaultRepository(
      metadata: metadata,
      hasTrustedDevice: true,
      openTrustedSessionResult: const DeviceKeyLegacyStateException('legacy slot'),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        supportedPlatformProvider.overrideWithValue(true),
        vaultRepositoryProvider.overrideWithValue(repository),
        appLockServiceProvider.overrideWithValue(
          _FakeAppLockService(biometricEnabled: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    final AppSessionState state = await container.read(appStartupProvider.future);

    expect(state.status, AppLockStatus.recoveryRequired);
    expect(state.message, 'legacy slot');
    expect(repository.clearTrustedDeviceAccessCalls, 1);
  });

  test('啟動遇到 invalidated trusted state 時會進入 recoveryRequired 並清掉 trusted state', () async {
    final _FakeVaultRepository repository = _FakeVaultRepository(
      metadata: metadata,
      hasTrustedDevice: true,
      openTrustedSessionResult: const DeviceKeyInvalidatedException('invalid key'),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        supportedPlatformProvider.overrideWithValue(true),
        vaultRepositoryProvider.overrideWithValue(repository),
        appLockServiceProvider.overrideWithValue(
          _FakeAppLockService(biometricEnabled: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    final AppSessionState state = await container.read(appStartupProvider.future);

    expect(state.status, AppLockStatus.recoveryRequired);
    expect(state.message, 'invalid key');
    expect(repository.clearTrustedDeviceAccessCalls, 1);
  });

  test('啟動遇到使用者取消驗證時維持 locked，不清 trusted state', () async {
    final _FakeVaultRepository repository = _FakeVaultRepository(
      metadata: metadata,
      hasTrustedDevice: true,
      openTrustedSessionResult: const DeviceKeyUserCancelledException(),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        supportedPlatformProvider.overrideWithValue(true),
        vaultRepositoryProvider.overrideWithValue(repository),
        appLockServiceProvider.overrideWithValue(
          _FakeAppLockService(biometricEnabled: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    final AppSessionState state = await container.read(appStartupProvider.future);

    expect(state.status, AppLockStatus.locked);
    expect(repository.clearTrustedDeviceAccessCalls, 0);
  });
}
