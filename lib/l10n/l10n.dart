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

/// Material 和 Cupertino delegate 必須與目前 UI 套件的型別一致。
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

extension AppLanguageLocalization on AppLanguage {
  Locale get flutterLocale => switch (this) {
    AppLanguage.zh => appZhLocale,
    AppLanguage.en => appEnLocale,
  };
}

AppLocalizations localizationsFor(AppLanguage language) =>
    lookupAppLocalizations(language.flutterLocale);

AppLanguage appLanguageFromDeviceLocale(Locale locale) {
  if (locale.languageCode == 'zh') {
    return AppLanguage.zh;
  }
  return AppLanguage.en;
}
