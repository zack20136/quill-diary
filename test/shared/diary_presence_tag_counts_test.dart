import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/shared/utils/diary_presence_tag_counts.dart';

import '../helpers/entry_index_fixtures.dart';

void main() {
  test('同篇重複 tag 只計一次', () {
    final Map<String, int> counts = diaryPresenceTagCounts(<EntryIndexRecord>[
      buildEntryIndexRecord(
        id: 'jrn_1',
        tags: const <String>['生活', '生活', ' 生活 '],
      ),
    ]);

    expect(counts['生活'], 1);
    expect(counts.length, 1);
  });

  test('大小寫與空白正規化後合併', () {
    final Map<String, int> counts = diaryPresenceTagCounts(<EntryIndexRecord>[
      buildEntryIndexRecord(
        id: 'jrn_1',
        tags: const <String>['Work'],
      ),
      buildEntryIndexRecord(
        id: 'jrn_2',
        tags: const <String>['  work  '],
      ),
    ]);

    expect(counts.length, 1);
    expect(counts.values.single, 2);
  });

  test('空 tag 略過', () {
    final Map<String, int> counts = diaryPresenceTagCounts(<EntryIndexRecord>[
      buildEntryIndexRecord(
        id: 'jrn_1',
        tags: const <String>['', '   '],
      ),
    ]);

    expect(counts, isEmpty);
  });
}
