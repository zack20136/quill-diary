import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';

void main() {
  late LocalCryptoService crypto;

  setUp(() {
    crypto = LocalCryptoService();
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

  test('encryptBytes recovery slot 可 round-trip', () async {
    const String vaultId = 'vlt_TEST01';
    final KdfDescriptor kdf = KdfDescriptor.argon2idRecovery(
      saltBytes: List<int>.filled(16, 8),
    );
    final List<int> wrapKey = await crypto.deriveRecoveryWrapKey(
      recoveryKey: 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX',
      kdf: kdf,
    );
    final List<int> plaintext = utf8.encode('{"schema":1}');

    final EncryptionResult result = await crypto.encryptBytes(
      documentId: 'manifest',
      vaultId: vaultId,
      plaintextBytes: plaintext,
      contentType: 'application/json',
      recoveryWrapKey: wrapKey,
      recoverySlotKdf: kdf,
      createdAt: DateTime.parse('2026-05-13T20:30:12Z'),
      updatedAt: DateTime.parse('2026-05-13T20:30:12Z'),
    );
    final ParsedEncryptedDocument parsed = crypto.parseFileBytes(result.toFileBytes());
    final List<int> decrypted = await crypto.decryptBytes(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      context: DecryptionContext.recovery(
        recoveryWrapKey: wrapKey,
        vaultId: vaultId,
      ),
    );

    expect(decrypted, plaintext);
  });

  test('parseFileBytes 拒絕過短或錯誤 magic 的檔案', () {
    expect(
      () => crypto.parseFileBytes(<int>[1, 2, 3]),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => crypto.parseFileBytes(utf8.encode('NOTLDJ2FORMATXXXX')),
      throwsA(isA<FormatException>()),
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

  test('新加密檔只寫入 recovery slot，不產生 device slot', () async {
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

    expect(
      parsed.header.keySlots.where((EncryptionKeySlot slot) => slot.slotType == 'device'),
      isEmpty,
    );

    final String markdown = await crypto.decryptMarkdown(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      context: DecryptionContext.recovery(
        recoveryWrapKey: wrapKey,
        vaultId: vaultId,
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
