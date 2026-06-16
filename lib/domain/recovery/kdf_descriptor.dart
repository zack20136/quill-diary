import 'dart:convert';

/// 衍生復原包裝金鑰的 Argon2id 參數（RFC 9106；OWASP 導向預設值）。
class KdfDescriptor {
  const KdfDescriptor({
    required this.name,
    required this.saltBase64,
    required this.memory,
    required this.parallelism,
    required this.iterations,
    required this.hashLength,
  }) : assert(name == kAlgorithmName, 'Only argon2id is supported');

  static const String kAlgorithmName = 'argon2id';

  /// 記憶體成本：1 KiB 區塊數（[Argon2id.memory]）。
  static const int kRecoveryMemoryKiB = 19456;

  /// 時間成本（[Argon2id.iterations]）；較 OWASP Argon2 下限略高以降低離線暴力破解成本，
  /// 仍維持 ~19 MiB 記憶體與平行度=1 以適合中階 Android。
  static const int kRecoveryIterations = 3;
  static const int kRecoveryParallelism = 1;
  static const int kRecoveryHashLength = 32;

  final String name;
  final String saltBase64;
  final int memory;
  final int parallelism;
  final int iterations;
  final int hashLength;

  factory KdfDescriptor.argon2idRecovery({required List<int> saltBytes}) {
    if (saltBytes.length < 16) {
      throw ArgumentError.value(
        saltBytes.length,
        'saltBytes',
        'Salt must be at least 16 bytes.',
      );
    }
    return KdfDescriptor(
      name: kAlgorithmName,
      saltBase64: base64Encode(saltBytes),
      memory: kRecoveryMemoryKiB,
      parallelism: kRecoveryParallelism,
      iterations: kRecoveryIterations,
      hashLength: kRecoveryHashLength,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'salt': saltBase64,
      'memory': memory,
      'parallelism': parallelism,
      'iterations': iterations,
      'hash_length': hashLength,
    };
  }

  factory KdfDescriptor.fromJson(Map<String, Object?> json) {
    final String nameParsed = (json['name'] ?? '').toString();
    if (nameParsed != kAlgorithmName) {
      throw FormatException(
        'Unsupported KDF: $nameParsed (expected $kAlgorithmName).',
      );
    }
    final String salt = (json['salt'] ?? '').toString();
    if (salt.isEmpty) {
      throw const FormatException('KDF salt is missing.');
    }
    final List<int> saltBytes = base64Decode(salt);
    if (saltBytes.length < 16) {
      throw const FormatException('KDF salt is too short.');
    }
    return KdfDescriptor(
      name: kAlgorithmName,
      saltBase64: salt,
      memory: _reqInt(json, 'memory'),
      parallelism: _reqInt(json, 'parallelism'),
      iterations: _reqInt(json, 'iterations'),
      hashLength: _reqInt(json, 'hash_length'),
    );
  }

  /// 從復原中繼資料讀取 KDF 子區段（忽略 `purpose`）。
  static KdfDescriptor fromRecoveryMetadataKdf(Map<String, Object?> json) {
    final Map<String, Object?> clone = Map<String, Object?>.from(json)
      ..remove('purpose');
    return KdfDescriptor.fromJson(clone);
  }

  static int _reqInt(Map<String, Object?> json, String key) {
    if (!json.containsKey(key)) {
      throw FormatException('KDF missing required parameter: $key');
    }
    return int.tryParse('${json[key]}') ??
        (throw FormatException('Invalid integer for KDF parameter $key.'));
  }
}
