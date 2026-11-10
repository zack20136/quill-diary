import 'dart:convert';

import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/persona/persona_request_payload.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_privacy.dart';

void main() {
  test('長材料的正文與風格各自成段，不會按編號配在一起', () {
    final pieces = personaBatchPieces(
      {'source': 'line', 'text': '正' * 8000, 'style_text': '風' * 3000},
      subject: '主題',
      instructions: '提取證據',
    ).cast<Map>();
    expect(pieces.length, greaterThan(1));
    expect(
      pieces.every((piece) => piece['text'] == '' || piece['style_text'] == ''),
      isTrue,
    );
    expect(pieces.map((piece) => piece['text']).join(), '正' * 8000);
    expect(pieces.map((piece) => piece['style_text']).join(), '風' * 3000);
  });

  for (final map in [false, true]) {
    test('${map ? '原始材料' : '中間摘要'}依 JSON 跳脫長度切段並保留字元與完整標記', () {
      const unit = '"\\\n\t👩🏽‍💻é⟦P01⟧́$personaHiddenText';
      final text = unit * 1000;
      final instructions = '提取' * 5000;
      final pieces = personaBatchPieces(
        map ? {'source': 'diary', 'text': text} : text,
        subject: '測試"主題',
        instructions: instructions,
      );
      expect(pieces.length, greaterThan(1));
      final boundaries = <int>{0};
      var offset = 0;
      for (final character in text.characters) {
        offset += character.length;
        boundaries.add(offset);
      }
      var cursor = 0;
      for (final piece in pieces) {
        final part = map ? (piece as Map)['text'] as String : piece as String;
        cursor += part.length;
        expect(boundaries, contains(cursor));
        for (final marker in ['⟦P01⟧', personaHiddenText]) {
          final occurrence = text.lastIndexOf(marker, cursor - 1);
          expect(
            occurrence < 0 || occurrence + marker.length <= cursor,
            isTrue,
          );
        }
        expect(
          jsonEncode(piece).length,
          lessThanOrEqualTo(PersonaLimits.pieceCodeUnits),
        );
        expect(
          personaRequestLength(
            instructions,
            personaExtractionData(subject: '測試"主題', fragment: piece),
          ),
          lessThanOrEqualTo(PersonaLimits.requestCodeUnits),
        );
      }
      expect(pieces.map((p) => map ? (p as Map)['text'] : p).join(), text);
    });
  }

  test('剛好可容納的片段不拆分，多一個字元才分段', () {
    final instructions = '指令' * 6000;
    const subject = '主題';
    final budget =
        PersonaLimits.requestCodeUnits -
        personaRequestLength(
          instructions,
          personaExtractionData(subject: subject, fragment: ''),
        );
    final exact = '文' * budget;
    expect(
      personaBatchPieces(exact, subject: subject, instructions: instructions),
      [exact],
    );
    final pieces = personaBatchPieces(
      '$exact文',
      subject: subject,
      instructions: instructions,
    );
    expect(pieces, [exact, '文']);
  });

  test('固定欄位或單一完整標記無法容納時拒絕拆段，不截斷內容', () {
    expect(
      () => personaBatchPieces(
        {'text': '正文', 'source': '欄位' * PersonaLimits.requestCodeUnits},
        subject: '主題',
        instructions: '指令',
      ),
      throwsFormatException,
    );
    final instructions =
        '指' *
        (PersonaLimits.requestCodeUnits -
            personaExtractionData(subject: '主題', fragment: '').length -
            1);
    expect(
      () => personaBatchPieces(
        '⟦P01⟧',
        subject: '主題',
        instructions: instructions,
      ),
      throwsFormatException,
    );
  });
}
