import 'package:flutter/material.dart';

import '../../domain/people/person.dart';
import '../../domain/shared/value_objects.dart';
import 'accent_visual.dart';

/// 優先使用自訂色；未自訂時仍依人物 ID 穩定映射既有色盤。
Color personAccentColor(Person person) => person.accentArgb == null
    ? defaultPersonAccentColor(person.id)
    : Color(person.accentArgb!);

/// 將頭貼底色預先混合到指定表面，避免同一透明色在不同頁面背景上看起來不一致。
Color personAvatarBackgroundColor(Person person, Color surface) =>
    accentColorPair(personAccentColor(person), surface).$1;

/// 人物標籤沿用人物管理頁頭像的底色與前景色，避免不同畫面各自轉色。
(Color, Color) personLabelColorPair(Person person, Color surface) =>
    accentColorPair(personAccentColor(person), surface);

/// 依人物 ID 穩定選色，確保未自訂顏色的人物每次顯示一致。
Color defaultPersonAccentColor(PersonId personId) {
  return accentColorForStableKey(personId);
}

/// 取姓名前 1–2 個可見字元作為頭像縮寫。
String personInitials(String name) {
  final String trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  final List<int> runes = trimmed.runes.toList(growable: false);
  final int first = runes.first;
  final bool cjk =
      (first >= 0x4E00 && first <= 0x9FFF) ||
      (first >= 0x3400 && first <= 0x4DBF);
  if (cjk || runes.length == 1) {
    return String.fromCharCode(first);
  }
  final List<String> parts = trimmed
      .split(RegExp(r'\s+'))
      .where((String p) => p.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    final String a = String.fromCharCode(parts[0].runes.first);
    final String b = String.fromCharCode(parts[1].runes.first);
    return '$a$b'.toUpperCase();
  }
  if (runes.length >= 2) {
    return String.fromCharCodes(runes.take(2)).toUpperCase();
  }
  return String.fromCharCode(first).toUpperCase();
}
