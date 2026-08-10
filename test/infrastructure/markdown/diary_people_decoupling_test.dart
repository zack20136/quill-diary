import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/markdown/front_matter_codec.dart';

void main() {
  test('日記 front matter 不包含人物欄位或人物 ID', () {
    final DateTime now = DateTime.utc(2026, 8, 10);
    final String markdown = const FrontMatterCodec().encode(
      DiaryEntry(
        id: 'ent_decoupled',
        vaultId: 'vlt_test',
        date: const DateOnly('2026-08-10'),
        createdAt: now,
        updatedAt: now,
        markdownBody: '一般日記正文',
      ),
    );
    final Map<String, Object?> frontMatter = const FrontMatterCodec()
        .decodeDocument(markdown)
        .frontMatter;

    expect(frontMatter.keys, isNot(contains('person_id')));
    expect(frontMatter.keys, isNot(contains('person_ids')));
    expect(frontMatter.keys, isNot(contains('people')));
    expect(frontMatter.keys, isNot(contains('persons')));
  });
}
