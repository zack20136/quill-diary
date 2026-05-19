import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/infrastructure/database/index_key_derivation.dart';

void main() {
  test('deriveIndexDatabaseKey 對相同輸入穩定', () async {
    final List<int> recoveryWrapKey = List<int>.generate(32, (int index) => index + 11);

    final List<int> first = await deriveIndexDatabaseKey(
      recoveryWrapKey: recoveryWrapKey,
      vaultId: 'vlt_same',
    );
    final List<int> second = await deriveIndexDatabaseKey(
      recoveryWrapKey: recoveryWrapKey,
      vaultId: 'vlt_same',
    );

    expect(first, hasLength(32));
    expect(second, first);
  });

  test('deriveIndexDatabaseKey 符合 cryptography Hkdf 相同 salt/info 約定', () async {
    final List<int> recoveryWrapKey = List<int>.filled(32, 0xaa);
    const String vaultId = 'golden_vault';
    final Hkdf hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final SecretKey reference = await hkdf.deriveKey(
      secretKey: SecretKey(recoveryWrapKey),
      nonce: utf8.encode(vaultId),
      info: utf8.encode('quill_lock_diary:index:v1'),
    );
    final List<int> derived = await deriveIndexDatabaseKey(
      recoveryWrapKey: recoveryWrapKey,
      vaultId: vaultId,
    );

    expect(derived, await reference.extractBytes());
  });

  test('deriveIndexDatabaseKey 會隨 vaultId 改變', () async {
    final List<int> recoveryWrapKey = List<int>.generate(32, (int index) => index + 21);

    final List<int> first = await deriveIndexDatabaseKey(
      recoveryWrapKey: recoveryWrapKey,
      vaultId: 'vlt_one',
    );
    final List<int> second = await deriveIndexDatabaseKey(
      recoveryWrapKey: recoveryWrapKey,
      vaultId: 'vlt_two',
    );

    expect(second, isNot(first));
  });
}
