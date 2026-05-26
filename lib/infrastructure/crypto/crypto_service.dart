import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../domain/recovery/kdf_descriptor.dart';
import '../../infrastructure/security/device_key_manager.dart';

const String kEncryptedDocumentMagic = 'LDJ2';
const int _gcmNonceLength = 12;
const int _gcmTagLength = 16;
const int _schemaVersion = 2;

class EncryptionKeySlot {
  const EncryptionKeySlot({
    required this.slotId,
    required this.slotType,
    required this.wrapAlgorithm,
    required this.wrappedKeyBase64,
    required this.nonceBase64,
    this.kdf,
    this.platform,
  });

  final String slotId;
  final String slotType;
  final String wrapAlgorithm;
  final String wrappedKeyBase64;
  final String nonceBase64;
  final KdfDescriptor? kdf;
  final String? platform;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'slot_id': slotId,
      'slot_type': slotType,
      'wrap_algorithm': wrapAlgorithm,
      'wrapped_key': wrappedKeyBase64,
      'nonce': nonceBase64,
      if (kdf != null) 'kdf': kdf!.toJson(),
      if (platform != null) 'platform': platform,
    };
  }

  factory EncryptionKeySlot.fromJson(Map<String, Object?> json) {
    return EncryptionKeySlot(
      slotId: (json['slot_id'] ?? '').toString(),
      slotType: (json['slot_type'] ?? '').toString(),
      wrapAlgorithm: (json['wrap_algorithm'] ?? 'aes-256-gcm').toString(),
      wrappedKeyBase64: (json['wrapped_key'] ?? '').toString(),
      nonceBase64: (json['nonce'] ?? '').toString(),
      kdf: json['kdf'] is Map<String, Object?>
          ? KdfDescriptor.fromJson(json['kdf'] as Map<String, Object?>)
          : null,
      platform: json['platform']?.toString(),
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
  final List<EncryptionKeySlot> keySlots;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schema_version': schemaVersion,
      'file_id': fileId,
      'vault_id': vaultId,
      'content_type': contentType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'cipher': cipher,
      'nonce': nonceBase64,
      'key_slots': keySlots.map((EncryptionKeySlot slot) => slot.toJson()).toList(),
    };
  }

  factory EncryptedDocumentHeader.fromJson(Map<String, Object?> json) {
    final List<Object?> rawSlots =
        json['key_slots'] is List<Object?> ? json['key_slots'] as List<Object?> : const <Object?>[];

    return EncryptedDocumentHeader(
      schemaVersion: int.tryParse('${json['schema_version'] ?? 0}') ?? 0,
      fileId: (json['file_id'] ?? '').toString(),
      vaultId: (json['vault_id'] ?? '').toString(),
      contentType: (json['content_type'] ?? 'application/octet-stream').toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      cipher: (json['cipher'] ?? 'aes-256-gcm').toString(),
      nonceBase64: (json['nonce'] ?? '').toString(),
      keySlots: rawSlots.whereType<Map<String, Object?>>().map(EncryptionKeySlot.fromJson).toList(),
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

class DecryptionContext {
  const DecryptionContext({
    required this.vaultId,
    required this.trustedDevice,
    this.recoveryWrapKey,
    this.deviceSlotId,
  });

  const DecryptionContext.recovery({
    required List<int> recoveryWrapKey,
    required String vaultId,
  }) : this(
          vaultId: vaultId,
          trustedDevice: false,
          recoveryWrapKey: recoveryWrapKey,
        );

  final String vaultId;
  final bool trustedDevice;
  final List<int>? recoveryWrapKey;
  final String? deviceSlotId;
}

abstract class CryptoService {
  Future<EncryptionResult> encryptMarkdown({
    required String documentId,
    required String vaultId,
    required String markdown,
    required List<int> recoveryWrapKey,
    required KdfDescriptor recoverySlotKdf,
    required DateTime createdAt,
    required DateTime updatedAt,
  });

  Future<EncryptionResult> encryptBytes({
    required String documentId,
    required String vaultId,
    required List<int> plaintextBytes,
    required String contentType,
    required List<int> recoveryWrapKey,
    required KdfDescriptor recoverySlotKdf,
    required DateTime createdAt,
    required DateTime updatedAt,
  });

  ParsedEncryptedDocument parseFileBytes(List<int> fileBytes);

  Future<List<int>> decryptBytes({
    required List<int> headerBytes,
    required List<int> ciphertextBytes,
    required DecryptionContext context,
  });

  Future<String> decryptMarkdown({
    required List<int> headerBytes,
    required List<int> ciphertextBytes,
    required DecryptionContext context,
  });

  Future<List<int>> deriveRecoveryWrapKey({
    required String recoveryKey,
    required KdfDescriptor kdf,
  });
}

class LocalCryptoService implements CryptoService {
  LocalCryptoService({
    required DeviceKeyManager deviceKeyManager,
    Cipher? contentCipher,
    Random? random,
  })  : _deviceKeyManager = deviceKeyManager,
        _contentCipher = contentCipher ?? AesGcm.with256bits(),
        _recoveryWrapCipher = AesGcm.with256bits(),
        _random = random ?? Random.secure();

  final DeviceKeyManager _deviceKeyManager;
  final Cipher _contentCipher;
  final Cipher _recoveryWrapCipher;
  final Random _random;

  @override
  Future<List<int>> decryptBytes({
    required List<int> headerBytes,
    required List<int> ciphertextBytes,
    required DecryptionContext context,
  }) async {
    final EncryptedDocumentHeader header = _parseHeader(headerBytes);
    _validateHeader(header);
    final SecretBox secretBox = _readSecretBox(
      ciphertextBytes,
      base64Decode(header.nonceBase64),
    );

    if (context.trustedDevice) {
      final EncryptionKeySlot? deviceSlot = _findDeviceSlot(header, context.deviceSlotId);
      if (deviceSlot != null) {
        try {
          final List<int> fileKeyBytes = await _deviceKeyManager.unwrapWithDeviceKey(
            vaultId: context.vaultId,
            slotId: deviceSlot.slotId,
            nonceBase64: deviceSlot.nonceBase64,
            ciphertextBase64: deviceSlot.wrappedKeyBase64,
          );
          return await _contentCipher.decrypt(
            secretBox,
            secretKey: SecretKey(fileKeyBytes),
            aad: headerBytes,
          );
        } catch (_) {}
      }
    }

    if (context.recoveryWrapKey != null) {
      final EncryptionKeySlot recoverySlot = header.keySlots.firstWhere(
        (EncryptionKeySlot slot) => slot.slotType == 'recovery',
        orElse: () => throw const FormatException('Recovery slot is missing.'),
      );
      final List<int> fileKeyBytes = await _unwrapRecoveryKey(
        wrappingKey: context.recoveryWrapKey!,
        slot: recoverySlot,
      );
      return _contentCipher.decrypt(
        secretBox,
        secretKey: SecretKey(fileKeyBytes),
        aad: headerBytes,
      );
    }

    throw SecretBoxAuthenticationError();
  }

  @override
  Future<String> decryptMarkdown({
    required List<int> headerBytes,
    required List<int> ciphertextBytes,
    required DecryptionContext context,
  }) async {
    final List<int> bytes = await decryptBytes(
      headerBytes: headerBytes,
      ciphertextBytes: ciphertextBytes,
      context: context,
    );
    return utf8.decode(bytes);
  }

  @override
  Future<List<int>> deriveRecoveryWrapKey({
    required String recoveryKey,
    required KdfDescriptor kdf,
  }) async {
    final Argon2id algo = Argon2id(
      parallelism: kdf.parallelism,
      memory: kdf.memory,
      iterations: kdf.iterations,
      hashLength: kdf.hashLength,
    );
    final List<int> saltBytes = base64Decode(kdf.saltBase64);
    final SecretKey derived = await algo.deriveKey(
      secretKey: SecretKey(utf8.encode(recoveryKey)),
      nonce: saltBytes,
    );
    return derived.extractBytes();
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
  }) async {
    final SecretKey fileKey = await _contentCipher.newSecretKey();
    final List<int> fileKeyBytes = await fileKey.extractBytes();
    final EncryptionKeySlot recoverySlot = await _createRecoverySlot(
      wrappingKey: recoveryWrapKey,
      recoverySlotKdf: recoverySlotKdf,
      fileKeyBytes: fileKeyBytes,
    );

    final List<int> contentNonce = _randomBytes(_gcmNonceLength);
    final EncryptedDocumentHeader header = EncryptedDocumentHeader(
      schemaVersion: _schemaVersion,
      fileId: documentId,
      vaultId: vaultId,
      contentType: contentType,
      createdAt: createdAt,
      updatedAt: updatedAt,
      cipher: 'aes-256-gcm',
      nonceBase64: base64Encode(contentNonce),
      keySlots: <EncryptionKeySlot>[recoverySlot],
    );
    final Uint8List headerBytes = _canonicalHeaderBytes(header);
    final SecretBox contentBox = await _contentCipher.encrypt(
      plaintextBytes,
      secretKey: fileKey,
      nonce: contentNonce,
      aad: headerBytes,
    );

    return EncryptionResult(
      header: header,
      headerBytes: headerBytes,
      ciphertextBytes: Uint8List.fromList(<int>[
        ...contentBox.cipherText,
        ...contentBox.mac.bytes,
      ]),
    );
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
    return encryptBytes(
      documentId: documentId,
      vaultId: vaultId,
      plaintextBytes: utf8.encode(markdown),
      contentType: 'text/markdown',
      recoveryWrapKey: recoveryWrapKey,
      recoverySlotKdf: recoverySlotKdf,
      createdAt: createdAt,
      updatedAt: updatedAt,
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
      throw const FormatException('不支援舊版或未知的加密檔案格式。');
    }

    final ByteData data = ByteData.sublistView(bytes, 4, 8);
    final int headerLength = data.getUint32(0, Endian.big);
    final int headerEnd = 8 + headerLength;
    if (headerLength <= 0 || headerEnd >= bytes.lengthInBytes) {
      throw const FormatException('加密檔案標頭長度不正確。');
    }

    final Uint8List headerBytes = Uint8List.sublistView(bytes, 8, headerEnd);
    final Uint8List ciphertextBytes = Uint8List.sublistView(bytes, headerEnd);
    final EncryptedDocumentHeader header = _parseHeader(headerBytes);
    _validateHeader(header);

    return ParsedEncryptedDocument(
      header: header,
      headerBytes: headerBytes,
      ciphertextBytes: ciphertextBytes,
    );
  }

  Future<EncryptionKeySlot> _createRecoverySlot({
    required List<int> wrappingKey,
    required KdfDescriptor recoverySlotKdf,
    required List<int> fileKeyBytes,
  }) async {
    final List<int> nonce = _randomBytes(_gcmNonceLength);
    final SecretBox box = await _recoveryWrapCipher.encrypt(
      fileKeyBytes,
      secretKey: SecretKey(wrappingKey),
      nonce: nonce,
    );
    return EncryptionKeySlot(
      slotId: 'recovery',
      slotType: 'recovery',
      wrapAlgorithm: 'aes-256-gcm',
      wrappedKeyBase64: base64Encode(<int>[...box.cipherText, ...box.mac.bytes]),
      nonceBase64: base64Encode(nonce),
      kdf: recoverySlotKdf,
    );
  }

  Uint8List _canonicalHeaderBytes(EncryptedDocumentHeader header) {
    return Uint8List.fromList(utf8.encode(jsonEncode(header.toJson())));
  }

  EncryptionKeySlot? _findDeviceSlot(
    EncryptedDocumentHeader header,
    String? deviceSlotId,
  ) {
    if (deviceSlotId != null && deviceSlotId.isNotEmpty) {
      for (final EncryptionKeySlot slot in header.keySlots) {
        if (slot.slotType == 'device' && slot.slotId == deviceSlotId) {
          return slot;
        }
      }
      return null;
    }
    for (final EncryptionKeySlot slot in header.keySlots) {
      if (slot.slotType == 'device') {
        return slot;
      }
    }
    return null;
  }

  EncryptedDocumentHeader _parseHeader(List<int> headerBytes) {
    final Map<String, Object?> headerJson =
        (jsonDecode(utf8.decode(headerBytes)) as Map<Object?, Object?>).map(
      (Object? key, Object? value) => MapEntry('$key', _deepCast(value)),
    );
    return EncryptedDocumentHeader.fromJson(headerJson);
  }

  SecretBox _readSecretBox(List<int> encryptedBytes, List<int> nonce) {
    if (nonce.length != _gcmNonceLength) {
      throw const FormatException('Invalid nonce length.');
    }
    if (encryptedBytes.length < _gcmTagLength) {
      throw const FormatException('Ciphertext is too short.');
    }
    return SecretBox(
      encryptedBytes.sublist(0, encryptedBytes.length - _gcmTagLength),
      nonce: nonce,
      mac: Mac(encryptedBytes.sublist(encryptedBytes.length - _gcmTagLength)),
    );
  }

  Future<List<int>> _unwrapRecoveryKey({
    required List<int> wrappingKey,
    required EncryptionKeySlot slot,
  }) async {
    final List<int> wrapped = base64Decode(slot.wrappedKeyBase64);
    final SecretBox secretBox = _readSecretBox(
      wrapped,
      base64Decode(slot.nonceBase64),
    );
    return _recoveryWrapCipher.decrypt(
      secretBox,
      secretKey: SecretKey(wrappingKey),
    );
  }

  void _validateHeader(EncryptedDocumentHeader header) {
    if (header.schemaVersion != _schemaVersion) {
      throw FormatException('不支援的加密文件版本：${header.schemaVersion}。');
    }
    if (header.fileId.isEmpty || header.vaultId.isEmpty) {
      throw const FormatException('加密檔案缺少必要識別資訊。');
    }
    if (header.cipher != 'aes-256-gcm') {
      throw FormatException('不支援的加密演算法：${header.cipher}。');
    }
    final List<int> nonceBytes = base64Decode(header.nonceBase64);
    if (nonceBytes.length != _gcmNonceLength) {
      throw const FormatException('Encrypted document nonce is invalid.');
    }
    if (!header.keySlots.any((EncryptionKeySlot slot) => slot.slotType == 'recovery')) {
      throw const FormatException('加密檔案缺少 Recovery 金鑰槽。');
    }
    for (final EncryptionKeySlot slot in header.keySlots) {
      final List<int> slotNonce = base64Decode(slot.nonceBase64);
      if (slotNonce.length != _gcmNonceLength) {
        throw const FormatException('Key slot nonce is invalid.');
      }
      if (slot.slotType == 'device') {
        if (slot.wrapAlgorithm != 'android-keystore-aes-gcm' || (slot.platform?.isEmpty ?? true)) {
          throw const FormatException('裝置金鑰槽資訊不正確。');
        }
      } else if (slot.slotType == 'recovery') {
        if (slot.wrapAlgorithm != 'aes-256-gcm' || slot.kdf == null) {
          throw const FormatException('Recovery 金鑰槽資訊不正確。');
        }
      }
    }
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
