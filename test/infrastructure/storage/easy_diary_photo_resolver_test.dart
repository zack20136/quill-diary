import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/infrastructure/storage/import/easy_diary/easy_diary_photo_resolver.dart';
import 'package:quill_diary/infrastructure/storage/import/easy_diary/easy_diary_realm_entry.dart';

/// 1×1 透明 PNG。
final Uint8List _validPngBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Easy Diary 相片以內容優先，並略過無法解碼的圖片', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'easy_diary_photo_resolver_',
    );
    try {
      final cases = [
        (
          name: 'valid.png',
          bytes: _validPngBytes,
          realmMimeType: 'image/jpeg',
          expected: 'image/png',
        ),
        (
          name: 'header-only',
          bytes: <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
          realmMimeType: 'image/png',
          expected: null,
        ),
        (
          name: 'invalid.png',
          bytes: <int>[1, 2, 3],
          realmMimeType: 'image/png',
          expected: null,
        ),
        (
          name: 'unknown',
          bytes: <int>[4, 5, 6],
          realmMimeType: null,
          expected: null,
        ),
      ];

      for (final testCase in cases) {
        await File(
          p.join(directory.path, testCase.name),
        ).writeAsBytes(testCase.bytes);
      }
      final EasyDiaryPhotoIndex index = EasyDiaryPhotoIndex.scan(directory);

      for (final testCase in cases) {
        final ResolvedEasyDiaryAttachments result =
            await resolveEasyDiaryPhotoAttachments(
              photos: <EasyDiaryPhotoRef>[
                EasyDiaryPhotoRef(
                  photoKey: testCase.name,
                  mimeType: testCase.realmMimeType,
                ),
              ],
              photoIndex: index,
            );
        if (testCase.expected case final String expected) {
          expect(result.attachments, hasLength(1));
          expect(result.attachments.single.mimeType, expected);
        } else {
          expect(result.attachments, isEmpty);
          expect(result.skippedAttachments, 1);
        }
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('canDecodeImageBytes 接受完整 PNG、拒絕截斷檔', () async {
    expect(await canDecodeImageBytes(_validPngBytes), isTrue);
    expect(
      await canDecodeImageBytes(const <int>[
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]),
      isFalse,
    );
  });
}
