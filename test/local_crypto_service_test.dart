import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/infrastructure/crypto/crypto_service.dart';

void main() {
  test('local crypto service encrypts and decrypts markdown', () async {
    final LocalCryptoService crypto = LocalCryptoService();
    const String recoveryKey = 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX';
    final List<int> wrapKey = await crypto.deriveRecoveryWrapKey(
      recoveryKey: recoveryKey,
      saltBytes: List<int>.filled(16, 7),
    );

    final EncryptionResult result = await crypto.encryptMarkdown(
      documentId: 'jrn_TEST01',
      vaultId: 'vlt_TEST01',
      markdown: '# Hello\n\nEncrypted world.',
      recoveryWrapKey: wrapKey,
      deviceSecret: 'device-secret',
      createdAt: DateTime.parse('2026-05-13T20:30:12Z'),
      updatedAt: DateTime.parse('2026-05-13T20:30:12Z'),
    );

    final ParsedEncryptedDocument parsed =
        crypto.parseFileBytes(result.toFileBytes());
    final String markdown = await crypto.decryptMarkdown(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      deviceSecret: 'device-secret',
      recoveryWrapKey: wrapKey,
    );

    expect(parsed.header.fileId, 'jrn_TEST01');
    expect(parsed.header.vaultId, 'vlt_TEST01');
    expect(markdown, '# Hello\n\nEncrypted world.');
  });
}
