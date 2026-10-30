import 'dart:ui';

import 'package:quill_diary/domain/shared/accent_palette.dart';
import 'package:quill_diary/domain/tag/tag.dart';
import 'package:quill_diary/l10n/l10n.dart';

const List<int> _defaultTagPresetIndexes = <int>[
  18, // 日常：褐
  1, // 心情：玫紅
  10, // 心得：青綠
  13, // 筆記：藍
  15, // 反思：紫
  5, // 靈感：琥珀
  12, // 計畫：天藍
  0, // 目標：紅
  19, // 工作：灰藍
  8, // 學習：綠
  17, // 人際：洋紅
  4, // 家庭：橘
  9, // 健康：翠綠
  6, // 感謝：金黃
];

List<TagCatalogItem> defaultTagCatalogFor(AppLocalizations l10n) {
  final List<String> labels = localizedDefaultTagLabels(l10n);
  final List<int> defaultAccents = _defaultTagPresetIndexes
      .map((int index) => accentArgbPresets[index])
      .toList(growable: false);
  assert(
    labels.length == defaultAccents.length,
    'localizedDefaultTagLabels (${labels.length}) 與預設標籤配色 (${defaultAccents.length}) 數量必須一致',
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
