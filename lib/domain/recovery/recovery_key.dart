import 'dart:math';
import 'dart:typed_data';

class RecoveryKeyFormatException extends FormatException {
  const RecoveryKeyFormatException() : super('復原金鑰格式不正確');
}

class RecoveryKeyRotationPendingException implements Exception {
  const RecoveryKeyRotationPendingException();
}

class RecoveryKeyRotationDraftExpiredException implements Exception {
  const RecoveryKeyRotationDraftExpiredException();
}

abstract final class RecoveryKey {
  static const int symbolCount = 24;
  static const int groupSize = 4;
  static const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static final _separators = RegExp(r'[\s\-‐‑‒–—―−－]');
  static final _payload = RegExp(r'^[0-9A-HJKMNP-TV-Z]*$');

  static String payloadOf(String input) => input
      .toUpperCase()
      .replaceAll(_separators, '')
      .replaceAll(RegExp('[IL]'), '1')
      .replaceAll('O', '0');

  static bool isValidPartial(String input) {
    final payload = payloadOf(input);
    return payload.length <= symbolCount && _payload.hasMatch(payload);
  }

  static String format(String payload) => [
    for (var i = 0; i < payload.length; i += groupSize)
      payload.substring(i, min(i + groupSize, payload.length)),
  ].join('-');

  static String normalize(String input) {
    final payload = payloadOf(input);
    if (payload.length != symbolCount || !_payload.hasMatch(payload)) {
      throw const RecoveryKeyFormatException();
    }
    return format(payload);
  }

  static String generate() {
    final random = Random.secure();
    return encode(
      Uint8List.fromList(List.generate(15, (_) => random.nextInt(256))),
    );
  }

  static String encode(List<int> bytes) {
    if (bytes.length != 15 || bytes.any((byte) => byte < 0 || byte > 255)) {
      throw ArgumentError('復原金鑰需要恰好 15 bytes');
    }
    final encoded = StringBuffer();
    var bits = 0;
    var buffer = 0;
    for (final byte in bytes) {
      buffer = (buffer << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        encoded.write(alphabet[(buffer >> bits) & 31]);
      }
      buffer &= (1 << bits) - 1;
    }
    return format(encoded.toString());
  }
}
