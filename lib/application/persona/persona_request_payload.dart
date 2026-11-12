import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_privacy.dart';

String personaGenerationData({
  required String subject,
  required Map<String, String> baseline,
  required List<Object?> materials,
}) => jsonEncode({
  'subject': subject,
  'current_cards': baseline,
  'materials': materials,
});

String personaExtractionData({
  required String subject,
  required List<Object?> fragment,
}) => jsonEncode({'subject': subject, 'fragment': fragment});

int personaRequestLength(String instructions, String data) =>
    instructions.length + data.length;

List<List<Object?>> personaExtractionBatches(
  Iterable<Object?> materials, {
  required String subject,
  required String instructions,
}) {
  final budget = math.min(
    // 單段材料送出時會包在 fragment 陣列裡，需扣掉陣列的 [ ] 兩個字元。
    PersonaLimits.pieceCodeUnits - 2,
    PersonaLimits.requestCodeUnits -
        personaRequestLength(
          instructions,
          personaExtractionData(subject: subject, fragment: const []),
        ),
  );
  if (budget < 0) throw const FormatException('材料的固定欄位超過請求上限');
  final batches = <List<Object?>>[];
  var batch = <Object?>[];
  var length = 0;
  for (final material in materials) {
    for (final piece in _personaBatchPieces(material, budget)) {
      final size = jsonEncode(piece).length;
      if (batch.isNotEmpty && length + 1 + size > budget) {
        batches.add(batch);
        batch = [];
        length = 0;
      }
      if (batch.isNotEmpty) length++;
      batch.add(piece);
      length += size;
    }
  }
  if (batch.isNotEmpty) batches.add(batch);
  return batches;
}

List<Object?> _personaBatchPieces(Object? material, int budget) {
  int remainingBudget(Object? piece) => budget - jsonEncode(piece).length;

  if (remainingBudget(material) >= 0) return [material];
  if (material is! Map) {
    return _splitText('$material', remainingBudget(''));
  }
  final map = material.map((key, value) => MapEntry(key.toString(), value));
  final text = map['text'] as String? ?? '';
  final style = map['style_text'] as String?;
  final empty = <String, Object?>{
    ...map,
    'text': '',
    if (style != null) 'style_text': '',
  };
  final textBudget = remainingBudget(empty);
  if (textBudget < 0) throw const FormatException('材料的固定欄位超過請求上限');
  return [
    if (text.isNotEmpty)
      for (final part in _splitText(text, textBudget)) {...empty, 'text': part},
    if (style != null && style.isNotEmpty)
      for (final part in _splitText(style, textBudget))
        {...empty, 'style_text': part},
  ];
}

final _atomicTextPattern = RegExp(
  '${personaTokenPattern.pattern}|${RegExp.escape(personaHiddenText)}',
);

Iterable<String> _textUnits(String text) sync* {
  final matches = _atomicTextPattern.allMatches(text).iterator;
  var hasMatch = matches.moveNext();
  var cursor = 0;
  var start = 0;
  var protectedEnd = 0;
  for (final character in text.characters) {
    cursor += character.length;
    while (hasMatch && matches.current.start < cursor) {
      protectedEnd = matches.current.end;
      hasMatch = matches.moveNext();
    }
    if (cursor >= protectedEnd) {
      yield text.substring(start, cursor);
      start = cursor;
    }
  }
}

List<String> _splitText(String text, int budget) {
  if (budget < 0) throw const FormatException('材料的固定欄位超過請求上限');
  final parts = <String>[];
  var part = StringBuffer();
  var length = 0;
  for (final unit in _textUnits(text)) {
    // JSON 字串的跳脫長度可逐單位相加，外層引號已包含在固定欄位中。
    final size = jsonEncode(unit).length - 2;
    if (size > budget) throw const FormatException('單一字元或代號超過請求上限');
    if (length + size > budget) {
      parts.add(part.toString());
      part = StringBuffer();
      length = 0;
    }
    part.write(unit);
    length += size;
  }
  if (part.isNotEmpty || parts.isEmpty) parts.add(part.toString());
  return parts;
}
