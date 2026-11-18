import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// 直接建立原始記錄，讓重複項目不先被 Archive 合併。
Uint8List zipRecordFixture(
  List<String> names, {
  bool zip64 = false,
  bool descriptor = false,
  bool descriptorSignature = true,
  List<int> payload = const [1, 2, 3],
  bool deflate = false,
  int? declaredSize,
  String? unicodePath,
}) {
  final content = deflate ? ZLibCodec(raw: true).encode(payload) : payload;
  final size = declaredSize ?? payload.length;
  final output = BytesBuilder();
  void number(int value, int width) {
    output.add(List.generate(width, (i) => (value >> (8 * i)) & 255));
  }

  final offsets = <int>[];
  final crc = getCrc32(payload);
  for (final name in names) {
    final encoded = utf8.encode(name);
    offsets.add(output.length);
    number(0x04034b50, 4);
    number(zip64 ? 45 : 20, 2);
    number(0x800 | (descriptor ? 8 : 0), 2);
    number(deflate ? 8 : 0, 2);
    number(0, 4);
    number(descriptor ? 0 : crc, 4);
    number(
      zip64
          ? 0xffffffff
          : descriptor
          ? 0
          : content.length,
      4,
    );
    number(
      zip64
          ? 0xffffffff
          : descriptor
          ? 0
          : size,
      4,
    );
    final unicode = unicodePath == null ? null : utf8.encode(unicodePath);
    number(encoded.length, 2);
    number((zip64 ? 20 : 0) + (unicode == null ? 0 : 9 + unicode.length), 2);
    output.add(encoded);
    if (zip64) {
      number(1, 2);
      number(16, 2);
      number(descriptor ? 0 : size, 8);
      number(descriptor ? 0 : content.length, 8);
    }
    if (unicode != null) {
      number(0x7075, 2);
      number(5 + unicode.length, 2);
      number(1, 1);
      number(getCrc32(encoded), 4);
      output.add(unicode);
    }
    output.add(content);
    if (descriptor) {
      if (descriptorSignature) number(0x08074b50, 4);
      number(crc, 4);
      number(content.length, zip64 ? 8 : 4);
      number(size, zip64 ? 8 : 4);
    }
  }
  final directoryOffset = output.length;
  for (var i = 0; i < names.length; i++) {
    final encoded = utf8.encode(names[i]);
    number(0x02014b50, 4);
    number(zip64 ? 45 : 20, 2);
    number(zip64 ? 45 : 20, 2);
    number(0x800 | (descriptor ? 8 : 0), 2);
    number(deflate ? 8 : 0, 2);
    number(0, 4);
    number(crc, 4);
    number(zip64 ? 0xffffffff : content.length, 4);
    number(zip64 ? 0xffffffff : size, 4);
    final unicode = unicodePath == null ? null : utf8.encode(unicodePath);
    number(encoded.length, 2);
    number((zip64 ? 20 : 0) + (unicode == null ? 0 : 9 + unicode.length), 2);
    number(0, 2);
    number(0, 2);
    number(0, 2);
    number(0x81a40000, 4);
    number(offsets[i], 4);
    output.add(encoded);
    if (zip64) {
      number(1, 2);
      number(16, 2);
      number(size, 8);
      number(content.length, 8);
    }
    if (unicode != null) {
      number(0x7075, 2);
      number(5 + unicode.length, 2);
      number(1, 1);
      number(getCrc32(encoded), 4);
      output.add(unicode);
    }
  }
  final directorySize = output.length - directoryOffset;
  if (zip64) {
    final recordOffset = output.length;
    number(0x06064b50, 4);
    number(44, 8);
    number(45, 2);
    number(45, 2);
    number(0, 4);
    number(0, 4);
    number(names.length, 8);
    number(names.length, 8);
    number(directorySize, 8);
    number(directoryOffset, 8);
    number(0x07064b50, 4);
    number(0, 4);
    number(recordOffset, 8);
    number(1, 4);
  }
  number(0x06054b50, 4);
  number(0, 2);
  number(0, 2);
  number(zip64 ? 0xffff : names.length, 2);
  number(zip64 ? 0xffff : names.length, 2);
  number(zip64 ? 0xffffffff : directorySize, 4);
  number(zip64 ? 0xffffffff : directoryOffset, 4);
  number(0, 2);
  return output.toBytes();
}
