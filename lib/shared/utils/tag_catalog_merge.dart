import '../../domain/shared/value_objects.dart';
import '../../infrastructure/database/index_database.dart';
import '../../infrastructure/storage/tag_styles_store.dart';
import 'diary_presence_tag_counts.dart';

class TagCatalogUsageItem {
  const TagCatalogUsageItem({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;
}

List<TagCatalogUsageItem> mergeTagCatalogWithUsage(
  List<TagCatalogItem> catalog,
  Map<String, int> usageByLabel,
) {
  final Map<String, TagCatalogUsageItem> merged = <String, TagCatalogUsageItem>{};

  for (final TagCatalogItem item in catalog) {
    if (item.normalized.isEmpty) {
      continue;
    }
    merged[item.normalized] = TagCatalogUsageItem(label: item.label, count: 0);
  }

  for (final MapEntry<String, int> entry in usageByLabel.entries) {
    final String label = entry.key.trim().replaceAll(RegExp(r'\s+'), ' ');
    final String normalized = normalizeText(label);
    if (normalized.isEmpty) {
      continue;
    }
    final TagCatalogUsageItem? existing = merged[normalized];
    merged[normalized] = TagCatalogUsageItem(
      label: existing?.label ?? label,
      count: entry.value,
    );
  }

  return _sortTagUsageItems(merged.values);
}

/// 依日記索引計算熱門標籤（不含未出現在目錄／日記中的項目）。
List<TagCatalogUsageItem> rankedTagUsageFromEntries(
  List<EntryIndexRecord> entries, {
  int limit = 8,
}) {
  return mergeTagCatalogWithUsage(
    const <TagCatalogItem>[],
    diaryPresenceTagCounts(entries),
  ).take(limit).toList(growable: false);
}

List<TagCatalogUsageItem> _sortTagUsageItems(Iterable<TagCatalogUsageItem> items) {
  return items.toList(growable: false)
    ..sort((TagCatalogUsageItem a, TagCatalogUsageItem b) {
      final int byCount = b.count.compareTo(a.count);
      if (byCount != 0) {
        return byCount;
      }
      return a.label.compareTo(b.label);
    });
}
