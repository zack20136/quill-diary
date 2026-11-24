import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';

void main() {
  const codec = FrontMatterCodec();

  test('Markdown 往返保留反斜線、控制字元及正文空白', () {
    final entry = DiaryEntry(
      id: 'entry',
      vaultId: 'vault',
      date: DateOnly.parse('2026-11-23'),
      createdAt: DateTime.utc(2026, 11, 23),
      updatedAt: DateTime.utc(2026, 11, 23),
      title: '  C:\\new\t「日記」🌿\n第二行  ',
      tags: [r'C:\new', '印象\n深刻'],
      markdownBody: '\n    保留縮排  \r\n末尾  \n\n',
    );
    final encoded = codec.encode(entry);
    final restored = codec.decode(encoded);

    expect(restored.title, entry.title);
    expect(restored.tags, entry.tags);
    expect(restored.markdownBody, entry.markdownBody);
    expect(codec.encode(restored), encoded);
  });

  test('舊 CRLF 文件可讀且字串 null 與空值分開', () {
    const document = '---\r\ntitle: "null"\r\n---\r\n\r\n  正文\r\n';
    expect(codec.decode(document).title, 'null');
    expect(codec.decode(document).markdownBody, '  正文\r\n');
    expect(codec.decode('---\ntitle: null\n---\n').title, isNull);
    expect(codec.decode('\n正文  \n').markdownBody, '\n正文  \n');
    expect(
      () => codec.decode('---\ntitle: "C:\\xNOT"\n---\n'),
      throwsFormatException,
    );
  });
}
