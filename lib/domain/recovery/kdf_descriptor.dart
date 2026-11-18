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
  });

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

  bool hasSameParametersAs(KdfDescriptor other) =>
      name == other.name &&
      memory == other.memory &&
      parallelism == other.parallelism &&
      iterations == other.iterations &&
      hashLength == other.hashLength &&
      base64Encode(validate()) == base64Encode(other.validate());

  List<int> validate() {
    if (name != kAlgorithmName ||
        parallelism != 1 ||
        memory < 8 * parallelism ||
        memory > 32768 ||
        iterations < 1 ||
        iterations > 6 ||
        hashLength != 32 ||
        saltBase64.length > 88) {
      throw const FormatException('不支援或超出安全範圍的 KDF 參數');
    }
    final salt = base64Decode(saltBase64);
    if (salt.length < 16 || salt.length > 64) {
      throw const FormatException('KDF Salt 長度不正確');
    }
    return salt;
  }

  factory KdfDescriptor.argon2idRecovery({required List<int> saltBytes}) {
    if (saltBytes.length < 16 || saltBytes.length > 64) {
      throw ArgumentError.value(
        saltBytes.length,
        'saltBytes',
        'Salt 必須為 16～64 bytes。',
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
    final descriptor = KdfDescriptor(
      name: (json['name'] ?? '').toString(),
      saltBase64: (json['salt'] ?? '').toString(),
      memory: _reqInt(json, 'memory'),
      parallelism: _reqInt(json, 'parallelism'),
      iterations: _reqInt(json, 'iterations'),
      hashLength: _reqInt(json, 'hash_length'),
    );
    descriptor.validate();
    return descriptor;
  }

  static int _reqInt(Map<String, Object?> json, String key) {
    if (!json.containsKey(key)) {
      throw FormatException('KDF missing required parameter: $key');
    }
    return int.tryParse('${json[key]}') ??
        (throw FormatException('Invalid integer for KDF parameter $key.'));
  }
}
