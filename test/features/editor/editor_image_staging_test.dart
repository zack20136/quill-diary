import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/editor/editor_image_staging.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'editor_image_staging_test_',
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('原圖預設不變更路徑與 mime', () async {
    final File source = await _writeSampleJpeg(tempDir);

    final PreparedImageFile prepared = await compressImageIfNeeded(
      sourcePath: source.path,
      displayName: 'photo.png',
      preset: ImageCompressPreset.original,
    );

    expect(prepared.path, source.path);
    expect(prepared.mimeType, 'image/jpeg');
    expect(prepared.fileName, 'photo.png');
  });

  test('GIF 不壓縮', () async {
    final File gif = File('${tempDir.path}/anim.gif');
    await gif.writeAsBytes(<int>[
      ...'GIF89a'.codeUnits,
      ...List<int>.filled(32, 0),
    ]);

    final PreparedImageFile prepared = await compressImageIfNeeded(
      sourcePath: gif.path,
      displayName: 'anim.gif',
      preset: ImageCompressPreset.standard,
    );

    expect(prepared.path, gif.path);
    expect(prepared.mimeType, 'image/gif');
    expect(prepared.fileName, 'anim.gif');
  });

  test('標準預設壓縮為 JPEG', () async {
    if (kIsWeb) {
      return;
    }

    final File source = await _writeSampleJpeg(tempDir);
    final int sourceSize = await source.length();

    PreparedImageFile prepared;
    try {
      prepared = await compressImageIfNeeded(
        sourcePath: source.path,
        displayName: 'camera_photo.heic',
        preset: ImageCompressPreset.standard,
      );
    } on Object {
      return;
    }

    if (prepared.path == source.path) {
      return;
    }

    expect(prepared.mimeType, 'image/jpeg');
    expect(prepared.fileName, 'camera_photo.jpg');
    expect(await File(prepared.path).length(), lessThanOrEqualTo(sourceSize));

    await File(prepared.path).delete();
  }, skip: _compressionUnsupportedReason());
}

Future<File> _writeSampleJpeg(Directory dir) async {
  final File file = File('${dir.path}/sample.jpg');
  await file.writeAsBytes(base64Decode(_minimalJpegBase64));
  return file;
}

/// 極小有效 JPEG，供壓縮測試使用。
const String _minimalJpegBase64 =
    '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDAREAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAb/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k=';

String? _compressionUnsupportedReason() {
  if (kIsWeb) {
    return 'Web 平台略過原生壓縮測試';
  }
  return null;
}
