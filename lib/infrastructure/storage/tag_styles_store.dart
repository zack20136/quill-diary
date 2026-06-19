import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import '../../domain/shared/value_objects.dart';
import '../../l10n/l10n.dart';
import 'vault_path_strategy.dart';

class TagCatalogItem {
  const TagCatalogItem({required this.label, this.accentArgb});

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
    final String label = '${raw['label'] ?? ''}'.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
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

const List<int> kDefaultTagAccents = <int>[
  0xFF748091,
  0xFFD6336C,
  0xFF7950F2,
  0xFF4C6EF5,
  0xFF7048E8,
  0xFFA855F7,
  0xFF339AF0,
  0xFF15AABF,
  0xFF228BE6,
  0xFF20C997,
  0xFFF783AC,
  0xFFFF922B,
  0xFF51CF66,
  0xFFFCC419,
];

List<TagCatalogItem> defaultTagCatalogFor(AppLocalizations l10n) {
  final List<String> labels = localizedDefaultTagLabels(l10n);
  return List<TagCatalogItem>.generate(
    labels.length,
    (int index) => TagCatalogItem(
      label: labels[index],
      accentArgb: kDefaultTagAccents[index],
    ),
    growable: false,
  );
}

List<TagCatalogItem> defaultTagCatalogForLocale(Locale locale) {
  final AppLocalizations l10n = lookupAppLocalizations(locale);
  return defaultTagCatalogFor(l10n);
}

/// 在 [vault/tag_styles.json] 持久化標籤目錄，使預設與未使用標籤在備份／還原後保留。
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
        rawTags
            .map(TagCatalogItem.fromJson)
            .whereType<TagCatalogItem>()
            .toList(growable: false),
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
      'tags': normalized
          .map((TagCatalogItem item) => item.toJson())
          .toList(growable: false),
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
          TagCatalogItem(label: item.displayLabel, accentArgb: item.accentArgb),
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
