import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';
import 'package:quill_diary/infrastructure/ai/ai_image_preparer.dart';

import '../../helpers/ai/ai_test_helpers.dart';

void main() {
  test('PNG 移除未知私有區塊並保留透明度、色彩與動畫區塊', () {
    final rendering = [
      _pngChunk('sRGB', [0]),
      _pngChunk('tRNS', [0, 0]),
      _pngChunk('acTL', [0, 0, 0, 1, 0, 0, 0, 0]),
      _pngChunk('fcTL', List.filled(26, 0)),
      _pngChunk('fdAT', [0, 0, 0, 0, 1]),
    ].expand((chunk) => chunk).toList();
    final input = Uint8List.fromList([
      ...testAiPng.sublist(0, 33),
      ...rendering,
      ..._pngChunk('caBX', utf8.encode('私人姓名與地點')),
      ..._pngChunk('vpAg', utf8.encode('私人備註')),
      ...testAiPng.sublist(33),
    ]);
    expect(stripAiImageMetadata(input, 'image/png'), [
      ...testAiPng.sublist(0, 33),
      ...rendering,
      ...testAiPng.sublist(33),
    ]);
  });

  test('WebP 移除外層及動畫影格內未知區塊並保留像素與透明度', () {
    final frame = [
      ...List.filled(16, 0),
      ..._webpChunk('ALPH', [1, 2]),
      ..._webpChunk('VP8 ', [3, 4]),
    ];
    final requiredChunks = [
      ..._webpChunk('VP8X', [0x12, ...List.filled(9, 0)]),
      ..._webpChunk('ICCP', [1, 2, 3]),
      ..._webpChunk('ANIM', List.filled(6, 0)),
    ];
    final inputPayload = [
      ...requiredChunks,
      ..._webpChunk('ANMF', [
        ...frame,
        ..._webpChunk('PRIV', utf8.encode('私人影格資訊')),
      ]),
      ..._webpChunk('PRIV', utf8.encode('私人姓名與地點')),
    ];
    final expected = [...requiredChunks, ..._webpChunk('ANMF', frame)];
    final header = ByteData(12)
      ..setUint32(0, 0x52494646)
      ..setUint32(4, inputPayload.length + 4, Endian.little)
      ..setUint32(8, 0x57454250);
    final clean = stripAiImageMetadata(
      Uint8List.fromList([...header.buffer.asUint8List(), ...inputPayload]),
      'image/webp',
    );
    expect(clean.sublist(12), expected);
    expect(
      ByteData.sublistView(clean).getUint32(4, Endian.little),
      clean.length - 8,
    );
  });

  test('大型圖片可在背景處理並保留原始像素', () async {
    final input = Uint8List.fromList([
      ...testAiPng.sublist(0, 33),
      ..._pngChunk('vpAg', List.filled(1024 * 1024, 65)),
      ...testAiPng.sublist(33),
    ]);
    expect((await prepareAiImage('large', input)).bytes, testAiPng);
  });

  test('移除 PNG 文字中繼資料但保留像素區塊與尺寸', () {
    final clean = stripAiImageMetadata(pngWithPrivateMetadata(), 'image/png');
    expect(clean, testAiPng);
    expect(utf8.decode(clean, allowMalformed: true), isNot(contains('私人地址')));
  });
  test('JPEG 移除 EXIF 與註解而不重編碼掃描資料', () {
    final bytes = Uint8List.fromList([
      0xff,
      0xd8,
      0xff,
      0xe1,
      0,
      6,
      1,
      2,
      3,
      4,
      0xff,
      0xfe,
      0,
      4,
      5,
      6,
      0xff,
      0xda,
      0,
      2,
      42,
      0xff,
      0,
      43,
      0xff,
      0xd9,
    ]);
    expect(stripAiImageMetadata(bytes, 'image/jpeg'), [
      0xff,
      0xd8,
      0xff,
      0xda,
      0,
      2,
      42,
      0xff,
      0,
      43,
      0xff,
      0xd9,
    ]);
  });
  test('毀損中繼資料不能回退傳送原始位元組', () async {
    final broken = Uint8List.fromList([
      ...testAiPng.sublist(0, 8),
      0xff,
      0xff,
      0xff,
      0xff,
      1,
      2,
      3,
      4,
    ]);
    await expectLater(prepareAiImage('id', broken), throwsA(isA<AiFailure>()));
  });
  test('JPEG 僅重建必要方向，移除其他 EXIF 且保留原始壓縮像素', () {
    final tiff = _orientationExif();
    final payload = [
      ...ascii.encode('Exif\x00\x00'),
      ...tiff,
      ...utf8.encode('私人地點與姓名'),
    ];
    final scan = [0xff, 0xda, 0, 2, 42, 0xff, 0, 43, 0xff, 0xd9];
    final image = Uint8List.fromList([
      0xff,
      0xd8,
      0xff,
      0xe1,
      0,
      payload.length + 2,
      ...payload,
      ...scan,
    ]);
    final clean = stripAiImageMetadata(image, 'image/jpeg');
    expect(utf8.decode(clean, allowMalformed: true), isNot(contains('私人地點')));
    expect(clean.sublist(clean.length - scan.length), scan);
    expect(clean.sublist(12, 38), tiff);
    expect(stripAiImageMetadata(clean, 'image/jpeg'), clean);
  });
  test('PNG 只留下方向 EXIF，重算 CRC 並保留原本像素區塊', () {
    final orientation = _orientationExif();
    final metadata = [...orientation, ...utf8.encode('私人地點與姓名')];
    final chunk = ByteData(metadata.length + 12)..setUint32(0, metadata.length);
    final chunkBytes = chunk.buffer.asUint8List();
    chunkBytes.setRange(4, 8, ascii.encode('eXIf'));
    chunkBytes.setRange(8, 8 + metadata.length, metadata);
    chunk.setUint32(
      8 + metadata.length,
      getCrc32(chunkBytes.sublist(4, 8 + metadata.length)),
    );
    final image = Uint8List.fromList([
      ...testAiPng.sublist(0, 33),
      ...chunkBytes,
      ...testAiPng.sublist(33),
    ]);
    final clean = stripAiImageMetadata(image, 'image/png');
    expect(clean.sublist(41, 67), orientation);
    expect(
      ByteData.sublistView(clean).getUint32(67),
      getCrc32(clean.sublist(37, 67)),
    );
    expect([...clean.sublist(0, 33), ...clean.sublist(71)], testAiPng);
    expect(utf8.decode(clean, allowMalformed: true), isNot(contains('私人地點')));
  });

  test('WebP 清除 XMP 與私人 EXIF，保留方向並更新標記與 RIFF 長度', () {
    final orientation = _orientationExif();
    final extendedHeader = _webpChunk('VP8X', [
      0x0c,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ]);
    final pixels = _webpChunk('VP8 ', [1, 2, 3, 4]);
    final payload = [
      ...extendedHeader,
      ...pixels,
      ..._webpChunk('EXIF', [...orientation, ...utf8.encode('私人地點與姓名')]),
      ..._webpChunk('XMP ', utf8.encode('私人標籤')),
    ];
    final header = ByteData(12)
      ..setUint32(0, 0x52494646)
      ..setUint32(4, payload.length + 4, Endian.little)
      ..setUint32(8, 0x57454250);
    final clean = stripAiImageMetadata(
      Uint8List.fromList([...header.buffer.asUint8List(), ...payload]),
      'image/webp',
    );
    expect(
      ByteData.sublistView(clean).getUint32(4, Endian.little),
      clean.length - 8,
    );
    expect(clean[20], 0x08);
    expect(clean.sublist(30, 42), pixels);
    expect(clean.sublist(50), orientation);
    expect(utf8.decode(clean, allowMalformed: true), isNot(contains('私人')));
  });

  test('GIF 移除註解與私有應用資料，保留動畫循環、延遲與影格', () {
    final header = [...ascii.encode('GIF89a'), 1, 0, 1, 0, 0, 0, 0];
    final loop = [
      0x21,
      0xff,
      11,
      ...ascii.encode('NETSCAPE2.0'),
      3,
      1,
      0,
      0,
      0,
    ];
    final delay = [0x21, 0xf9, 4, 0, 5, 0, 0, 0];
    final frame = [0x2c, 0, 0, 0, 0, 1, 0, 1, 0, 0, 2, 2, 0x44, 1, 0, 0x3b];
    final secret = utf8.encode('私人地點');
    final image = Uint8List.fromList([
      ...header,
      ...loop,
      0x21,
      0xfe,
      secret.length,
      ...secret,
      0,
      0x21,
      0xff,
      11,
      ...ascii.encode('PRIVATEAPP1'),
      secret.length,
      ...secret,
      0,
      ...delay,
      ...frame,
    ]);
    expect(stripAiImageMetadata(image, 'image/gif'), [
      ...header,
      ...loop,
      ...delay,
      ...frame,
    ]);
  });
}

Uint8List _orientationExif() {
  final exif = ByteData(26)
    ..setUint16(0, 0x4949)
    ..setUint16(2, 42, Endian.little)
    ..setUint32(4, 8, Endian.little)
    ..setUint16(8, 1, Endian.little)
    ..setUint16(10, 0x0112, Endian.little)
    ..setUint16(12, 3, Endian.little)
    ..setUint32(14, 1, Endian.little)
    ..setUint16(18, 6, Endian.little);
  return exif.buffer.asUint8List();
}

Uint8List _pngChunk(String type, List<int> payload) {
  final chunk = ByteData(12 + payload.length)..setUint32(0, payload.length);
  final bytes = chunk.buffer.asUint8List()
    ..setRange(4, 8, ascii.encode(type))
    ..setRange(8, 8 + payload.length, payload);
  chunk.setUint32(
    8 + payload.length,
    getCrc32(bytes.sublist(4, 8 + payload.length)),
  );
  return bytes;
}

Uint8List _webpChunk(String type, List<int> payload) {
  final header = ByteData(8)..setUint32(4, payload.length, Endian.little);
  header.buffer.asUint8List().setRange(0, 4, ascii.encode(type));
  return Uint8List.fromList([
    ...header.buffer.asUint8List(),
    ...payload,
    if (payload.length.isOdd) 0,
  ]);
}
