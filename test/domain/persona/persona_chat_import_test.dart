import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

void main() {
  test('LINE 日期跨午夜、多行與引用範圍保留，媒體不成為文字材料', () {
    final chat = parsePersonaLineChat(
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
      () => parsePersonaLineChat(
        '隨便貼的文字',
        vaultId: 'vault',
        personId: generatePersonId(),
        personaId: generatePersonaId(),
      ),
      throwsFormatException,
    );
  });
}
