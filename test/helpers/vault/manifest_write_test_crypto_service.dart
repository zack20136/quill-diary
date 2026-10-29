import 'dart:async';

import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';

class ManifestWriteTestCryptoService extends LocalCryptoService {
  bool failManifestWrites = false;
  Completer<void>? manifestWriteStarted;
  Future<void>? manifestWriteGate;

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
  }) async {
    if (documentId == 'manifest') {
      if (failManifestWrites) throw StateError('manifest 寫入失敗');
      final gate = manifestWriteGate;
      if (gate != null) {
        if (manifestWriteStarted?.isCompleted == false) {
          manifestWriteStarted!.complete();
        }
        await gate;
      }
    }
    return super.encryptBytes(
      documentId: documentId,
      vaultId: vaultId,
      plaintextBytes: plaintextBytes,
      contentType: contentType,
      recoveryWrapKey: recoveryWrapKey,
      recoverySlotKdf: recoverySlotKdf,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
