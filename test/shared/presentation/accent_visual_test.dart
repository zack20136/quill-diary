import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';

double _colorDistance(Color a, Color b) {
  final double dr = a.r - b.r;
  final double dg = a.g - b.g;
  final double db = a.b - b.b;
  return math.sqrt(dr * dr + dg * dg + db * db);
}

void main() {
  test('共用色盤固定包含二十個指定色並維持順序', () {
    expect(
      kAccentColorPresets.map(colorArgb32),
      <int>[
        0xFFBF6760,
        0xFFC47A88,
        0xFFCC8A98,
        0xFFCC8C74,
        0xFFCC9A5E,
        0xFFC4A256,
        0xFFB0A262,
        0xFF8EAA6A,
        0xFF62A87C,
        0xFF54A890,
        0xFF4EA196,
        0xFF559AAC,
        0xFF5C94B8,
        0xFF5480B0,
        0xFF6874B0,
        0xFF786CB0,
        0xFF8C66AC,
        0xFFA666A0,
        0xFF968876,
        0xFF748494,
      ],
    );
  });

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

  test('ARGB 轉換與 preset 判斷使用完整三十二位元色值', () {
    const Color preset = Color(0xFF62A87C);

    expect(colorArgb32(preset), 0xFF62A87C);
    expect(accentMatchesPreset(preset), isTrue);
    expect(accentMatchesPreset(const Color(0x8062A87C)), isFalse);
    expect(accentMatchesPreset(const Color(0xFF010203)), isFalse);
  });

  test('穩定字串每次映射到相同 preset 且空字串使用第一色', () {
    final Color first = accentColorForStableKey('person-123');

    expect(accentColorForStableKey('person-123'), first);
    expect(accentMatchesPreset(first), isTrue);
    expect(accentColorForStableKey(''), kAccentColorPresets.first);
  });

  test('邊框由原始 Accent 與指定透明度及寬度產生', () {
    const Color accent = Color(0xFF8C66AC);

    expect(
      accentBorderColor(accent),
      accent.withValues(alpha: kAccentBorderAlpha),
    );
    expect(
      accentBorderSide(accent, alpha: 0.4, width: 1.25),
      BorderSide(color: accent.withValues(alpha: 0.4), width: 1.25),
    );
  });
}
