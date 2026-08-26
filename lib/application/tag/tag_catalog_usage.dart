import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/storage/tag_styles_store.dart';

class TagCatalogUsageItem {
  const TagCatalogUsageItem({required this.label, required this.count});
  final String label;
  final int count;
}

Map<String, int> diaryPresenceTagCounts(List<EntryIndexRecord> entries) {
  final Map<String, int> counts = <String, int>{};
  final Map<String, String> labels = <String, String>{};
  for (final EntryIndexRecord entry in entries) {
    final Set<String> seen = <String>{};
    for (final String raw in entry.tags) {
      final String label = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      final String normalized = normalizeText(raw);
      if (label.isEmpty || !seen.add(normalized)) continue;
      counts.update(normalized, (int count) => count + 1, ifAbsent: () => 1);
      labels.putIfAbsent(normalized, () => label);
    }
  }
  return <String, int>{
    for (final MapEntry<String, int> entry in counts.entries)
      labels[entry.key]!: entry.value,
  };
}

List<TagCatalogUsageItem> mergeTagCatalogWithUsage(
  List<TagCatalogItem> catalog,
  Map<String, int> usageByLabel,
) {
  final Map<String, TagCatalogUsageItem> merged = <String, TagCatalogUsageItem>{
    for (final TagCatalogItem item in catalog)
      if (item.normalized.isNotEmpty)
        item.normalized: TagCatalogUsageItem(label: item.label, count: 0),
  };
  for (final MapEntry<String, int> entry in usageByLabel.entries) {
    final String label = entry.key.trim().replaceAll(RegExp(r'\s+'), ' ');
    final String normalized = normalizeText(label);
    if (normalized.isEmpty) continue;
    merged[normalized] = TagCatalogUsageItem(
      label: merged[normalized]?.label ?? label,
      count: entry.value,
    );
  }
  return merged.values.toList(growable: false)
    ..sort((TagCatalogUsageItem a, TagCatalogUsageItem b) {
      final int byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.label.compareTo(b.label);
    });
}

List<TagCatalogUsageItem> rankedTagUsageFromEntries(
  List<EntryIndexRecord> entries, {
  int limit = 8,
}) => mergeTagCatalogWithUsage(
  const <TagCatalogItem>[],
  diaryPresenceTagCounts(entries),
).take(limit).toList(growable: false);
