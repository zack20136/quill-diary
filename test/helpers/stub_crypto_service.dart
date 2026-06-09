import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';

class StubCryptoService implements CryptoService {
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
