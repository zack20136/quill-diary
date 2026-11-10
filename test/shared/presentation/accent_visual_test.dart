import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';

double _colorDistance(Color a, Color b) {
  final double dr = a.r - b.r;
  final double dg = a.g - b.g;
  final double db = a.b - b.b;
  return math.sqrt(dr * dr + dg * dg + db * db);
}

void main() {
  test('Accent 背景依表面明暗混色且前景保留原色', () {
    const Color accent = Color(0xFF5480B0);
    const Color lightSurface = Color(0xFFF5F2ED);
    const Color darkSurface = Color(0xFF12161F);

    final (Color lightBackground, Color lightForeground) = accentColorPair(
      accent,
      lightSurface,
    );
    final (Color darkBackground, Color darkForeground) = accentColorPair(
      accent,
      darkSurface,
    );

    expect(
      lightBackground,
      Color.lerp(lightSurface, accent, kAccentBackgroundMixLight),
    );
    expect(lightForeground, accent);
    expect(
      darkBackground,
      Color.lerp(darkSurface, accent, kAccentBackgroundMixDark),
    );
    expect(darkForeground, accent);
    expect(
      _colorDistance(darkBackground, accent),
      lessThan(_colorDistance(lightBackground, accent)),
    );
  });

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

  test('穩定字串每次映射到相同 preset 且空字串使用第一色', () {
    final Color first = accentColorForStableKey('person-123');

    expect(accentColorForStableKey('person-123'), first);
    expect(accentMatchesPreset(first), isTrue);
    expect(accentColorForStableKey(''), accentColorPresets.first);
  });
}
