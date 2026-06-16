import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/infrastructure/storage/import/easy_diary/easy_diary_photo_resolver.dart';

void main() {
  test('可解析無副檔名的 UUID 相片檔', () {
    final Directory tempDir = Directory.systemTemp.createTempSync(
      'easy_photo_index_',
    );
    final String uuid = 'fe3121ef-e13e-41dd-a7c4-3f860786ff74';
    File(
      p.join(tempDir.path, uuid),
    ).writeAsBytesSync(<int>[0xFF, 0xD8, 0xFF, 0x00]);

    final EasyDiaryPhotoIndex index = EasyDiaryPhotoIndex.scan(tempDir);
    final File? resolved = index.resolve(uuid);
    expect(resolved, isNotNull);
    expect(p.basename(resolved!.path), uuid);

    final String mime = sniffImageMimeType(
      Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF]),
      fileNameHint: uuid,
    );
    expect(mime, 'image/jpeg');
    tempDir.deleteSync(recursive: true);
  });

  test('可移除內文中的 UUID 占位行', () {
    const String uuid = 'fe3121ef-e13e-41dd-a7c4-3f860786ff74';
    final String stripped = stripEasyDiaryPhotoPlaceholderLines(
      '段落一\n$uuid\n段落二',
      <String>{uuid},
    );
    expect(stripped, '段落一\n段落二');
  });
}
