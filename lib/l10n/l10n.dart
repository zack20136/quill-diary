import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/app_localizations.dart';

export 'package:flutter/widgets.dart' show BuildContext;
export 'package:quill_diary/l10n/app_localizations.dart';

/// 繁體中文（台灣）；避免裸 `Locale('zh')` 被框架解析成簡體。
const Locale appZhLocale = Locale('zh', 'TW');

const Locale appEnLocale = Locale('en');

const List<Locale> appSupportedLocales = <Locale>[appZhLocale, appEnLocale];

/// gen-l10n 仍把 Material／Cupertino delegate 指到 `flutter_localizations`。
/// App 改用獨立套件的 delegate，避免和 `material_ui` 的本地化型別對不上。
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ];

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

extension AppLanguageVisual on AppLanguage {
  Locale get materialLocale => switch (this) {
    AppLanguage.zh => appZhLocale,
    AppLanguage.en => appEnLocale,
  };
}

AppLanguage appLanguageFromDeviceLocale(Locale locale) {
  if (locale.languageCode == 'zh') {
    return AppLanguage.zh;
  }
  return AppLanguage.en;
}
