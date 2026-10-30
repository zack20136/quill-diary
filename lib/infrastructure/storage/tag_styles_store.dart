import 'dart:convert';
import 'dart:io';

import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/domain/tag/tag.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';

/// 在 [vault/tag_styles.json] 持久化標籤目錄，使預設與未使用標籤在備份／還原後保留。
class TagStylesStore {
  TagStylesStore(this._pathStrategy);

  final VaultPathStrategy _pathStrategy;

  Future<List<TagCatalogItem>> read() async {
    final File file = File(await _pathStrategy.tagStylesPath());
    if (!file.existsSync()) {
      return const <TagCatalogItem>[];
    }
    try {
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is! List<Object?>) {
        await _deleteCatalogFile(file);
        return const <TagCatalogItem>[];
      }

      final List<TagCatalogItem> items = _normalizeItems(
        decoded
            .map(TagCatalogItem.fromJson)
            .whereType<TagCatalogItem>()
            .toList(growable: false),
      );
      if (items.isEmpty) {
        await _deleteCatalogFile(file);
        return const <TagCatalogItem>[];
      }
      return items;
    } on Object {
      await _deleteCatalogFile(file);
      return const <TagCatalogItem>[];
    }
  }

  Future<void> _deleteCatalogFile(File file) async {
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<void> write(List<TagCatalogItem> items) async {
    final File file = File(await _pathStrategy.tagStylesPath());
    await file.parent.create(recursive: true);
    final List<TagCatalogItem> normalized = _normalizeItems(items);
    final List<Map<String, Object?>> payload = normalized
        .map((TagCatalogItem item) => item.toJson())
        .toList(growable: false);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }

  static Map<String, int> toAccentMap(List<TagCatalogItem> items) {
    return <String, int>{
      for (final TagCatalogItem item in _normalizeItems(items))
        if (item.accentArgb != null) item.normalized: item.accentArgb!,
    };
  }

  /// 後面的項目覆寫較早的鍵。
  static List<TagCatalogItem> merge(
    List<TagCatalogItem> base,
    List<TagCatalogItem> overlay,
  ) {
    return _normalizeItems(<TagCatalogItem>[...base, ...overlay]);
  }

  static List<TagCatalogItem> _normalizeItems(List<TagCatalogItem> items) {
    final Map<String, int> indexByNorm = <String, int>{};
    final List<TagCatalogItem> normalized = <TagCatalogItem>[];

    for (final TagCatalogItem item in items) {
      final String normalizedKey = item.normalized;
      if (normalizedKey.isEmpty) {
        continue;
      }
      final int? existingIndex = indexByNorm[normalizedKey];
      if (existingIndex == null) {
        indexByNorm[normalizedKey] = normalized.length;
        normalized.add(
          TagCatalogItem(
            label: item.displayLabel,
            accentArgb: item.accentArgb,
            accentIsCustom: item.accentIsCustom,
          ),
        );
        continue;
      }
      final TagCatalogItem previous = normalized[existingIndex];
      normalized[existingIndex] = TagCatalogItem(
        label: item.displayLabel,
        accentArgb: item.accentArgb ?? previous.accentArgb,
        accentIsCustom: item.accentIsCustom ?? previous.accentIsCustom,
      );
    }

    return normalized;
  }

  Future<void> ensureLabels(Iterable<String> labels) async {
    final Set<String> seenNormalized = <String>{};
    final List<TagCatalogItem> overlay = <TagCatalogItem>[];
    for (final String raw in labels) {
      final String displayLabel = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      final String normalized = normalizeText(displayLabel);
      if (normalized.isEmpty || !seenNormalized.add(normalized)) {
        continue;
      }
      overlay.add(TagCatalogItem(label: displayLabel));
    }
    if (overlay.isEmpty) {
      return;
    }
    final List<TagCatalogItem> catalog = await read();
    await write(TagStylesStore.merge(catalog, overlay));
  }

  Future<void> applyToIndex(IndexDatabase indexDb) async {
    final List<TagCatalogItem> catalog = await read();
    if (catalog.isEmpty) {
      return;
    }
    for (final TagCatalogItem item in catalog) {
      if (item.accentArgb == null) {
        continue;
      }
      await indexDb.upsertTagAccentArgb(item.label, item.accentArgb!);
    }
  }
}
