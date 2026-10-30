import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart' show getCrc32;
import 'package:flutter/foundation.dart' show compute;
import 'package:quill_diary/infrastructure/ai/ai_client.dart';
import 'package:quill_diary/infrastructure/storage/shared/media_type_utils.dart';

/// 移除中繼資料時保留壓縮像素；相容格式轉換也不縮小尺寸。
Future<AiInputImage> prepareAiImage(String id, Uint8List bytes) async {
  try {
    final mime = sniffKnownMediaMimeType(bytes);
    if (mime == 'image/jpeg' ||
        mime == 'image/png' ||
        mime == 'image/webp' ||
        mime == 'image/gif') {
      return AiInputImage(
        id: id,
        mimeType: mime!,
        bytes: bytes.length < 1024 * 1024
            ? stripAiImageMetadata(bytes, mime)
            : await compute(
                (input) => stripAiImageMetadata(input.$1, input.$2),
                (bytes, mime),
              ),
      );
    }
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null) throw const AiFailure(AiErrorCode.image);
        return AiInputImage(
          id: id,
          mimeType: 'image/png',
          bytes: data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ),
        );
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  } on Object {
    throw const AiFailure(AiErrorCode.image);
  }
}

Uint8List stripAiImageMetadata(Uint8List bytes, String mimeType) =>
    switch (mimeType) {
      'image/gif' => _stripGifMetadata(bytes),
      'image/png' => _stripPngMetadata(bytes),
      'image/webp' => _stripWebpMetadata(bytes),
      'image/jpeg' => _stripJpegMetadata(bytes),
      _ => throw const FormatException('不支援的圖片格式'),
    };

Uint8List _stripGifMetadata(Uint8List bytes) {
  final output = BytesBuilder(copy: false);
  if (sniffKnownMediaMimeType(bytes) != 'image/gif' || bytes.length < 13) {
    throw const FormatException('無效圖片');
  }
  var cursor = 13 + ((bytes[10] & 0x80) != 0 ? 3 * (2 << (bytes[10] & 7)) : 0);
  if (cursor > bytes.length) throw const FormatException('無效色盤');
  output.add(bytes.sublist(0, cursor));
  var ended = false;
  while (cursor < bytes.length) {
    final start = cursor;
    final marker = bytes[cursor++];
    if (marker == 0x3b) {
      output.add([marker]);
      ended = true;
      break;
    }
    var keep = true;
    if (marker == 0x2c) {
      if (cursor + 9 > bytes.length) throw const FormatException('無效影格');
      final flags = bytes[cursor + 8];
      cursor += 9;
      if ((flags & 0x80) != 0) cursor += 3 * (2 << (flags & 7));
      cursor++;
    } else if (marker == 0x21) {
      if (cursor >= bytes.length) throw const FormatException('無效延伸資料');
      final label = bytes[cursor++];
      keep = label == 0xf9 || label == 0x01;
      if (label == 0xff && cursor + 12 <= bytes.length) {
        final applicationId = ascii.decode(
          bytes.sublist(cursor + 1, cursor + 12),
          allowInvalid: true,
        );
        keep = applicationId == 'NETSCAPE2.0' || applicationId == 'ANIMEXTS1.0';
      }
    } else {
      throw const FormatException('無效圖片區塊');
    }
    while (true) {
      if (cursor >= bytes.length) throw const FormatException('無效圖片結尾');
      final size = bytes[cursor++];
      cursor += size;
      if (cursor > bytes.length) throw const FormatException('無效圖片區塊');
      if (size == 0) break;
    }
    if (keep) output.add(bytes.sublist(start, cursor));
  }
  if (!ended) throw const FormatException('無效圖片結尾');
  return output.takeBytes();
}

Uint8List _stripPngMetadata(Uint8List bytes) {
  final output = BytesBuilder(copy: false);
  if (sniffKnownMediaMimeType(bytes) != 'image/png') {
    throw const FormatException('無效圖片');
  }
  output.add(bytes.sublist(0, 8));
  var cursor = 8;
  var ended = false;
  while (cursor + 12 <= bytes.length) {
    final chunkLength = ByteData.sublistView(
      bytes,
      cursor,
      cursor + 4,
    ).getUint32(0);
    final end = cursor + 12 + chunkLength;
    if (end > bytes.length) throw const FormatException('無效圖片區塊');
    final chunkType = ascii.decode(bytes.sublist(cursor + 4, cursor + 8));
    if (chunkType == 'eXIf') {
      final orientationExif = _buildOrientationExif(
        Uint8List.sublistView(bytes, cursor + 8, cursor + 8 + chunkLength),
      );
      if (orientationExif != null) {
        final chunk = ByteData(orientationExif.length + 12)
          ..setUint32(0, orientationExif.length);
        final chunkBytes = chunk.buffer.asUint8List();
        chunkBytes.setRange(4, 8, ascii.encode('eXIf'));
        chunkBytes.setRange(8, 8 + orientationExif.length, orientationExif);
        chunk.setUint32(
          8 + orientationExif.length,
          getCrc32(chunkBytes.sublist(4, 8 + orientationExif.length)),
        );
        output.add(chunkBytes);
      }
    } else if (const {
      'IHDR',
      'PLTE',
      'IDAT',
      'IEND',
      'tRNS',
      'cHRM',
      'gAMA',
      'iCCP',
      'sRGB',
      'cICP',
      'mDCV',
      'cLLI',
      'sBIT',
      'bKGD',
      'pHYs',
      'acTL',
      'fcTL',
      'fdAT',
    }.contains(chunkType)) {
      output.add(Uint8List.sublistView(bytes, cursor, end));
    } else if ((bytes[cursor + 4] & 0x20) == 0) {
      throw const FormatException('不支援的必要圖片區塊');
    }
    cursor = end;
    if (chunkType == 'IEND') {
      ended = true;
      break;
    }
  }
  if (!ended) throw const FormatException('無效圖片結尾');
  return output.takeBytes();
}

Uint8List _stripWebpMetadata(Uint8List bytes) {
  final output = BytesBuilder(copy: false);
  if (sniffKnownMediaMimeType(bytes) != 'image/webp') {
    throw const FormatException('無效圖片');
  }
  final chunks = BytesBuilder(copy: false);
  Uint8List? extendedHeader;
  var keptOrientation = false;
  var cursor = 12;
  while (cursor + 8 <= bytes.length) {
    final chunkType = ascii.decode(bytes.sublist(cursor, cursor + 4));
    final chunkLength = ByteData.sublistView(
      bytes,
      cursor + 4,
      cursor + 8,
    ).getUint32(0, Endian.little);
    final end = cursor + 8 + chunkLength + (chunkLength % 2);
    if (end > bytes.length) throw const FormatException('無效圖片區塊');
    if (chunkType == 'EXIF') {
      final orientationExif = _buildOrientationExif(
        Uint8List.sublistView(bytes, cursor + 8, cursor + 8 + chunkLength),
      );
      if (orientationExif != null) {
        final header = ByteData(8)
          ..setUint32(0, 0x45584946)
          ..setUint32(4, orientationExif.length, Endian.little);
        chunks.add(header.buffer.asUint8List());
        chunks.add(orientationExif);
        if (orientationExif.length.isOdd) chunks.add([0]);
        keptOrientation = true;
      }
    } else if (chunkType == 'ANMF') {
      if (chunkLength < 16) throw const FormatException('無效動畫影格');
      final frame = BytesBuilder(copy: false)
        ..add(Uint8List.sublistView(bytes, cursor + 8, cursor + 24));
      var frameCursor = cursor + 24;
      final frameEnd = cursor + 8 + chunkLength;
      while (frameCursor + 8 <= frameEnd) {
        final type = ascii.decode(bytes.sublist(frameCursor, frameCursor + 4));
        final size = ByteData.sublistView(bytes)
            .getUint32(frameCursor + 4, Endian.little);
        final next = frameCursor + 8 + size + size % 2;
        if (next > frameEnd) throw const FormatException('無效動畫區塊');
        if (const {'ALPH', 'VP8 ', 'VP8L'}.contains(type)) {
          frame.add(Uint8List.sublistView(bytes, frameCursor, next));
        }
        frameCursor = next;
      }
      if (frameCursor != frameEnd) throw const FormatException('無效動畫結尾');
      final payload = frame.takeBytes();
      final header = ByteData(8)
        ..setUint32(0, 0x414e4d46)
        ..setUint32(4, payload.length, Endian.little);
      chunks.add(header.buffer.asUint8List());
      chunks.add(payload);
      if (payload.length.isOdd) chunks.add([0]);
    } else if (const {
      'VP8X',
      'ICCP',
      'ANIM',
      'ALPH',
      'VP8 ',
      'VP8L',
    }.contains(chunkType)) {
      final chunk = chunkType == 'VP8X'
          ? Uint8List.fromList(Uint8List.sublistView(bytes, cursor, end))
          : Uint8List.sublistView(bytes, cursor, end);
      if (chunkType == 'VP8X' && chunk.length > 8) {
        chunk[8] &= ~0x0c;
        extendedHeader = chunk;
      }
      chunks.add(chunk);
    }
    cursor = end;
  }
  if (cursor != bytes.length) throw const FormatException('無效圖片結尾');
  if (keptOrientation && extendedHeader != null) extendedHeader[8] |= 0x08;
  final payload = chunks.takeBytes();
  final header = ByteData(12)
    ..setUint32(0, 0x52494646)
    ..setUint32(4, payload.length + 4, Endian.little)
    ..setUint32(8, 0x57454250);
  output.add(header.buffer.asUint8List());
  output.add(payload);
  return output.takeBytes();
}

Uint8List _stripJpegMetadata(Uint8List bytes) {
  final output = BytesBuilder(copy: false);
  if (sniffKnownMediaMimeType(bytes) != 'image/jpeg') {
    throw const FormatException('無效圖片');
  }
  output.add(bytes.sublist(0, 2));
  var cursor = 2;
  var inScan = false;
  var ended = false;
  while (cursor < bytes.length) {
    if (inScan) {
      final start = cursor;
      while (cursor < bytes.length) {
        if (bytes[cursor] != 0xff) {
          cursor++;
          continue;
        }
        if (cursor + 1 >= bytes.length) throw const FormatException('無效掃描資料');
        final marker = bytes[cursor + 1];
        if (marker == 0 || (marker >= 0xd0 && marker <= 0xd7)) {
          cursor += 2;
          continue;
        }
        break;
      }
      output.add(bytes.sublist(start, cursor));
      inScan = false;
    }
    if (cursor + 1 >= bytes.length || bytes[cursor] != 0xff) {
      throw const FormatException('無效圖片標記');
    }
    final start = cursor;
    while (cursor < bytes.length && bytes[cursor] == 0xff) {
      cursor++;
    }
    if (cursor >= bytes.length) throw const FormatException('無效圖片結尾');
    final marker = bytes[cursor++];
    if (marker == 0xd9) {
      output.add([0xff, 0xd9]);
      ended = true;
      break;
    }
    if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
      output.add(bytes.sublist(start, cursor));
      continue;
    }
    if (cursor + 2 > bytes.length) throw const FormatException('無效圖片區塊');
    final segmentLength = (bytes[cursor] << 8) | bytes[cursor + 1];
    final end = cursor + segmentLength;
    if (segmentLength < 2 || end > bytes.length) {
      throw const FormatException('無效圖片區塊');
    }
    if (marker == 0xe1) {
      final orientationExif = _buildOrientationExif(
        Uint8List.sublistView(bytes, cursor + 2, end),
      );
      if (orientationExif != null) {
        final payload = [69, 120, 105, 102, 0, 0, ...orientationExif];
        output.add([
          0xff,
          0xe1,
          (payload.length + 2) >> 8,
          (payload.length + 2) & 0xff,
          ...payload,
        ]);
      }
    } else {
      final isPrivateMetadata =
          (marker >= 0xe2 && marker <= 0xef) || marker == 0xfe;
      final isColorProfile =
          marker == 0xe2 &&
          end - cursor >= 14 &&
          ascii.decode(
                bytes.sublist(cursor + 2, cursor + 14),
                allowInvalid: true,
              ) ==
              'ICC_PROFILE\u0000';
      if (!isPrivateMetadata || isColorProfile) {
        output.add(bytes.sublist(start, end));
      }
    }
    cursor = end;
    if (marker == 0xda) inScan = true;
  }
  if (!ended) throw const FormatException('無效圖片結尾');
  return output.takeBytes();
}

/// 僅重建顯示方向；姓名、GPS、裝置與拍攝時間等原始 EXIF 不會複製。
Uint8List? _buildOrientationExif(Uint8List bytes) {
  var offset = 0;
  if (bytes.length >= 6 &&
      ascii.decode(bytes.sublist(0, 6), allowInvalid: true) ==
          'Exif\u0000\u0000') {
    offset = 6;
  }
  if (bytes.length - offset < 8) return null;
  final data = ByteData.sublistView(bytes, offset);
  final order = data.getUint16(0);
  if (order != 0x4949 && order != 0x4d4d) return null;
  final endian = order == 0x4949 ? Endian.little : Endian.big;
  if (data.getUint16(2, endian) != 42) return null;
  final directoryOffset = data.getUint32(4, endian);
  if (directoryOffset + 2 > data.lengthInBytes) return null;
  final count = data.getUint16(directoryOffset, endian);
  for (var index = 0; index < count; index++) {
    final entry = directoryOffset + 2 + 12 * index;
    if (entry + 12 > data.lengthInBytes) return null;
    if (data.getUint16(entry, endian) != 0x0112 ||
        data.getUint16(entry + 2, endian) != 3 ||
        data.getUint32(entry + 4, endian) != 1) {
      continue;
    }
    final orientation = data.getUint16(entry + 8, endian);
    if (orientation <= 1 || orientation > 8) return null;
    final orientationExif = ByteData(26)
      ..setUint16(0, 0x4949)
      ..setUint16(2, 42, Endian.little)
      ..setUint32(4, 8, Endian.little)
      ..setUint16(8, 1, Endian.little)
      ..setUint16(10, 0x0112, Endian.little)
      ..setUint16(12, 3, Endian.little)
      ..setUint32(14, 1, Endian.little)
      ..setUint16(18, orientation, Endian.little);
    return orientationExif.buffer.asUint8List();
  }
  return null;
}
