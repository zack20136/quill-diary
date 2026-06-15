import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';

void main() {
  late Directory tempDir;
  late File prefsFile;
  late UserPreferences preferences;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('user_preferences_test_');
    prefsFile = File('${tempDir.path}/app_preferences.json');
    preferences = UserPreferences(storageFile: prefsFile);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('未設定時預設為 standard', () async {
    expect(await preferences.imageCompressPreset, ImageCompressPreset.standard);
  });

  test('讀寫持久化 imageCompressPreset', () async {
    await preferences.setImageCompressPreset(ImageCompressPreset.high);

    expect(await preferences.imageCompressPreset, ImageCompressPreset.high);

    final UserPreferences reloaded = UserPreferences(storageFile: prefsFile);
    expect(await reloaded.imageCompressPreset, ImageCompressPreset.high);

    final Object? decoded = jsonDecode(await prefsFile.readAsString());
    expect(decoded, isA<Map<String, dynamic>>());
    expect(
      (decoded as Map<String, dynamic>)['image_compress_preset'],
      'high',
    );
  });

  test('未知 storage 值 fallback 為 standard', () async {
    await prefsFile.writeAsString('{"image_compress_preset":"unknown"}');

    final UserPreferences reloaded = UserPreferences(storageFile: prefsFile);
    expect(await reloaded.imageCompressPreset, ImageCompressPreset.standard);
  });

  test('ImageCompressPreset.fromStorage 對應各档', () {
    expect(ImageCompressPreset.fromStorage(null), ImageCompressPreset.standard);
    expect(ImageCompressPreset.fromStorage(''), ImageCompressPreset.standard);
    expect(ImageCompressPreset.fromStorage('standard'), ImageCompressPreset.standard);
    expect(ImageCompressPreset.fromStorage('original'), ImageCompressPreset.original);
    expect(ImageCompressPreset.fromStorage('high'), ImageCompressPreset.high);
    expect(ImageCompressPreset.fromStorage('bogus'), ImageCompressPreset.standard);
  });
}
