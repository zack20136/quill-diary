import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';

void main() {
  test('色盤色塊顯示完整 Accent，不使用混色背景', () {
    const Color accent = Color(0xFF62A87C);
    const Color surface = Color(0xFF12161F);

    final colors = accentColorsFor(accent, surface);

    expect(accentSwatchColor(accent), accent);
    expect(accentSwatchColor(accent), isNot(colors.background));
    expect(colors.accent, accent);
    expect(
      _contrast(accentOnSwatchColor(accent), accent),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('自訂色文字對比不足時保留色標並改用可辨識字色', () {
    const accent = Color(0xFF384552);
    final colors = accentColorsFor(accent, const Color(0xFF222A34));
    expect(colors.accent, accent);
    expect(colors.foreground, isNot(accent));
    expect(
      _contrast(colors.foreground, colors.background),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('亮色標籤文字帶入自訂色相，且在不同表面維持對比', () {
    const accent = Color(0xFF7FC0C8);
    for (final surface in [const Color(0xFFF1F4FA), const Color(0xFF283444)]) {
      final label = accentForegroundColor(accent, surface);
      expect(label.b, greaterThan(label.r));
      expect(_contrast(label, surface), greaterThanOrEqualTo(4.5));

      final colors = accentColorsFor(accent, surface);
      expect(colors.foreground.b, greaterThan(colors.foreground.r));
      expect(
        _contrast(colors.foreground, colors.background),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('帶透明度的顏色不算 preset', () {
    const Color preset = Color(0xFF62A87C);

    expect(accentMatchesPreset(preset), isTrue);
    expect(accentMatchesPreset(const Color(0x8062A87C)), isFalse);
    expect(accentMatchesPreset(const Color(0xFF010203)), isFalse);
  });
}

double _contrast(Color foreground, Color background) {
  final luminances = [
    foreground.computeLuminance(),
    background.computeLuminance(),
  ]..sort();
  return (luminances.last + 0.05) / (luminances.first + 0.05);
}
