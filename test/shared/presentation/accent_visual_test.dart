import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';

void main() {
  test('色盤色塊顯示完整 Accent，不使用混色背景', () {
    const Color accent = Color(0xFF62A87C);
    const Color surface = Color(0xFF12161F);

    final (Color chipBackground, Color chipForeground) = accentColorPair(
      accent,
      surface,
    );

    expect(accentSwatchColor(accent), accent);
    expect(accentSwatchColor(accent), isNot(chipBackground));
    expect(accentSwatchColor(accent), chipForeground);
    expect(accentOnSwatchColor(accent), Colors.white);
    expect(
      accentOnSwatchColor(const Color(0xFFE8F5E9)),
      const Color(0xDE000000),
    );
  });

  test('帶透明度的顏色不算 preset', () {
    const Color preset = Color(0xFF62A87C);

    expect(accentMatchesPreset(preset), isTrue);
    expect(accentMatchesPreset(const Color(0x8062A87C)), isFalse);
    expect(accentMatchesPreset(const Color(0xFF010203)), isFalse);
  });
}
