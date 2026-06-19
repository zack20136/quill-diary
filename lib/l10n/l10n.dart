import 'package:flutter/material.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';
export 'package:flutter/widgets.dart' show BuildContext;

/// 繁體中文（台灣）；避免裸 `Locale('zh')` 被框架解析成簡體。
const Locale appZhLocale = Locale('zh', 'TW');

const Locale appEnLocale = Locale('en');

const List<Locale> appSupportedLocales = <Locale>[appZhLocale, appEnLocale];

extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

bool isEnglishL10n(AppLocalizations l10n) => l10n.localeName == 'en';

List<String> localizedDefaultTagLabels(AppLocalizations l10n) {
  return <String>[
    l10n.defaultTagDaily,
    l10n.defaultTagMood,
    l10n.defaultTagTakeaways,
    l10n.defaultTagNotes,
    l10n.defaultTagReflection,
    l10n.defaultTagIdeas,
    l10n.defaultTagPlans,
    l10n.defaultTagGoals,
    l10n.defaultTagWork,
    l10n.defaultTagLearning,
    l10n.defaultTagRelationships,
    l10n.defaultTagFamily,
    l10n.defaultTagHealth,
    l10n.defaultTagGratitude,
  ];
}
