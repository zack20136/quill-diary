import 'dart:ui';

import 'package:quill_diary/domain/shared/accent_palette.dart';
import 'package:quill_diary/domain/tag/tag.dart';
import 'package:quill_diary/l10n/l10n.dart';

List<TagCatalogItem> defaultTagCatalogFor(AppLocalizations l10n) => [
  for (final (label, accentIndex) in [
    (l10n.defaultTagDaily, 18),
    (l10n.defaultTagMood, 1),
    (l10n.defaultTagTakeaways, 10),
    (l10n.defaultTagNotes, 13),
    (l10n.defaultTagReflection, 15),
    (l10n.defaultTagIdeas, 5),
    (l10n.defaultTagPlans, 12),
    (l10n.defaultTagGoals, 0),
    (l10n.defaultTagWork, 19),
    (l10n.defaultTagLearning, 8),
    (l10n.defaultTagRelationships, 17),
    (l10n.defaultTagFamily, 4),
    (l10n.defaultTagHealth, 9),
    (l10n.defaultTagGratitude, 6),
  ])
    TagCatalogItem(
      label: label,
      accentArgb: accentArgbPresets[accentIndex],
      accentIsCustom: false,
    ),
];

List<TagCatalogItem> defaultTagCatalogForLocale(Locale locale) {
  final AppLocalizations l10n = lookupAppLocalizations(locale);
  return defaultTagCatalogFor(l10n);
}
