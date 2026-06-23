import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:quill_diary/infrastructure/security/device_key_manager.dart';
import 'package:quill_diary/infrastructure/security/keystore_unlock_policy.dart';

/// Device-key fake for crypto unit tests.
class TestDeviceKeyManager implements DeviceKeyManager {
  TestDeviceKeyManager()
    : _cipher = AesGcm.with256bits(),
      _keyBytes = List<int>.generate(32, (int index) => index + 1);

  final Cipher _cipher;
  final List<int> _keyBytes;
  final Map<String, WrappedRecoveryKeyRecord> _wrappedRecoveryRecords =
      <String, WrappedRecoveryKeyRecord>{};

  @override
  Future<void> clearTrustedKey(String vaultId) async {
    _wrappedRecoveryRecords.remove(vaultId);
  }

  @override
  Future<TrustedDeviceInfo> ensureDeviceKey(
    String vaultId, {
    required KeystoreAuthKind authKind,
  }) async {
    return TrustedDeviceInfo(
      slotId: 'dev_android_keystore_${authKind.storageSuffix}_$vaultId',
      platform: 'android_keystore_test',
    );
  }

  @override
  Future<bool> hasTrustedKey(String vaultId) async {
    return _wrappedRecoveryRecords.containsKey(vaultId);
  }

  @override
  Future<TrustedDeviceInfo?> readDeviceInfo(String vaultId) async {
    return ensureDeviceKey(
      vaultId,
      authKind: KeystoreAuthKind.deviceCredential,
    );
  }

  @override
  Future<WrappedRecoveryKeyRecord?> readWrappedRecoveryKey(
    String vaultId,
  ) async {
    return _wrappedRecoveryRecords[vaultId];
  }

  @override
  Future<void> storeWrappedRecoveryKey({
    required String vaultId,
    required WrappedRecoveryKeyRecord record,
  }) async {
    _wrappedRecoveryRecords[vaultId] = record;
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
    return _cipher.decrypt(box, secretKey: SecretKey(_keyBytes));
  }

  @override
  Future<DeviceWrappedPayload> wrapWithDeviceKey({
    required String vaultId,
    required List<int> plaintextBytes,
    required KeystoreAuthKind authKind,
  }) async {
    final SecretBox box = await _cipher.encrypt(
      plaintextBytes,
      secretKey: SecretKey(_keyBytes),
    );
    return DeviceWrappedPayload(
      slotId: 'dev_android_keystore_${authKind.storageSuffix}_$vaultId',
      nonceBase64: base64Encode(box.nonce),
      ciphertextBase64: base64Encode(<int>[
        ...box.cipherText,
        ...box.mac.bytes,
      ]),
      platform: 'android_keystore_test',
    );
  }

  @override
  Future<RewrapTrustedRecoveryKeyResult> rewrapTrustedRecoveryKey({
    required String vaultId,
    required String sourceSlotId,
    required String nonceBase64,
    required String ciphertextBase64,
    required KeystoreAuthKind targetAuthKind,
  }) async {
    final List<int> recoveryWrapKey = await unwrapWithDeviceKey(
      vaultId: vaultId,
      slotId: sourceSlotId,
      nonceBase64: nonceBase64,
      ciphertextBase64: ciphertextBase64,
    );
    final DeviceWrappedPayload payload = await wrapWithDeviceKey(
      vaultId: vaultId,
      plaintextBytes: recoveryWrapKey,
      authKind: targetAuthKind,
    );
    return RewrapTrustedRecoveryKeyResult(
      recoveryWrapKey: recoveryWrapKey,
      payload: payload,
    );
  }

  @override
  Future<void> purgeInactiveDeviceKeys(
    String vaultId, {
    required KeystoreAuthKind activeAuthKind,
  }) async {}
}

/// Records keystore auth kind usage for vault integration tests.
class RecordingDeviceKeyManager implements DeviceKeyManager {
  RecordingDeviceKeyManager()
    : _cipher = AesGcm.with256bits(),
      _secureKey = List<int>.generate(32, (int index) => 255 - index);

  final Cipher _cipher;
  final List<int> _secureKey;
  final Map<String, WrappedRecoveryKeyRecord> _wrappedRecords =
      <String, WrappedRecoveryKeyRecord>{};
  final Map<String, TrustedDeviceInfo> _deviceInfos =
      <String, TrustedDeviceInfo>{};

  KeystoreAuthKind? lastEnsureAuthKind;
  KeystoreAuthKind? lastWrapAuthKind;
  KeystoreAuthKind? lastPurgeAuthKind;
  KeystoreAuthKind? lastRewrapTargetAuthKind;
  int purgeInactiveDeviceKeysCalls = 0;
  int unwrapWithDeviceKeyCalls = 0;
  int wrapWithDeviceKeyCalls = 0;
  int rewrapTrustedRecoveryKeyCalls = 0;

  /// 測試用：直接寫入受信任裝置資料。
  void seedTrustedDevice({
    required String vaultId,
    required WrappedRecoveryKeyRecord record,
    required TrustedDeviceInfo deviceInfo,
  }) {
    _wrappedRecords[vaultId] = record;
    _deviceInfos[vaultId] = deviceInfo;
  }

  @override
  Future<void> clearTrustedKey(String vaultId) async {
    _wrappedRecords.remove(vaultId);
    _deviceInfos.remove(vaultId);
  }

  @override
  Future<TrustedDeviceInfo> ensureDeviceKey(
    String vaultId, {
    required KeystoreAuthKind authKind,
  }) async {
    lastEnsureAuthKind = authKind;
    final TrustedDeviceInfo info = TrustedDeviceInfo(
      slotId: _slotId(vaultId, authKind),
      platform: 'android_keystore_test',
    );
    _deviceInfos[vaultId] = info;
    return info;
  }

  @override
  Future<bool> hasTrustedKey(String vaultId) async {
    return _wrappedRecords.containsKey(vaultId) &&
        _deviceInfos.containsKey(vaultId);
  }

  @override
  Future<TrustedDeviceInfo?> readDeviceInfo(String vaultId) async =>
      _deviceInfos[vaultId];

  @override
  Future<WrappedRecoveryKeyRecord?> readWrappedRecoveryKey(
    String vaultId,
  ) async {
    return _wrappedRecords[vaultId];
  }

  @override
  Future<void> storeWrappedRecoveryKey({
    required String vaultId,
    required WrappedRecoveryKeyRecord record,
  }) async {
    _wrappedRecords[vaultId] = record;
    _deviceInfos[vaultId] = TrustedDeviceInfo(
      slotId: record.slotId,
      platform: record.platform,
    );
  }

  @override
  Future<List<int>> unwrapWithDeviceKey({
    required String vaultId,
    required String slotId,
    required String nonceBase64,
    required String ciphertextBase64,
  }) async {
    unwrapWithDeviceKeyCalls++;
    final List<int> encryptedBytes = base64Decode(ciphertextBase64);
    final SecretBox box = SecretBox(
      encryptedBytes.sublist(0, encryptedBytes.length - 16),
      nonce: base64Decode(nonceBase64),
      mac: Mac(encryptedBytes.sublist(encryptedBytes.length - 16)),
    );
    return _cipher.decrypt(box, secretKey: SecretKey(_secretKeyBytes(slotId)));
  }

  @override
  Future<RewrapTrustedRecoveryKeyResult> rewrapTrustedRecoveryKey({
    required String vaultId,
    required String sourceSlotId,
    required String nonceBase64,
    required String ciphertextBase64,
    required KeystoreAuthKind targetAuthKind,
  }) async {
    rewrapTrustedRecoveryKeyCalls++;
    lastRewrapTargetAuthKind = targetAuthKind;
    final List<int> encryptedBytes = base64Decode(ciphertextBase64);
    final SecretBox box = SecretBox(
      encryptedBytes.sublist(0, encryptedBytes.length - 16),
      nonce: base64Decode(nonceBase64),
      mac: Mac(encryptedBytes.sublist(encryptedBytes.length - 16)),
    );
    final List<int> recoveryWrapKey = await _cipher.decrypt(
      box,
      secretKey: SecretKey(_secretKeyBytes(sourceSlotId)),
    );
    final DeviceWrappedPayload payload = await wrapWithDeviceKey(
      vaultId: vaultId,
      plaintextBytes: recoveryWrapKey,
      authKind: targetAuthKind,
    );
    return RewrapTrustedRecoveryKeyResult(
      recoveryWrapKey: recoveryWrapKey,
      payload: payload,
    );
  }

  @override
  Future<DeviceWrappedPayload> wrapWithDeviceKey({
    required String vaultId,
    required List<int> plaintextBytes,
    required KeystoreAuthKind authKind,
  }) async {
    if (plaintextBytes.length == 32) {
      wrapWithDeviceKeyCalls++;
      lastWrapAuthKind = authKind;
    }
    final SecretBox box = await _cipher.encrypt(
      plaintextBytes,
      secretKey: SecretKey(_secureKey),
    );
    return DeviceWrappedPayload(
      slotId: _slotId(vaultId, authKind),
      nonceBase64: base64Encode(box.nonce),
      ciphertextBase64: base64Encode(<int>[
        ...box.cipherText,
        ...box.mac.bytes,
      ]),
      platform: 'android_keystore_test',
    );
  }

  String _slotId(String vaultId, KeystoreAuthKind authKind) {
    return 'dev_android_keystore_${authKind.storageSuffix}_$vaultId';
  }

  List<int> _secretKeyBytes(String slotId) {
    return _secureKey;
  }

  @override
  Future<void> purgeInactiveDeviceKeys(
    String vaultId, {
    required KeystoreAuthKind activeAuthKind,
  }) async {
    purgeInactiveDeviceKeysCalls++;
    lastPurgeAuthKind = activeAuthKind;
  }
}

/// 於 [wrapWithDeviceKey] 時拋出取消，供解鎖方式切換測試使用。
class CancellingDeviceKeyManager extends RecordingDeviceKeyManager {
  bool cancelWrap = false;

  @override
  Future<DeviceWrappedPayload> wrapWithDeviceKey({
    required String vaultId,
    required List<int> plaintextBytes,
    required KeystoreAuthKind authKind,
  }) async {
    if (cancelWrap && plaintextBytes.length == 32) {
      throw const DeviceKeyUserCancelledException();
    }
    return super.wrapWithDeviceKey(
      vaultId: vaultId,
      plaintextBytes: plaintextBytes,
      authKind: authKind,
    );
  }
}
