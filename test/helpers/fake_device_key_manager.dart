import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:quill_lock_diary/infrastructure/security/device_key_manager.dart';

/// Plain-only fake for crypto unit tests.
class PlainFakeDeviceKeyManager implements DeviceKeyManager {
  PlainFakeDeviceKeyManager()
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
    required bool userAuthenticationRequired,
  }) async {
    return TrustedDeviceInfo(
      slotId: 'dev_android_keystore_plain_$vaultId',
      platform: 'android_keystore_test',
    );
  }

  @override
  Future<bool> hasTrustedKey(String vaultId) async {
    return _wrappedRecoveryRecords.containsKey(vaultId);
  }

  @override
  Future<TrustedDeviceInfo?> readDeviceInfo(String vaultId) async {
    return ensureDeviceKey(vaultId, userAuthenticationRequired: false);
  }

  @override
  Future<WrappedRecoveryKeyRecord?> readWrappedRecoveryKey(String vaultId) async {
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
    if (slotId != 'dev_android_keystore_plain_$vaultId') {
      throw StateError('slot mismatch');
    }
    final List<int> encryptedBytes = base64Decode(ciphertextBase64);
    final SecretBox box = SecretBox(
      encryptedBytes.sublist(0, encryptedBytes.length - 16),
      nonce: base64Decode(nonceBase64),
      mac: Mac(encryptedBytes.sublist(encryptedBytes.length - 16)),
    );
    return _cipher.decrypt(
      box,
      secretKey: SecretKey(_keyBytes),
    );
  }

  @override
  Future<DeviceWrappedPayload> wrapWithDeviceKey({
    required String vaultId,
    required List<int> plaintextBytes,
    required bool userAuthenticationRequired,
  }) async {
    final SecretBox box = await _cipher.encrypt(
      plaintextBytes,
      secretKey: SecretKey(_keyBytes),
    );
    return DeviceWrappedPayload(
      slotId: 'dev_android_keystore_plain_$vaultId',
      nonceBase64: base64Encode(box.nonce),
      ciphertextBase64: base64Encode(<int>[...box.cipherText, ...box.mac.bytes]),
      platform: 'android_keystore_test',
    );
  }
}

/// Records plain vs auth slot usage for vault integration tests.
class RecordingDeviceKeyManager implements DeviceKeyManager {
  RecordingDeviceKeyManager()
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
