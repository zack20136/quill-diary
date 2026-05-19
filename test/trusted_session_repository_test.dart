import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_lock_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_lock_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_lock_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_lock_diary/infrastructure/database/index_database_manager.dart';
import 'package:quill_lock_diary/infrastructure/markdown/front_matter_codec.dart';
import 'package:quill_lock_diary/infrastructure/security/app_lock_service.dart';
import 'package:quill_lock_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_lock_diary/infrastructure/storage/vault_repository.dart';

class _TestVaultPathStrategy extends VaultPathStrategy {
  _TestVaultPathStrategy(this.root);

  final Directory root;

  @override
  Future<Directory> appRootDirectory() async => root;

  @override
  Future<Directory> vaultRootDirectory() async => Directory(p.join(root.path, 'vault'));

  @override
  Future<Directory> indexRootDirectory() async => Directory(p.join(root.path, 'index'));
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

class _RecordingDeviceKeyManager implements DeviceKeyManager {
  _RecordingDeviceKeyManager()
      : _cipher = AesGcm.with256bits(),
        _plainKey = List<int>.generate(32, (int index) => index + 1),
        _authKey = List<int>.generate(32, (int index) => 255 - index);

  final Cipher _cipher;
  final List<int> _plainKey;
  final List<int> _authKey;
  final Map<String, WrappedRecoveryKeyRecord> _wrappedRecords =
      <String, WrappedRecoveryKeyRecord>{};
  final Map<String, TrustedDeviceInfo> _deviceInfos = <String, TrustedDeviceInfo>{};

  bool? lastEnsureAuthRequired;
  bool? lastWrapAuthRequired;

  @override
  Future<void> clearTrustedKey(String vaultId) async {
    _wrappedRecords.remove(vaultId);
    _deviceInfos.remove(vaultId);
  }

  @override
  Future<TrustedDeviceInfo> ensureDeviceKey(
    String vaultId, {
    required bool userAuthenticationRequired,
  }) async {
    lastEnsureAuthRequired = userAuthenticationRequired;
    final TrustedDeviceInfo info = TrustedDeviceInfo(
      slotId: _slotId(vaultId, userAuthenticationRequired),
      platform: 'android_keystore_test',
    );
    _deviceInfos[vaultId] = info;
    return info;
  }

  @override
  Future<bool> hasTrustedKey(String vaultId) async {
    return _wrappedRecords.containsKey(vaultId) && _deviceInfos.containsKey(vaultId);
  }

  @override
  Future<TrustedDeviceInfo?> readDeviceInfo(String vaultId) async => _deviceInfos[vaultId];

  @override
  Future<WrappedRecoveryKeyRecord?> readWrappedRecoveryKey(String vaultId) async {
    return _wrappedRecords[vaultId];
  }

  @override
  Future<void> storeWrappedRecoveryKey({
    required String vaultId,
    required WrappedRecoveryKeyRecord record,
  }) async {
    _wrappedRecords[vaultId] = record;
  }

  @override
  Future<List<int>> unwrapWithDeviceKey({
    required String vaultId,
    required String slotId,
    required String nonceBase64,
    required String ciphertextBase64,
  }) async {
    final List<int> encryptedBytes = base64Decode(ciphertextBase64);
    final SecretBox box = SecretBox(
      encryptedBytes.sublist(0, encryptedBytes.length - 16),
      nonce: base64Decode(nonceBase64),
      mac: Mac(encryptedBytes.sublist(encryptedBytes.length - 16)),
    );
    return _cipher.decrypt(
      box,
      secretKey: SecretKey(_secretKeyBytes(slotId)),
    );
  }

  @override
  Future<DeviceWrappedPayload> wrapWithDeviceKey({
    required String vaultId,
    required List<int> plaintextBytes,
    required bool userAuthenticationRequired,
  }) async {
    if (plaintextBytes.length == 32) {
      lastWrapAuthRequired = userAuthenticationRequired;
    }
    final SecretBox box = await _cipher.encrypt(
      plaintextBytes,
      secretKey: SecretKey(
        userAuthenticationRequired ? _authKey : _plainKey,
      ),
    );
    return DeviceWrappedPayload(
      slotId: _slotId(vaultId, userAuthenticationRequired),
      nonceBase64: base64Encode(box.nonce),
      ciphertextBase64: base64Encode(<int>[...box.cipherText, ...box.mac.bytes]),
      platform: 'android_keystore_test',
    );
  }

  String _slotId(String vaultId, bool authRequired) {
    final String mode = authRequired ? 'auth' : 'plain';
    return 'dev_android_keystore_${mode}_$vaultId';
  }

  List<int> _secretKeyBytes(String slotId) {
    return slotId.contains('_auth_') ? _authKey : _plainKey;
  }
}

void main() {
  late Directory tempDir;
  late _TestVaultPathStrategy pathStrategy;
  late _RecordingDeviceKeyManager deviceKeyManager;
  late _FakeAppLockService appLockService;
  late VaultRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qld_trusted_repo_test_');
    pathStrategy = _TestVaultPathStrategy(tempDir);
    deviceKeyManager = _RecordingDeviceKeyManager();
    appLockService = _FakeAppLockService(biometricEnabled: false);
    repository = VaultRepository(
      pathStrategy: pathStrategy,
      frontMatterCodec: const FrontMatterCodec(),
      cryptoService: LocalCryptoService(deviceKeyManager: deviceKeyManager),
      indexDatabaseManager: IndexDatabaseManager(pathStrategy),
      deviceKeyManager: deviceKeyManager,
      appLockService: appLockService,
    );
    await repository.initialize();
  });

  tearDown(() async {
    await repository.closeUnlockedResources();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('未開啟生物驗證時，unlockWithRecoveryKey 會重建 plain trusted session', () async {
    final RecoverySetupResult setup = await repository.setupRecoveryKey();

    await repository.closeUnlockedResources();
    final UnlockedVaultSession session = await repository.unlockWithRecoveryKey(
      setup.recoveryKey,
    );
    final WrappedRecoveryKeyRecord? record = await deviceKeyManager.readWrappedRecoveryKey(
      session.vaultId,
    );

    expect(deviceKeyManager.lastEnsureAuthRequired, isFalse);
    expect(deviceKeyManager.lastWrapAuthRequired, isFalse);
    expect(session.deviceSlotId, 'dev_android_keystore_plain_${session.vaultId}');
    expect(record?.slotId, 'dev_android_keystore_plain_${session.vaultId}');
    expect(record?.formatVersion, 2);
  });

  test('開啟生物驗證後，refreshTrustedSessionProtection 會切到 auth trusted session', () async {
    final RecoverySetupResult setup = await repository.setupRecoveryKey();
    appLockService.biometricEnabled = true;

    final UnlockedVaultSession refreshed = await repository.refreshTrustedSessionProtection(
      setup.session,
      biometricRequired: true,
    );
    final WrappedRecoveryKeyRecord? record = await deviceKeyManager.readWrappedRecoveryKey(
      refreshed.vaultId,
    );

    expect(deviceKeyManager.lastEnsureAuthRequired, isTrue);
    expect(deviceKeyManager.lastWrapAuthRequired, isTrue);
    expect(refreshed.deviceSlotId, 'dev_android_keystore_auth_${refreshed.vaultId}');
    expect(record?.slotId, 'dev_android_keystore_auth_${refreshed.vaultId}');
    expect(record?.formatVersion, 2);
  });
}
