import 'dart:convert';

import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/persona/persona_request_payload.dart';
import 'package:quill_diary/domain/ai/ai_request.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../helpers/ai/ai_test_helpers.dart';
import '../../helpers/shared/test_l10n.dart';

void main() {
  test('長材料的正文與風格各自成段，不會按編號配在一起', () {
    final pieces = personaExtractionBatches(
      [
        {'source': 'chat', 'text': '正' * 8000, 'style_text': '風' * 3000},
      ],
      subject: '主題',
      instructions: '提取證據',
    ).expand((batch) => batch).cast<Map>();
    expect(pieces.length, greaterThan(1));
    expect(
      pieces.every((piece) => piece['text'] == '' || piece['style_text'] == ''),
      isTrue,
    );
    expect(pieces.map((piece) => piece['text']).join(), '正' * 8000);
    expect(pieces.map((piece) => piece['style_text']).join(), '風' * 3000);
  });

  for (final l10n in [testZhL10n, testEnL10n]) {
    for (final map in [false, true]) {
      test(
        '${isEnglishL10n(l10n) ? '英文' : '繁體中文'}${map ? '原始材料' : '中間摘要'}依實際外送長度切段並保留字元與完整標記',
        () async {
          const unit = '"\\\n\t👩🏽‍💻é{{PER_01}}́{{PRI_01}}';
          final text = unit * 1000;
          final instructions = '提取' * 5000;
          final batches = personaExtractionBatches(
            [
              map ? {'source': 'diary', 'text': text} : text,
            ],
            subject: '測試"主題',
            instructions: instructions,
          );
          expect(batches.length, greaterThan(1));
          final pieces = batches.expand((batch) => batch).toList();
          final boundaries = <int>{0};
          var offset = 0;
          for (final character in text.characters) {
            offset += character.length;
            boundaries.add(offset);
          }
          var cursor = 0;
          for (final piece in pieces) {
            final part = map
                ? (piece as Map)['text'] as String
                : piece as String;
            cursor += part.length;
            expect(boundaries, contains(cursor));
            for (final marker in ['{{PER_01}}', '{{PRI_01}}']) {
              final occurrence = text.lastIndexOf(marker, cursor - 1);
              expect(
                occurrence < 0 || occurrence + marker.length <= cursor,
                isTrue,
              );
            }
          }
          for (final batch in batches) {
            expect(
              jsonEncode(batch).length,
              lessThanOrEqualTo(PersonaLimits.pieceCodeUnits),
            );
            final request = await prepareAiRequest(
              connection: testChatDiarySession().connectionConfig,
              instructions: instructions,
              messages: [
                AiInputMessage(
                  isUser: true,
                  text: personaExtractionData(
                    subject: '測試"主題',
                    fragment: batch,
                  ),
                ),
              ],
              originals: {'{{PER_01}}': '{{PER_01}}'},
            );
            expect(
              request.systemPrompt.length + request.messages.single.text.length,
              lessThanOrEqualTo(PersonaLimits.requestCodeUnits),
            );
          }
          expect(pieces.map((p) => map ? (p as Map)['text'] : p).join(), text);
        },
      );
    }
  }

  test('剛好可容納的片段不拆分，多一個字元才分段', () {
    final instructions = '指令' * 6000;
    const subject = '主題';
    final budget =
        PersonaLimits.requestCodeUnits -
        personaRequestLength(
          instructions,
          personaExtractionData(subject: subject, fragment: const []),
        ) -
        2;
    final exact = '文' * budget;
    expect(
      personaExtractionBatches(
        [exact],
        subject: subject,
        instructions: instructions,
      ),
      [
        [exact],
      ],
    );
    final batches = personaExtractionBatches(
      ['$exact文'],
      subject: subject,
      instructions: instructions,
    );
    expect(batches, [
      [exact],
      ['文'],
    ]);
  });

  test('相鄰片段依序合批，陣列括號與逗號剛好達上限時仍可送出', () {
    const subject = '測試主題';
    final instructions =
        '指' *
        (PersonaLimits.requestCodeUnits -
            personaExtractionData(
              subject: subject,
              fragment: ['甲', '乙'],
            ).length);
    final batches = personaExtractionBatches(
      ['甲', '乙', '丙'],
      subject: subject,
      instructions: instructions,
    );
    expect(batches, [
      ['甲', '乙'],
      ['丙'],
    ]);
    expect(
      personaRequestLength(
        instructions,
        personaExtractionData(subject: subject, fragment: batches.first),
      ),
      PersonaLimits.requestCodeUnits,
    );
  });

  test('固定欄位或單一完整標記無法容納時拒絕拆段，不截斷內容', () {
    expect(
      () => personaExtractionBatches(
        [
          {'text': '正文', 'source': '欄位' * PersonaLimits.requestCodeUnits},
        ],
        subject: '主題',
        instructions: '指令',
      ),
      throwsFormatException,
    );
    final instructions =
        '指' *
        (PersonaLimits.requestCodeUnits -
            personaExtractionData(subject: '主題', fragment: const []).length -
            3);
    expect(
      () => personaExtractionBatches(
        ['{{PER_01}}'],
        subject: '主題',
        instructions: instructions,
      ),
      throwsFormatException,
    );
  });
}
