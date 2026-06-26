import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import '../../domain/shared/value_objects.dart';
import '../../shared/presentation/tag_visual.dart';
import '../../l10n/l10n.dart';
import 'vault_path_strategy.dart';

class TagCatalogItem {
  const TagCatalogItem({
    required this.label,
    this.accentArgb,
    this.accentIsCustom,
  });

  final String label;
  final int? accentArgb;
  final bool? accentIsCustom;

  String get displayLabel => label.trim().replaceAll(RegExp(r'\s+'), ' ');

  String get normalized => normalizeText(displayLabel);

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'label': displayLabel,
      if (accentArgb != null) 'accent_argb': accentArgb,
      if (accentIsCustom != null) 'accent_is_custom': accentIsCustom,
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
      accentIsCustom: _parseBool(raw['accent_is_custom']),
    );
  }

  static bool? _parseBool(Object? value) {
    if (value is bool) {
      return value;
    }
    return null;
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

List<TagCatalogItem> defaultTagCatalogFor(AppLocalizations l10n) {
  final List<String> labels = localizedDefaultTagLabels(l10n);
  final List<int> defaultAccents = defaultTagAccentArgbs();
  assert(
    labels.length == defaultAccents.length,
    'localizedDefaultTagLabels (${labels.length}) 與 kDefaultTagAccentPresets (${defaultAccents.length}) 數量必須一致',
  );
  return List<TagCatalogItem>.generate(
    labels.length,
    (int index) => TagCatalogItem(
      label: labels[index],
      accentArgb: defaultAccents[index],
      accentIsCustom: false,
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
    final File file = File(await _filePath());
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
}
