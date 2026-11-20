import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_privacy.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';

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

typedef PersonaEvidence = ({PersonaCardKind kind, String text});

class PersonaEvidenceInvalid extends FormatException {
  const PersonaEvidenceInvalid() : super('分身證據的格式或長度不正確');
}

List<PersonaEvidence> decodePersonaEvidence(
  String output, {
  required PersonaUpdateTarget target,
  required PersonaTokenRegistry registry,
  required String requestData,
}) {
  if (output.length > PersonaLimits.evidenceCodeUnits) {
    throw const PersonaEvidenceInvalid();
  }
  Object? decoded;
  try {
    decoded = jsonDecode(output);
  } on FormatException {
    throw const PersonaEvidenceInvalid();
  }
  final kinds = target.kinds;
  if (decoded is! Map || decoded.length != kinds.length) {
    throw const PersonaEvidenceInvalid();
  }
  final evidence = <PersonaEvidence>{};
  for (final kind in kinds) {
    final items = decoded[kind.name];
    if (items is! List ||
        items.any((item) => item is! String || item.trim().isEmpty)) {
      throw const PersonaEvidenceInvalid();
    }
    for (final item in items.cast<String>()) {
      registry.validateOutputTokens(item, requestData);
      final protected = registry.protectEvidence(item);
      registry.validateOutputTokens(protected, requestData);
      evidence.add((kind: kind, text: protected));
    }
  }
  if (encodePersonaEvidence(evidence, target).length >
      PersonaLimits.evidenceCodeUnits) {
    throw const PersonaEvidenceInvalid();
  }
  return evidence.toList();
}

String encodePersonaEvidence(
  Iterable<PersonaEvidence> evidence,
  PersonaUpdateTarget target,
) => jsonEncode({
  for (final kind in target.kinds)
    kind.name: [
      for (final item in evidence)
        if (item.kind == kind) item.text,
    ],
});

Map<String, String> personaEvidenceMaterial(PersonaEvidence evidence) => {
  'evidence_kind': evidence.kind.name,
  'text': evidence.text,
};

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
  if (map.containsKey('evidence_kind')) {
    throw const PersonaEvidenceInvalid();
  }
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

final _atomicTextPattern = privacyTokenPattern;

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
