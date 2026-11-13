import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

void main() {
  test('LINE 日期跨午夜、多行與引用範圍保留，媒體不成為文字材料', () {
    final chat = parsePersonaChat(
      '[LINE] 匯出\n2026/11/05（四）\n23:59\t小明\t晚安\n> 他人的話\n2026/11/06（五）\n00:01\t我\t早安\n00:02\t小明\t[貼圖]\n不應接到上一位說話者',
      vaultId: 'vault',
      personId: generatePersonId(),
      personaId: generatePersonaId(),
    );
    expect(chat.messages.length, 2);
    expect(chat.messages.first.sentAtLocal, '2026-11-05T23:59:00');
    expect(chat.messages.last.sentAtLocal, '2026-11-06T00:01:00');
    expect(chat.messages.last.text, '早安');
    expect(chat.messages.first.quoteRanges, hasLength(1));
    expect(
      chat.speakers.every(
        (speaker) => speaker.role == PersonaSpeakerRole.unknown,
      ),
      isTrue,
    );
    final restored = PersonaChatImport.fromJson(chat.toJson());
    expect(restored.messages.first.text, contains('他人的話'));
    expect(
      () => parsePersonaChat(
        '隨便貼的文字',
        vaultId: 'vault',
        personId: generatePersonId(),
        personaId: generatePersonaId(),
      ),
      throwsFormatException,
    );
  });

  test('LINE 上午下午換成 24 小時，貼圖與照片不成為文字', () {
    final chat = parsePersonaChat(
      '[LINE] 測試群組的聊天記錄\n'
      '儲存日期： 2026/11/13 13:30\n'
      '\n'
      '2026/11/10（二）\n'
      '上午09:12\t小美\t早安～\n'
      '上午09:13\t阿哲\t早安！今天要做什麼？\n'
      '上午09:15\t小美\t要不要一起吃飯？\n'
      '上午09:18\t阿哲\t[貼圖]\n'
      '上午09:20\t小美\t[照片]\n'
      '下午12:10\t小美\t中午\n'
      '下午01:05\t阿哲\t下午見\n'
      '\n'
      '2026/11/11（三）\n'
      '上午12:01\t小美\t明天有空嗎？\n'
      '上午10:03\t阿哲\t有啊！\n',
      vaultId: 'vault',
      personId: generatePersonId(),
      personaId: generatePersonaId(),
    );
    expect(chat.messages.map((message) => message.sentAtLocal), [
      '2026-11-10T09:12:00',
      '2026-11-10T09:13:00',
      '2026-11-10T09:15:00',
      '2026-11-10T12:10:00',
      '2026-11-10T13:05:00',
      '2026-11-11T00:01:00',
      '2026-11-11T10:03:00',
    ]);
    expect(chat.messages.map((message) => message.text), [
      '早安～',
      '早安！今天要做什麼？',
      '要不要一起吃飯？',
      '中午',
      '下午見',
      '明天有空嗎？',
      '有啊！',
    ]);
  });

  test('LINE 桌面空白分隔、引號多行與無法辨識行仍可匯入', () {
    final report = parsePersonaChatReport(
      '[LINE] 匯出\n'
      '2026.07.31 Friday\n'
      '亂掉的一行\n'
      '09:00 Alice "line one\n'
      'line two"\n'
      '午前09:12\t小美\t早\n'
      '午後01:05\t小美\t午\n'
      '09:30 AM\tAnn\thi\n'
      '01:05 PM\tAnn\tbye\n'
      '25:99\t小美\t不該留下\n'
      '09:40\t小美\t您已收回訊息\n'
      '09:41\t阿哲已收回訊息\n',
      vaultId: 'vault',
      personId: generatePersonId(),
      personaId: generatePersonaId(),
    );
    expect(report.skippedLines, 2);
    expect(report.chat.messages.map((message) => message.text), [
      'line one\nline two',
      '早',
      '午',
      'hi',
      'bye',
    ]);
    expect(report.chat.messages.map((message) => message.sentAtLocal), [
      '2026-07-31T09:00:00',
      '2026-07-31T09:12:00',
      '2026-07-31T13:05:00',
      '2026-07-31T09:30:00',
      '2026-07-31T13:05:00',
    ]);
    expect(report.chat.messages.first.speakerId, isNotNull);
    expect(report.chat.speakers.map((speaker) => speaker.label), [
      'Alice',
      '小美',
      'Ann',
    ]);
  });

  test('完全沒有 LINE 訊息仍失敗', () {
    expect(
      () => parsePersonaChat(
        '2026/11/10（二）\n亂掉的一行\n',
        vaultId: 'vault',
        personId: generatePersonId(),
        personaId: generatePersonaId(),
      ),
      throwsFormatException,
    );
  });

  test('Messenger 一般匯出修復亂碼、改為由舊到新，並略過附件與已收回訊息', () {
    final garbledName = latin1.decode(utf8.encode('小明'));
    final garbledText = latin1.decode(utf8.encode('嗨'));
    final older = 1710466867000;
    final newer = older + 60000;
    final chat = _parse(
      jsonEncode({
        'participants': [
          {'name': garbledName},
        ],
        'messages': [
          {
            'sender_name': garbledName,
            'timestamp_ms': newer,
            'content': garbledText,
            'photos': [
              {'uri': 'photo.jpg'},
            ],
          },
          {
            'sender_name': garbledName,
            'timestamp_ms': newer + 1000,
            'photos': [
              {'uri': 'only-photo.jpg'},
            ],
          },
          {
            'sender_name': garbledName,
            'timestamp_ms': older,
            'content': latin1.decode(utf8.encode('早')),
            'isUnsent': true,
          },
          {'sender_name': 'Pat', 'timestamp_ms': older, 'content': 'hello'},
        ],
      }),
    );

    expect(chat.messages.map((message) => message.text), ['hello', '嗨']);
    expect(chat.messages.first.sentAtLocal, _localSentAt(older));
    expect(chat.messages.last.sentAtLocal, _localSentAt(newer));
    expect(chat.speakers.map((speaker) => speaker.label), ['Pat', '小明']);
  });

  test('Messenger 加密備份不修復文字，並與一般匯出合併去重', () {
    const millis = 1710466867000;
    final garbled = latin1.decode(utf8.encode('嗨'));
    final encrypted = jsonEncode({
      'participants': ['小明', 'Pat'],
      'threadName': '小明_1',
      'messages': [
        {
          'senderName': '小明',
          'text': '嗨',
          'timestamp': millis,
          'type': 'text',
          'isUnsent': false,
          'media': [],
        },
        {
          'senderName': 'Pat',
          'text': 'only encrypted',
          'timestamp': millis + 1000,
          'type': 'text',
          'isUnsent': false,
          'media': [],
        },
      ],
    });
    final standard = jsonEncode({
      'messages': [
        {
          'sender_name': latin1.decode(utf8.encode('小明')),
          'timestamp_ms': millis,
          'content': latin1.decode(utf8.encode('嗨')),
        },
        {
          'sender_name': 'Pat',
          'timestamp_ms': millis - 1000,
          'content': 'only standard',
        },
      ],
    });
    final alone = _parse(
      jsonEncode({
        'messages': [
          {
            'senderName': '小明',
            'text': garbled,
            'timestamp': millis,
            'type': 'text',
            'isUnsent': false,
          },
        ],
      }),
    );
    expect(alone.messages.single.text, garbled);

    final merged = _parseAll([standard, encrypted]);
    expect(merged.messages.map((message) => message.text), [
      'only standard',
      '嗨',
      'only encrypted',
    ]);
    expect(merged.speakers.map((speaker) => speaker.label).toSet(), {
      'Pat',
      '小明',
    });
  });

  test('Instagram 與 Messenger 一般匯出共用結構，ChatLab 不再內建解析', () {
    final instagram = _parse(
      jsonEncode({
        'messages': [
          {
            'sender_name': latin1.decode(utf8.encode('小明')),
            'timestamp_ms': 1710466867000,
            'content': latin1.decode(utf8.encode('私訊')),
          },
        ],
      }),
    );
    expect(instagram.messages.single.text, '私訊');

    expect(
      () => _parse(
        jsonEncode({
          'chatlab': {'version': '0.0.2'},
          'members': [
            {'platformId': 'u1', 'accountName': '小明'},
          ],
          'messages': [
            {
              'sender': 'u1',
              'accountName': '小明',
              'timestamp': 1710466867,
              'type': 0,
              'content': '文字',
            },
          ],
        }),
      ),
      throwsFormatException,
    );
  });

  test('原文匯入保留全文與隱藏區間，不產生訊息或日期', () {
    final personId = generatePersonId();
    final chat = PersonaChatImport.raw(
      vaultId: 'vault',
      personId: personId,
      personaId: generatePersonaId(),
      text: '小明：明天見\n地址在這',
      speakers: [
        PersonaImportSpeaker(
          id: 'named-s1',
          label: '小明',
          role: PersonaSpeakerRole.personaSubject,
        ),
      ],
      hidden: const [PrivateTextRange(6, 10)],
    );
    final restored = PersonaChatImport.fromJson(
      jsonDecode(jsonEncode(chat.toJson())) as Map<String, dynamic>,
    );
    expect(restored.isRaw, isTrue);
    expect(restored.messages, isEmpty);
    expect(restored.rawText, chat.rawText);
    expect(restored.rawHidden.single.start, 6);
    expect(restored.speakers.single.role, PersonaSpeakerRole.personaSubject);
    expect(
      restored.messagesInWindow(PersonaChatSource(importId: restored.importId)),
      isEmpty,
    );
    expect(restored.toJson()['kind'], 'raw');
    expect(chat.toJson().containsKey('kind'), isTrue);
  });

  test('無法辨識的 JSON 不會當成聊天', () {
    expect(() => _parse('{"hello":true}'), throwsFormatException);
  });
}

PersonaChatImport _parse(String input) => parsePersonaChat(
  input,
  vaultId: 'vault',
  personId: generatePersonId(),
  personaId: generatePersonaId(),
);

PersonaChatImport _parseAll(List<String> inputs) {
  final personId = generatePersonId();
  final personaId = generatePersonaId();
  return combinePersonaChatReports(
    [
      for (final input in inputs)
        parsePersonaChatReport(
          input,
          vaultId: 'vault',
          personId: personId,
          personaId: personaId,
        ),
    ],
    vaultId: 'vault',
    personId: personId,
    personaId: personaId,
  ).chat;
}

String _localSentAt(int milliseconds) {
  final local = DateTime.fromMillisecondsSinceEpoch(
    milliseconds,
    isUtc: true,
  ).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-'
      '${two(local.month)}-${two(local.day)}T'
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}
