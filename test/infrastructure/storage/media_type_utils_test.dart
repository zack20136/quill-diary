import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/storage/shared/media_type_utils.dart';

void main() {
  test('已知圖片格式必須符合實際檔案特徵', () {
    final List<int> png = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

    expect(attachmentContentMatchesMimeType(png, 'image/png'), isTrue);
    expect(attachmentContentMatchesMimeType(png, 'image/jpeg'), isFalse);
    expect(
      attachmentContentMatchesMimeType(<int>[1, 2, 3], 'image/png'),
      isFalse,
    );
  });

  test('文字與 SVG 需為有效 UTF-8 且 SVG 具有根元素', () {
    expect(
      attachmentContentMatchesMimeType(utf8.encode('日記附件'), 'text/plain'),
      isTrue,
    );
    expect(
      attachmentContentMatchesMimeType(
        utf8.encode('<svg></svg>'),
        'image/svg+xml',
      ),
      isTrue,
    );
    expect(
      attachmentContentMatchesMimeType(
        utf8.encode('<html></html>'),
        'image/svg+xml',
      ),
      isFalse,
    );
  });

  test('未知附件格式採保守策略保留', () {
    expect(
      attachmentContentMatchesMimeType(<int>[1, 2, 3], 'application/zip'),
      isTrue,
    );
    expect(
      attachmentContentMatchesMimeType(<int>[
        1,
        2,
        3,
      ], 'application/octet-stream'),
      isTrue,
    );
  });

  test('未知 ftyp brand 不會誤判為 MP4', () {
    final List<int> avif = <int>[0, 0, 0, 24, ...'ftypavif'.codeUnits];

    expect(sniffKnownMediaMimeType(avif), isNull);
    expect(attachmentContentMatchesMimeType(avif, 'video/mp4'), isFalse);
  });
}
