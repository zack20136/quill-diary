class EncryptionResult {
  const EncryptionResult({
    required this.headerBytes,
    required this.ciphertextBytes,
  });

  final List<int> headerBytes;
  final List<int> ciphertextBytes;
}

abstract class CryptoService {
  Future<EncryptionResult> encryptMarkdown({
    required String documentId,
    required String vaultId,
    required String markdown,
  });

  Future<String> decryptMarkdown({
    required List<int> headerBytes,
    required List<int> ciphertextBytes,
  });
}
