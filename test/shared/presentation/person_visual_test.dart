import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/shared/presentation/person_visual.dart';

void main() {
  test('人物標籤沿用人物管理頁頭像的底色與前景色', () {
    final DateTime now = DateTime(2026);
    final Person person = Person(
      id: 'person-1',
      name: '小明',
      accentArgb: 0xFF5480B0,
      createdAt: now,
      updatedAt: now,
    );
    const Color accent = Color(0xFF5480B0);
    const Color surface = Color(0xFFF5F2ED);
    final Color expectedBackground = Color.alphaBlend(
      accent.withValues(alpha: 0.18),
      surface,
    );

    final (Color background, Color foreground) = personLabelColorPair(
      person,
      surface,
    );

    expect(background, expectedBackground);
    expect(foreground, accent);
  });
}
