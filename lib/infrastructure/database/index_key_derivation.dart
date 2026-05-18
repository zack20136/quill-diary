import 'dart:convert';

import 'package:cryptography/cryptography.dart';

Future<List<int>> deriveIndexDatabaseKey({
  required List<int> recoveryWrapKey,
  required String vaultId,
}) async {
  final Hkdf hkdf = Hkdf(
    hmac: Hmac.sha256(),
    outputLength: 32,
  );
  final SecretKey secretKey = await hkdf.deriveKey(
    secretKey: SecretKey(recoveryWrapKey),
    nonce: utf8.encode(vaultId),
    info: utf8.encode('quill_lock_diary:index:v1'),
  );
  return secretKey.extractBytes();
}

