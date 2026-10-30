import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show Locale;

import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';

AppLocalizations sessionL10n(Ref ref) {
  final Locale locale = ref
      .read(personalizationPreferencesProvider)
      .maybeWhen(
        data: (PersonalizationPreferences prefs) => prefs.locale.materialLocale,
        orElse: () => appZhLocale,
      );
  return lookupAppLocalizations(locale);
}

Future<AppLocalizations> loadSessionL10n(Ref ref) async {
  final PersonalizationPreferences? prefs = ref
      .read(personalizationPreferencesProvider)
      .maybeWhen(
        data: (PersonalizationPreferences value) => value,
        orElse: () => null,
      );
  if (prefs != null) {
    return lookupAppLocalizations(prefs.locale.materialLocale);
  }
  final AppLanguage? stored = await ref
      .read(userPreferencesProvider)
      .storedAppLocaleOrNull;
  return lookupAppLocalizations(stored?.materialLocale ?? appZhLocale);
}
