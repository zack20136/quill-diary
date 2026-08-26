import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/tag/tag_catalog_usage.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/storage/tag_styles_store.dart';

import '../../helpers/shared/entry_index_fixtures.dart';

void main() {
  test('同篇重複標籤只計一次並合併大小寫與留白', () {
    final List<EntryIndexRecord> entries = <EntryIndexRecord>[
      buildEntryIndexRecord(id: 'a', tags: const <String>[' Flutter ', 'flutter']),
      buildEntryIndexRecord(id: 'b', tags: const <String>['FLUTTER', '生活']),
    ];

    expect(diaryPresenceTagCounts(entries), <String, int>{
      'Flutter': 2,
      '生活': 1,
    });
  });

  test('目錄項目會保留零次使用並以次數及名稱排序', () {
    final List<TagCatalogUsageItem> items = mergeTagCatalogWithUsage(
      const <TagCatalogItem>[
        TagCatalogItem(label: '未使用'),
        TagCatalogItem(label: '生活'),
      ],
      <String, int>{'工作': 3, '生活': 3},
    );

    expect(
      items.map((TagCatalogUsageItem item) => (item.label, item.count)),
      <(String, int)>[('工作', 3), ('生活', 3), ('未使用', 0)],
    );
  });
}
