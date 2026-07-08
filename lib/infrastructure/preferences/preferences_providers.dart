import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_preferences.dart';

final userPreferencesProvider = Provider<UserPreferences>((Ref ref) {
  return UserPreferences();
});
