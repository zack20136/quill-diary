import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';

class InMemoryUserPreferences extends UserPreferences {
  InMemoryUserPreferences([this.value = PersonalizationPreferences.defaults]);

  PersonalizationPreferences value;

  @override
  Future<PersonalizationPreferences> loadPersonalizationPreferences() async =>
      value;

  @override
  Future<void> savePersonalizationPreferences(
    PersonalizationPreferences next,
  ) async {
    value = next;
  }

  @override
  Future<AppLanguage> get appLocale async => value.locale;
}
