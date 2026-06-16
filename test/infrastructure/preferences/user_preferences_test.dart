import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
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
    expect((decoded as Map<String, dynamic>)['image_compress_preset'], 'high');
  });

  test('未知 storage 值 fallback 為 standard', () async {
    await prefsFile.writeAsString('{"image_compress_preset":"unknown"}');

    final UserPreferences reloaded = UserPreferences(storageFile: prefsFile);
    expect(await reloaded.imageCompressPreset, ImageCompressPreset.standard);
  });

  test('ImageCompressPreset.fromStorage 對應各档', () {
    expect(ImageCompressPreset.fromStorage(null), ImageCompressPreset.standard);
    expect(ImageCompressPreset.fromStorage(''), ImageCompressPreset.standard);
    expect(
      ImageCompressPreset.fromStorage('standard'),
      ImageCompressPreset.standard,
    );
    expect(
      ImageCompressPreset.fromStorage('original'),
      ImageCompressPreset.original,
    );
    expect(ImageCompressPreset.fromStorage('high'), ImageCompressPreset.high);
    expect(
      ImageCompressPreset.fromStorage('bogus'),
      ImageCompressPreset.standard,
    );
  });

  test('未設定時 loadPersonalizationPreferences 使用預設值', () async {
    final PersonalizationPreferences loaded = await preferences
        .loadPersonalizationPreferences();

    expect(loaded.imageCompressPreset, ImageCompressPreset.standard);
    expect(loaded.typography, EditorTypographyPreferences.defaults);
    expect(loaded.themeMode, AppThemeModePreference.system);
    expect(loaded.sessionTimeoutMinutes, SessionBackgroundTimeoutMinutes.three);
    expect(loaded.locale, AppLanguage.zhTw);
  });

  test('savePersonalizationPreferences 持久化全部欄位', () async {
    const PersonalizationPreferences value = PersonalizationPreferences(
      imageCompressPreset: ImageCompressPreset.original,
      typography: EditorTypographyPreferences(
        titleFontSize: 24,
        titleLineHeight: 1.5,
        bodyFontSize: 18,
        bodyLineHeight: 2.0,
        bodyParagraphSpacing: 12,
      ),
      themeMode: AppThemeModePreference.dark,
      sessionTimeoutMinutes: SessionBackgroundTimeoutMinutes.ten,
      locale: AppLanguage.en,
    );

    await preferences.savePersonalizationPreferences(value);

    final UserPreferences reloaded = UserPreferences(storageFile: prefsFile);
    final PersonalizationPreferences loaded = await reloaded
        .loadPersonalizationPreferences();
    expect(loaded.imageCompressPreset, value.imageCompressPreset);
    expect(loaded.themeMode, value.themeMode);
    expect(loaded.sessionTimeoutMinutes, value.sessionTimeoutMinutes);
    expect(loaded.locale, value.locale);
    expect(loaded.typography, value.typography.clamped());
  });

  test('editorTypography 非法值 clamp 回合法範圍', () async {
    await prefsFile.writeAsString(
      '{"editor_title_font_size":"999","editor_body_line_height":"0.1"}',
    );

    final EditorTypographyPreferences typography =
        await preferences.editorTypography;
    expect(
      typography.titleFontSize,
      EditorTypographyPreferences.maxTitleFontSize,
    );
    expect(
      typography.bodyLineHeight,
      EditorTypographyPreferences.minBodyLineHeight,
    );
  });

  test('SessionBackgroundTimeoutMinutes.fromStorage 對應各档', () {
    expect(
      SessionBackgroundTimeoutMinutes.fromStorage(null),
      SessionBackgroundTimeoutMinutes.three,
    );
    expect(
      SessionBackgroundTimeoutMinutes.fromStorage('10'),
      SessionBackgroundTimeoutMinutes.ten,
    );
    expect(
      SessionBackgroundTimeoutMinutes.fromStorage('30'),
      SessionBackgroundTimeoutMinutes.ten,
    );
    expect(
      SessionBackgroundTimeoutMinutes.fromStorage('999'),
      SessionBackgroundTimeoutMinutes.three,
    );
  });
}
