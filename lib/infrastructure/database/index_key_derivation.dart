import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../config/app_identifiers.dart';

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
    info: utf8.encode(AppIdentifiers.indexKeyDerivationInfo),
  );
  return secretKey.extractBytes();
}
