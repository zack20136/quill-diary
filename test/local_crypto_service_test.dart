import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_lock_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_lock_diary/infrastructure/security/device_key_manager.dart';

class _FakeDeviceKeyManager implements DeviceKeyManager {
  _FakeDeviceKeyManager()
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
  Future<TrustedDeviceInfo> ensureDeviceKey(String vaultId) async {
    return TrustedDeviceInfo(
      slotId: 'dev_android_keystore_$vaultId',
      platform: 'android_keystore_test',
    );
  }

  @override
  Future<bool> hasTrustedKey(String vaultId) async {
    return _wrappedRecoveryRecords.containsKey(vaultId);
  }

  @override
  Future<TrustedDeviceInfo?> readDeviceInfo(String vaultId) async {
    return ensureDeviceKey(vaultId);
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
    if (slotId != 'dev_android_keystore_$vaultId') {
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
  }) async {
    final SecretBox box = await _cipher.encrypt(
      plaintextBytes,
      secretKey: SecretKey(_keyBytes),
    );
    return DeviceWrappedPayload(
      slotId: 'dev_android_keystore_$vaultId',
      nonceBase64: base64Encode(box.nonce),
      ciphertextBase64: base64Encode(<int>[...box.cipherText, ...box.mac.bytes]),
      platform: 'android_keystore_test',
    );
  }
}

void main() {
  late _FakeDeviceKeyManager deviceKeyManager;
  late LocalCryptoService crypto;

  setUp(() {
    deviceKeyManager = _FakeDeviceKeyManager();
    crypto = LocalCryptoService(deviceKeyManager: deviceKeyManager);
  });

  test('可用 Recovery Key 加解密 markdown，並寫入 recovery slot KDF', () async {
    const String recoveryKey = 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX';
    const String vaultId = 'vlt_TEST01';
    final KdfDescriptor kdf = KdfDescriptor.argon2idRecovery(
      saltBytes: List<int>.filled(16, 7),
    );
    final List<int> wrapKey = await crypto.deriveRecoveryWrapKey(
      recoveryKey: recoveryKey,
      kdf: kdf,
    );

    final EncryptionResult result = await crypto.encryptMarkdown(
      documentId: 'jrn_TEST01',
      vaultId: vaultId,
      markdown: '# Hello\n\nEncrypted world.',
      recoveryWrapKey: wrapKey,
      recoverySlotKdf: kdf,
      createdAt: DateTime.parse('2026-05-13T20:30:12Z'),
      updatedAt: DateTime.parse('2026-05-13T20:30:12Z'),
    );

    final ParsedEncryptedDocument parsed = crypto.parseFileBytes(result.toFileBytes());
    final String markdown = await crypto.decryptMarkdown(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      context: DecryptionContext.recovery(
        recoveryWrapKey: wrapKey,
        vaultId: vaultId,
      ),
    );

    expect(parsed.header.fileId, 'jrn_TEST01');
    expect(parsed.header.vaultId, vaultId);
    expect(markdown, '# Hello\n\nEncrypted world.');
    expect(
      parsed.header.keySlots
          .singleWhere((EncryptionKeySlot slot) => slot.slotType == 'recovery')
          .kdf
          ?.name,
      KdfDescriptor.kAlgorithmName,
    );
  });

  test('錯誤的 Recovery Key 無法解開 manifest', () async {
    const String vaultId = 'vlt_TEST01';
    final KdfDescriptor kdf = KdfDescriptor.argon2idRecovery(
      saltBytes: List<int>.filled(16, 9),
    );
    final List<int> goodWrapKey = await crypto.deriveRecoveryWrapKey(
      recoveryKey: 'GOOD-KEY1-GOOD-KEY2-GOOD-KEY3',
      kdf: kdf,
    );
    final List<int> badWrapKey = await crypto.deriveRecoveryWrapKey(
      recoveryKey: 'BADD-KEY1-BADD-KEY2-BADD-KEY3',
      kdf: kdf,
    );

    final EncryptionResult result = await crypto.encryptBytes(
      documentId: 'manifest',
      vaultId: vaultId,
      plaintextBytes: utf8.encode('{"ok":true}'),
      contentType: 'application/json',
      recoveryWrapKey: goodWrapKey,
      recoverySlotKdf: kdf,
      createdAt: DateTime.parse('2026-05-13T20:30:12Z'),
      updatedAt: DateTime.parse('2026-05-13T20:30:12Z'),
    );
    final ParsedEncryptedDocument parsed = crypto.parseFileBytes(result.toFileBytes());

    expect(
      () => crypto.decryptBytes(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: DecryptionContext.recovery(
          recoveryWrapKey: badWrapKey,
          vaultId: vaultId,
        ),
      ),
      throwsA(isA<Object>()),
    );
  });

  test('device slot 可成功 round-trip 解密', () async {
    const String vaultId = 'vlt_TEST01';
    final KdfDescriptor kdf = KdfDescriptor.argon2idRecovery(
      saltBytes: List<int>.filled(16, 3),
    );
    final List<int> wrapKey = await crypto.deriveRecoveryWrapKey(
      recoveryKey: 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX',
      kdf: kdf,
    );
    final EncryptionResult result = await crypto.encryptMarkdown(
      documentId: 'jrn_TEST01',
      vaultId: vaultId,
      markdown: 'device slot test',
      recoveryWrapKey: wrapKey,
      recoverySlotKdf: kdf,
      createdAt: DateTime.parse('2026-05-13T20:30:12Z'),
      updatedAt: DateTime.parse('2026-05-13T20:30:12Z'),
    );
    final ParsedEncryptedDocument parsed = crypto.parseFileBytes(result.toFileBytes());

    final String markdown = await crypto.decryptMarkdown(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      context: DecryptionContext(
        vaultId: vaultId,
        trustedDevice: true,
        deviceSlotId: 'dev_android_keystore_$vaultId',
      ),
    );
    expect(markdown, 'device slot test');

    expect(
      () => crypto.decryptMarkdown(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: const DecryptionContext(
          vaultId: vaultId,
          trustedDevice: true,
          deviceSlotId: 'dev_android_keystore_missing',
        ),
      ),
      throwsA(isA<Object>()),
    );
  });

  test('變更 canonical header 會導致解密失敗', () async {
    const String vaultId = 'vlt_TEST01';
    final KdfDescriptor kdf = KdfDescriptor.argon2idRecovery(
      saltBytes: List<int>.filled(16, 5),
    );
    final List<int> wrapKey = await crypto.deriveRecoveryWrapKey(
      recoveryKey: 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX',
      kdf: kdf,
    );
    final EncryptionResult result = await crypto.encryptMarkdown(
      documentId: 'jrn_TEST01',
      vaultId: vaultId,
      markdown: 'header tamper test',
      recoveryWrapKey: wrapKey,
      recoverySlotKdf: kdf,
      createdAt: DateTime.parse('2026-05-13T20:30:12Z'),
      updatedAt: DateTime.parse('2026-05-13T20:30:12Z'),
    );
    final ParsedEncryptedDocument parsed = crypto.parseFileBytes(result.toFileBytes());
    final Map<String, Object?> headerJson =
        jsonDecode(utf8.decode(parsed.headerBytes)) as Map<String, Object?>;
    headerJson['updated_at'] = '2030-01-01T00:00:00.000Z';
    final List<int> tamperedHeaderBytes = utf8.encode(jsonEncode(headerJson));

    expect(
      () => crypto.decryptMarkdown(
        headerBytes: tamperedHeaderBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: DecryptionContext.recovery(
          recoveryWrapKey: wrapKey,
          vaultId: vaultId,
        ),
      ),
      throwsA(isA<Object>()),
    );
  });
}
