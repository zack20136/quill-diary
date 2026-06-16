import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';

void main() {
  test('fromStorage 使用預設值', () {
    expect(
      EditorTypographyPreferences.fromStorage(
        titleFontSize: null,
        titleLineHeight: null,
        bodyFontSize: null,
        bodyLineHeight: null,
      ),
      EditorTypographyPreferences.defaults,
    );
  });

  test('clamped 限制超出範圍的值', () {
    const EditorTypographyPreferences raw = EditorTypographyPreferences(
      titleFontSize: 10,
      titleLineHeight: 3,
      bodyFontSize: 30,
      bodyLineHeight: 0.5,
      bodyParagraphSpacing: 99,
    );

    final EditorTypographyPreferences clamped = raw.clamped();
    expect(clamped.titleFontSize, EditorTypographyPreferences.minTitleFontSize);
    expect(
      clamped.titleLineHeight,
      EditorTypographyPreferences.maxTitleLineHeight,
    );
    expect(clamped.bodyFontSize, EditorTypographyPreferences.maxBodyFontSize);
    expect(
      clamped.bodyLineHeight,
      EditorTypographyPreferences.minBodyLineHeight,
    );
    expect(
      clamped.bodyParagraphSpacing,
      EditorTypographyPreferences.maxBodyParagraphSpacing,
    );
  });

  test('copyWith 合併並 clamp', () {
    final EditorTypographyPreferences updated = EditorTypographyPreferences
        .defaults
        .copyWith(bodyFontSize: 20, bodyParagraphSpacing: 16);
    expect(updated.bodyFontSize, 20);
    expect(updated.bodyParagraphSpacing, 16);
    expect(
      updated.titleFontSize,
      EditorTypographyPreferences.defaultTitleFontSize,
    );
  });

  test('isAtDefaults 辨識預設與自訂排版', () {
    expect(EditorTypographyPreferences.defaults.isAtDefaults, isTrue);
    expect(
      EditorTypographyPreferences.defaults
          .copyWith(bodyFontSize: 18)
          .isAtDefaults,
      isFalse,
    );
  });
}
