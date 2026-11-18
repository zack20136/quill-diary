import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_key.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';

void main() {
  for (final iterations in [2, 3]) {
    test('歷史 $iterations 次迭代的固定 KDF、LDJ2 與原始 ZIP 仍可解密', () async {
      final root = 'test/fixtures/security/iterations_$iterations';
      final fixture = jsonDecode(
        await File('$root.json').readAsString(),
      ) as Map<String, dynamic>;
      final metadata = RecoveryMetadata.fromJson(
        Map<String, Object?>.from(fixture['metadata'] as Map),
      );
      final crypto = LocalCryptoService();
      final wrap = await crypto.deriveRecoveryWrapKey(
        recoveryKey: fixture['recovery_key'] as String,
        kdf: metadata.kdf,
      );
      expect(base64Encode(wrap), fixture['derived_wrap_key_base64']);
      final original = await File('$root.ldj2').readAsBytes();
      final archive = ZipDecoder().decodeBytes(
        await File('$root.zip').readAsBytes(),
        verify: true,
      );
      expect(archive.findFile('manifest.json.enc')!.readBytes(), original);
      final parsed = crypto.parseFileBytes(original);
      final plaintext = await crypto.decryptBytes(
        headerBytes: parsed.headerBytes,
        ciphertextBytes: parsed.ciphertextBytes,
        context: DecryptionContext.recovery(
          recoveryWrapKey: wrap,
          vaultId: metadata.vaultId,
        ),
      );
      expect(utf8.decode(plaintext), fixture['plaintext']);
      expect(
        await crypto.deriveRecoveryWrapKey(
          recoveryKey: (fixture['recovery_key'] as String)
              .toLowerCase()
              .replaceAll('-', ' '),
          kdf: metadata.kdf,
        ),
        wrap,
      );
      for (final invalid in ['bad', true, 1.5, 999, null]) {
        expect(
          () => RecoveryMetadata.fromJson({
            ...Map<String, Object?>.from(fixture['metadata'] as Map),
            'schema_version': invalid,
          }),
          throwsFormatException,
        );
      }
    });
  }
  test('15 bytes 無損編碼且保留完整 120 bits', () {
    expect(
      RecoveryKey.encode(List.generate(15, (i) => i)),
      '000G-40R4-0M30-E209-185G-R38E',
    );
    expect(
      RecoveryKey.encode(List.filled(15, 0)),
      '0000-0000-0000-0000-0000-0000',
    );
    expect(
      RecoveryKey.encode(List.filled(15, 255)),
      'ZZZZ-ZZZZ-ZZZZ-ZZZZ-ZZZZ-ZZZZ',
    );
    final generated = RecoveryKey.generate();
    expect(RecoveryKey.normalize(generated), generated);
    expect(generated.split('-').map((part) => part.length), List.filled(6, 4));
    expect(() => RecoveryKey.encode(List.filled(14, 0)), throwsArgumentError);
  });
  test('KDF 拒絕資源濫用且接受歷史範圍', () {
    final base = KdfDescriptor.argon2idRecovery(saltBytes: List.filled(16, 7))
        .toJson();
    for (final entry in <String, List<Object>>{
      'memory': [0, 7, 32769],
      'iterations': [0, 7],
      'parallelism': [0, 2],
      'hash_length': [16, 64],
      'salt': [
        base64Encode(List.filled(15, 0)),
        base64Encode(List.filled(65, 0)),
      ],
    }.entries) {
      for (final value in entry.value) {
        expect(
          () => KdfDescriptor.fromJson({...base, entry.key: value}),
          throwsFormatException,
        );
      }
    }
    for (final iterations in [1, 2, 3, 6]) {
      expect(
        KdfDescriptor.fromJson({...base, 'iterations': iterations}).validate(),
        hasLength(16),
      );
    }
  });
}
