import 'package:flutter/material.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';
export 'package:flutter/widgets.dart' show BuildContext;

const Locale appZhTwLocale = Locale.fromSubtags(
  languageCode: 'zh',
  scriptCode: 'Hant',
  countryCode: 'TW',
);

const Locale appEnLocale = Locale('en');

const List<Locale> appSupportedLocales = <Locale>[appZhTwLocale, appEnLocale];

extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

List<String> localizedDefaultTagLabels(AppLocalizations l10n) {
  return <String>[
    l10n.defaultTagDaily,
    l10n.defaultTagMood,
    l10n.defaultTagReflection,
    l10n.defaultTagPlanning,
    l10n.defaultTagWork,
    l10n.defaultTagStudy,
    l10n.defaultTagFamily,
    l10n.defaultTagFriends,
    l10n.defaultTagTravel,
    l10n.defaultTagFood,
    l10n.defaultTagEntertainment,
    l10n.defaultTagExercise,
    l10n.defaultTagHealth,
    l10n.defaultTagShopping,
  ];
}
