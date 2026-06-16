import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/storage/tag_styles_store.dart';
import 'package:quill_diary/shared/utils/tag_catalog_merge.dart';

import '../helpers/entry_index_fixtures.dart';

void main() {
  test('mergeTagCatalogWithUsage 保留 catalog 標籤並合併使用次數', () {
    final List<TagCatalogUsageItem> merged = mergeTagCatalogWithUsage(
      const <TagCatalogItem>[
        TagCatalogItem(label: '日常', accentArgb: 1),
        TagCatalogItem(label: '工作', accentArgb: 2),
      ],
      <String, int>{'工作': 3, '臨時': 1},
    );

    expect(
      merged
          .map((TagCatalogUsageItem item) => <Object>[item.label, item.count])
          .toList(),
      <List<Object>>[
        <Object>['工作', 3],
        <Object>['臨時', 1],
        <Object>['日常', 0],
      ],
    );
  });

  test('mergeTagCatalogWithUsage 以 catalog 顯示名為準', () {
    final List<TagCatalogUsageItem> merged = mergeTagCatalogWithUsage(
      const <TagCatalogItem>[TagCatalogItem(label: '工作')],
      <String, int>{'工作 ': 2},
    );

    expect(merged.single.label, '工作');
    expect(merged.single.count, 2);
  });

  test('rankedTagUsageFromEntries 依範圍內日記計數', () {
    final List<TagCatalogUsageItem> topTags = rankedTagUsageFromEntries(
      <EntryIndexRecord>[
        buildEntryIndexRecord(tags: const <String>['工作', '日常']),
        buildEntryIndexRecord(
          id: 'jrn_B',
          tags: const <String>['工作'],
          date: const DateOnly('2026-05-02'),
        ),
      ],
      limit: 2,
    );

    expect(
      topTags
          .map((TagCatalogUsageItem item) => <Object>[item.label, item.count])
          .toList(),
      <List<Object>>[
        <Object>['工作', 2],
        <Object>['日常', 1],
      ],
    );
  });
}
