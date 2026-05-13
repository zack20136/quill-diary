import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const String kEncryptedDocumentMagic = 'LDJ1';

class KdfDescriptor {
  const KdfDescriptor({
    required this.name,
    required this.saltBase64,
    required this.iterations,
  });

  final String name;
  final String saltBase64;
  final int iterations;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'salt': saltBase64,
      'iterations': iterations,
    };
  }

  factory KdfDescriptor.fromJson(Map<String, Object?> json) {
    return KdfDescriptor(
      name: (json['name'] ?? 'pbkdf2-sha256').toString(),
      saltBase64: (json['salt'] ?? '').toString(),
      iterations: int.tryParse('${json['iterations'] ?? 210000}') ?? 210000,
    );
  }
}

class EncryptionKeySlot {
  const EncryptionKeySlot({
    required this.slotId,
    required this.type,
    required this.wrapAlgorithm,
    required this.wrappedKeyBase64,
    required this.nonceBase64,
    this.kdf,
  });

  final String slotId;
  final String type;
  final String wrapAlgorithm;
  final String wrappedKeyBase64;
  final String nonceBase64;
  final KdfDescriptor? kdf;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'slot_id': slotId,
      'type': type,
      'wrap_algorithm': wrapAlgorithm,
      'wrapped_key': wrappedKeyBase64,
      'nonce': nonceBase64,
      if (kdf != null) 'kdf': kdf!.toJson(),
    };
  }

  factory EncryptionKeySlot.fromJson(Map<String, Object?> json) {
    return EncryptionKeySlot(
      slotId: (json['slot_id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      wrapAlgorithm: (json['wrap_algorithm'] ?? 'aes-256-gcm').toString(),
      wrappedKeyBase64: (json['wrapped_key'] ?? '').toString(),
      nonceBase64: (json['nonce'] ?? '').toString(),
      kdf: json['kdf'] is Map<String, Object?>
          ? KdfDescriptor.fromJson(json['kdf'] as Map<String, Object?>)
          : null,
    );
  }
}

class EncryptedDocumentHeader {
  const EncryptedDocumentHeader({
    required this.schemaVersion,
    required this.fileId,
    required this.vaultId,
    required this.contentType,
    required this.createdAt,
    required this.updatedAt,
    required this.cipher,
    required this.nonceBase64,
    required this.aadBase64,
    required this.keySlots,
  });

  final int schemaVersion;
  final String fileId;
  final String vaultId;
  final String contentType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String cipher;
  final String nonceBase64;
  final String aadBase64;
  final List<EncryptionKeySlot> keySlots;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schema_version': schemaVersion,
      'file_id': fileId,
      'vault_id': vaultId,
      'content_type': contentType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'crypto': <String, Object?>{
        'cipher': cipher,
        'nonce': nonceBase64,
        'aad': aadBase64,
      },
      'key_slots': keySlots.map((EncryptionKeySlot slot) => slot.toJson()).toList(),
    };
  }

  factory EncryptedDocumentHeader.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> crypto =
        json['crypto'] is Map<String, Object?> ? json['crypto'] as Map<String, Object?> : <String, Object?>{};
    final List<Object?> rawSlots =
        json['key_slots'] is List<Object?> ? json['key_slots'] as List<Object?> : const <Object?>[];

    return EncryptedDocumentHeader(
      schemaVersion: int.tryParse('${json['schema_version'] ?? 1}') ?? 1,
      fileId: (json['file_id'] ?? '').toString(),
      vaultId: (json['vault_id'] ?? '').toString(),
      contentType: (json['content_type'] ?? 'application/octet-stream').toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      cipher: (crypto['cipher'] ?? 'aes-256-gcm').toString(),
      nonceBase64: (crypto['nonce'] ?? '').toString(),
      aadBase64: (crypto['aad'] ?? '').toString(),
      keySlots: rawSlots
          .whereType<Map<String, Object?>>()
          .map(EncryptionKeySlot.fromJson)
          .toList(),
    );
  }
}

class ParsedEncryptedDocument {
  const ParsedEncryptedDocument({
    required this.header,
    required this.headerBytes,
    required this.ciphertextBytes,
  });

  final EncryptedDocumentHeader header;
  final Uint8List headerBytes;
  final Uint8List ciphertextBytes;
}

class EncryptionResult {
  const EncryptionResult({
    required this.header,
    required this.headerBytes,
    required this.ciphertextBytes,
  });

  final EncryptedDocumentHeader header;
  final Uint8List headerBytes;
  final Uint8List ciphertextBytes;

  Uint8List toFileBytes() {
    final ByteData lengthBuffer = ByteData(8)
      ..setUint8(0, kEncryptedDocumentMagic.codeUnitAt(0))
      ..setUint8(1, kEncryptedDocumentMagic.codeUnitAt(1))
      ..setUint8(2, kEncryptedDocumentMagic.codeUnitAt(2))
      ..setUint8(3, kEncryptedDocumentMagic.codeUnitAt(3))
      ..setUint32(4, headerBytes.lengthInBytes, Endian.big);

    return Uint8List.fromList(<int>[
      ...lengthBuffer.buffer.asUint8List(),
      ...headerBytes,
      ...ciphertextBytes,
    ]);
  }
}

abstract class CryptoService {
  Future<EncryptionResult> encryptMarkdown({
    required String documentId,
    required String vaultId,
    required String markdown,
    required List<int> recoveryWrapKey,
    required String deviceSecret,
    required DateTime createdAt,
    required DateTime updatedAt,
  });

  Future<EncryptionResult> encryptBytes({
    required String documentId,
    required String vaultId,
    required List<int> plaintextBytes,
    required String contentType,
    required List<int> recoveryWrapKey,
    required String deviceSecret,
    required DateTime createdAt,
    required DateTime updatedAt,
  });

  ParsedEncryptedDocument parseFileBytes(List<int> fileBytes);

  Future<List<int>> decryptBytes({
    required List<int> headerBytes,
    required List<int> ciphertextBytes,
    required String? deviceSecret,
    required List<int>? recoveryWrapKey,
  });

  Future<String> decryptMarkdown({
    required List<int> headerBytes,
    required List<int> ciphertextBytes,
    required String? deviceSecret,
    required List<int>? recoveryWrapKey,
  });

  Future<List<int>> deriveRecoveryWrapKey({
    required String recoveryKey,
    required List<int> saltBytes,
  });
}

class LocalCryptoService implements CryptoService {
  LocalCryptoService({
    Cipher? contentCipher,
    Random? random,
  })  : _contentCipher = contentCipher ?? AesGcm.with256bits(),
        _wrapCipher = AesGcm.with256bits(),
        _random = random ?? Random.secure();

  final Cipher _contentCipher;
  final Cipher _wrapCipher;
  final Random _random;
  static const int _recoveryIterations = 210000;

  @override
  Future<EncryptionResult> encryptMarkdown({
    required String documentId,
    required String vaultId,
    required String markdown,
    required List<int> recoveryWrapKey,
    required String deviceSecret,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return encryptBytes(
      documentId: documentId,
      vaultId: vaultId,
      plaintextBytes: Uint8List.fromList(utf8.encode(markdown)),
      contentType: 'text/markdown',
      recoveryWrapKey: recoveryWrapKey,
      deviceSecret: deviceSecret,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  Future<EncryptionResult> encryptBytes({
    required String documentId,
    required String vaultId,
    required List<int> plaintextBytes,
    required String contentType,
    required List<int> recoveryWrapKey,
    required String deviceSecret,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {
    final SecretKey fileKey = await _contentCipher.newSecretKey();
    final List<int> fileKeyBytes = await fileKey.extractBytes();
    final List<int> aadBytes = utf8.encode(
      jsonEncode(<String, Object?>{
        'schema_version': 1,
        'file_id': documentId,
        'vault_id': vaultId,
        'content_type': contentType,
      }),
    );
    final List<int> contentNonce = _randomBytes(12);
    final SecretBox contentBox = await _contentCipher.encrypt(
      plaintextBytes,
      secretKey: fileKey,
      nonce: contentNonce,
      aad: aadBytes,
    );

    final EncryptionKeySlot deviceSlot = await _createWrappedSlot(
      slotId: 'dev_default',
      type: 'device',
      wrappingKey: await _deviceWrappingKey(deviceSecret),
      fileKeyBytes: fileKeyBytes,
      kdf: null,
    );

    final EncryptionKeySlot recoverySlot = await _createWrappedSlot(
      slotId: 'rks_01',
      type: 'recovery',
      wrappingKey: recoveryWrapKey,
      fileKeyBytes: fileKeyBytes,
      kdf: const KdfDescriptor(
        name: 'pbkdf2-sha256',
        saltBase64: '',
        iterations: _recoveryIterations,
      ),
    );

    final EncryptedDocumentHeader header = EncryptedDocumentHeader(
      schemaVersion: 1,
      fileId: documentId,
      vaultId: vaultId,
      contentType: contentType,
      createdAt: createdAt,
      updatedAt: updatedAt,
      cipher: 'aes-256-gcm',
      nonceBase64: base64Encode(contentNonce),
      aadBase64: base64Encode(aadBytes),
      keySlots: <EncryptionKeySlot>[deviceSlot, recoverySlot],
    );
    final Uint8List headerBytes =
        Uint8List.fromList(utf8.encode(jsonEncode(header.toJson())));

    return EncryptionResult(
      header: header,
      headerBytes: headerBytes,
      ciphertextBytes: Uint8List.fromList(<int>[
        ...contentBox.cipherText,
        ...contentBox.mac.bytes,
      ]),
    );
  }

  Future<EncryptionKeySlot> _createWrappedSlot({
    required String slotId,
    required String type,
    required List<int> wrappingKey,
    required List<int> fileKeyBytes,
    required KdfDescriptor? kdf,
  }) async {
    final List<int> nonce = _randomBytes(12);
    final SecretBox box = await _wrapCipher.encrypt(
      fileKeyBytes,
      secretKey: SecretKey(wrappingKey),
      nonce: nonce,
    );
    return EncryptionKeySlot(
      slotId: slotId,
      type: type,
      wrapAlgorithm: 'aes-256-gcm',
      wrappedKeyBase64: base64Encode(<int>[...box.cipherText, ...box.mac.bytes]),
      nonceBase64: base64Encode(nonce),
      kdf: kdf,
    );
  }

  @override
  ParsedEncryptedDocument parseFileBytes(List<int> fileBytes) {
    final Uint8List bytes = Uint8List.fromList(fileBytes);
    if (bytes.lengthInBytes < 8) {
      throw const FormatException('Encrypted document is too short.');
    }

    final String magic = ascii.decode(bytes.sublist(0, 4));
    if (magic != kEncryptedDocumentMagic) {
      throw const FormatException('Magic header mismatch.');
    }

    final ByteData data = ByteData.sublistView(bytes, 4, 8);
    final int headerLength = data.getUint32(0, Endian.big);
    final int headerEnd = 8 + headerLength;
    if (headerLength <= 0 || headerEnd > bytes.lengthInBytes) {
      throw const FormatException('Invalid encrypted document header length.');
    }

    final Uint8List headerBytes = Uint8List.sublistView(bytes, 8, headerEnd);
    final Uint8List ciphertextBytes = Uint8List.sublistView(bytes, headerEnd);
    final Map<String, Object?> headerJson =
        (jsonDecode(utf8.decode(headerBytes)) as Map<Object?, Object?>)
            .map((Object? key, Object? value) => MapEntry('$key', _deepCast(value)));

    return ParsedEncryptedDocument(
      header: EncryptedDocumentHeader.fromJson(headerJson),
      headerBytes: headerBytes,
      ciphertextBytes: ciphertextBytes,
    );
  }

  @override
  Future<List<int>> decryptBytes({
    required List<int> headerBytes,
    required List<int> ciphertextBytes,
    required String? deviceSecret,
    required List<int>? recoveryWrapKey,
  }) async {
    final Map<String, Object?> headerJson =
        (jsonDecode(utf8.decode(headerBytes)) as Map<Object?, Object?>)
            .map((Object? key, Object? value) => MapEntry('$key', _deepCast(value)));
    final EncryptedDocumentHeader header = EncryptedDocumentHeader.fromJson(headerJson);
    final List<int> aadBytes = base64Decode(header.aadBase64);
    final List<int> contentNonce = base64Decode(header.nonceBase64);

    final List<int>? deviceWrappingKey = deviceSecret != null && deviceSecret.isNotEmpty
        ? await _deviceWrappingKey(deviceSecret)
        : null;

    for (final EncryptionKeySlot slot in header.keySlots) {
      final List<int>? wrappingKey = slot.type == 'device'
          ? deviceWrappingKey
          : recoveryWrapKey;
      if (wrappingKey == null) {
        continue;
      }

      try {
        final SecretKey fileKey = SecretKey(
          await _unwrapKey(
            wrappingKey: wrappingKey,
            slot: slot,
          ),
        );
        final SecretBox secretBox = SecretBox(
          ciphertextBytes.sublist(0, ciphertextBytes.length - 16),
          nonce: contentNonce,
          mac: Mac(ciphertextBytes.sublist(ciphertextBytes.length - 16)),
        );
        final List<int> plaintext = await _contentCipher.decrypt(
          secretBox,
          secretKey: fileKey,
          aad: aadBytes,
        );
        return plaintext;
      } catch (_) {
        continue;
      }
    }

    throw SecretBoxAuthenticationError();
  }

  @override
  Future<String> decryptMarkdown({
    required List<int> headerBytes,
    required List<int> ciphertextBytes,
    required String? deviceSecret,
    required List<int>? recoveryWrapKey,
  }) async {
    final List<int> bytes = await decryptBytes(
      headerBytes: headerBytes,
      ciphertextBytes: ciphertextBytes,
      deviceSecret: deviceSecret,
      recoveryWrapKey: recoveryWrapKey,
    );
    return utf8.decode(bytes);
  }

  @override
  Future<List<int>> deriveRecoveryWrapKey({
    required String recoveryKey,
    required List<int> saltBytes,
  }) async {
    final Pbkdf2 pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _recoveryIterations,
      bits: 256,
    );
    final SecretKey secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(recoveryKey)),
      nonce: saltBytes,
    );
    return secretKey.extractBytes();
  }

  Future<List<int>> _unwrapKey({
    required List<int> wrappingKey,
    required EncryptionKeySlot slot,
  }) async {
    final List<int> wrapped = base64Decode(slot.wrappedKeyBase64);
    final SecretBox secretBox = SecretBox(
      wrapped.sublist(0, wrapped.length - 16),
      nonce: base64Decode(slot.nonceBase64),
      mac: Mac(wrapped.sublist(wrapped.length - 16)),
    );
    return _wrapCipher.decrypt(
      secretBox,
      secretKey: SecretKey(wrappingKey),
    );
  }

  Future<List<int>> _deviceWrappingKey(String deviceSecret) async {
    final Hash hash = await Sha256().hash(utf8.encode(deviceSecret));
    return hash.bytes;
  }

  List<int> _randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }

  Object? _deepCast(Object? value) {
    if (value is Map<Object?, Object?>) {
      return value.map((Object? key, Object? entryValue) {
        return MapEntry('$key', _deepCast(entryValue));
      });
    }
    if (value is List<Object?>) {
      return value.map(_deepCast).toList();
    }
    return value;
  }
}
