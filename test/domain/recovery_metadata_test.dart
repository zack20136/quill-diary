import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';

void main() {
  final KdfDescriptor kdf = KdfDescriptor.argon2idRecovery(
    saltBytes: Uint8List.fromList(List<int>.generate(16, (int i) => i + 1)),
  );

  final RecoveryMetadata metadata = RecoveryMetadata(
    vaultId: 'vlt_META_TEST',
    recoveryEnabled: true,
    recoveryKeyVersion: 1,
    recoveryKeyHint: 'WXYZ',
    createdAt: DateTime.parse('2026-05-19T12:00:00Z'),
    kdf: kdf,
  );

  test('RecoveryMetadata JSON round-trip', () {
    final Map<String, Object?> json = metadata.toJson();
    final RecoveryMetadata restored = RecoveryMetadata.fromJson(json);

    expect(restored.vaultId, metadata.vaultId);
    expect(restored.recoveryEnabled, isTrue);
    expect(restored.recoveryKeyVersion, 1);
    expect(restored.recoveryKeyHint, metadata.recoveryKeyHint);
    expect(restored.kdf.name, KdfDescriptor.kAlgorithmName);
    expect(restored.kdf.saltBase64, kdf.saltBase64);
  });

  test('RecoveryMetadata 拒絕 v0 recovery_key_version', () {
    final Map<String, Object?> json = metadata.toJson()..['recovery_key_version'] = 0;

    expect(
      () => RecoveryMetadata.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  test('RecoveryMetadata 拒絕 schema_version 2', () {
    final Map<String, Object?> json = metadata.toJson()..['schema_version'] = 2;

    expect(
      () => RecoveryMetadata.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  test('RecoveryMetadata 缺少 kdf 時拋 FormatException', () {
    final Map<String, Object?> json = metadata.toJson()..remove('kdf');

    expect(
      () => RecoveryMetadata.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  test('KdfDescriptor 拒絕非 argon2id 演算法', () {
    final Map<String, Object?> json = kdf.toJson()..['name'] = 'pbkdf2';

    expect(
      () => KdfDescriptor.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  test('KdfDescriptor.argon2idRecovery 拒絕過短 salt', () {
    expect(
      () => KdfDescriptor.argon2idRecovery(saltBytes: List<int>.filled(8, 1)),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('KdfDescriptor.fromRecoveryMetadataKdf 忽略 purpose 欄位', () {
    final Map<String, Object?> kdfJson = <String, Object?>{
      ...kdf.toJson(),
      'purpose': 'recovery_wrapping',
    };

    final KdfDescriptor parsed = KdfDescriptor.fromRecoveryMetadataKdf(kdfJson);
    expect(parsed.saltBase64, kdf.saltBase64);
    expect(parsed.memory, kdf.memory);
  });
}
