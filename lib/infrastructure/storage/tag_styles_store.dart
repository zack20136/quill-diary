import 'dart:convert';
import 'dart:io';

import '../../domain/shared/value_objects.dart';
import 'vault_path_strategy.dart';

class TagCatalogItem {
  const TagCatalogItem({
    required this.label,
    this.accentArgb,
  });

  final String label;
  final int? accentArgb;

  String get displayLabel => label.trim().replaceAll(RegExp(r'\s+'), ' ');

  String get normalized => normalizeText(displayLabel);

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'label': displayLabel,
      if (accentArgb != null) 'accent_argb': accentArgb,
    };
  }

  static TagCatalogItem? fromJson(Object? raw) {
    if (raw is! Map<Object?, Object?>) {
      return null;
    }
    final String label = '${raw['label'] ?? ''}'.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (label.isEmpty) {
      return null;
    }
    return TagCatalogItem(
      label: label,
      accentArgb: _parseArgb(raw['accent_argb']),
    );
  }

  static int? _parseArgb(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}

const List<TagCatalogItem> kDefaultTagCatalog = <TagCatalogItem>[
  TagCatalogItem(label: '日常', accentArgb: 0xFF748091),
  TagCatalogItem(label: '心情', accentArgb: 0xFFD6336C),
  TagCatalogItem(label: '反思', accentArgb: 0xFF7950F2),
  TagCatalogItem(label: '計畫', accentArgb: 0xFF4C6EF5),
  TagCatalogItem(label: '工作', accentArgb: 0xFF339AF0),
  TagCatalogItem(label: '學習', accentArgb: 0xFF15AABF),
  TagCatalogItem(label: '家庭', accentArgb: 0xFFFF922B),
  TagCatalogItem(label: '朋友', accentArgb: 0xFFF783AC),
  TagCatalogItem(label: '旅遊', accentArgb: 0xFF20C997),
  TagCatalogItem(label: '美食', accentArgb: 0xFFFCC419),
  TagCatalogItem(label: '娛樂', accentArgb: 0xFFA855F7),
  TagCatalogItem(label: '運動', accentArgb: 0xFF51CF66),
  TagCatalogItem(label: '健康', accentArgb: 0xFF69DB7C),
  TagCatalogItem(label: '購物', accentArgb: 0xFFFF6B6B),
];

/// Persists tag catalog under [vault/tag_styles.json] so predefined and unused
/// tags survive backup/restore.
class TagStylesStore {
  TagStylesStore(this._pathStrategy);

  final VaultPathStrategy _pathStrategy;

  static const int schemaVersion = 1;

  Future<String> _filePath() async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    return '${vaultRoot.path}${Platform.pathSeparator}tag_styles.json';
  }

  Future<List<TagCatalogItem>> read() async {
    final File file = File(await _filePath());
    if (!file.existsSync()) {
      return const <TagCatalogItem>[];
    }
    try {
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) {
        return const <TagCatalogItem>[];
      }

      final Object? rawTags = decoded['tags'];
      if (rawTags is! List<Object?>) {
        return const <TagCatalogItem>[];
      }

      return _normalizeItems(
        rawTags.map(TagCatalogItem.fromJson).whereType<TagCatalogItem>().toList(growable: false),
      );
    } on Object {
      return const <TagCatalogItem>[];
    }
  }

  Future<void> write(List<TagCatalogItem> items) async {
    final File file = File(await _filePath());
    await file.parent.create(recursive: true);
    final List<TagCatalogItem> normalized = _normalizeItems(items);
    final Map<String, Object?> payload = <String, Object?>{
      'version': schemaVersion,
      'tags': normalized.map((TagCatalogItem item) => item.toJson()).toList(growable: false),
    };
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

  /// Later entries override earlier keys.
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
          ),
        );
        continue;
      }
      final TagCatalogItem previous = normalized[existingIndex];
      normalized[existingIndex] = TagCatalogItem(
        label: item.displayLabel,
        accentArgb: item.accentArgb ?? previous.accentArgb,
      );
    }

    return normalized;
  }
}
