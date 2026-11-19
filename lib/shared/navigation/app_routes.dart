enum SettingsEntryAction { focusUnlockMethod, focusExternalRestore }

abstract final class AppRoutes {
  static const String homeRoute = '/';
  static const String editorRoute = '/editor';
  static const String editorDetailRoute = '/editor/:entryId';
  static const String personDetailRoute = '/people/:id';
  static const String personaRoute = '/persona/:personId';
  static String personaLocation(String personId) => '/persona/$personId';
  static const String settingsRoute = '/settings';
  static const String aboutRoute = '/settings/about';
  static const String personalizationRoute = '/settings/personalization';
  static const String supportRoute = '/settings/support';
  static const String chatDiaryRoutePrefix = '/chat-diary';
  static const String diaryOrganizationRoutePrefix = '/diary-organization';
  static String diaryOrganizationLocation(String entryId) =>
      '$diaryOrganizationRoutePrefix/$entryId';
  static String chatDiaryLocation(String id) => '$chatDiaryRoutePrefix/$id';
  static String newChatDiaryLocation(String id) =>
      '$chatDiaryRoutePrefix/new/$id';
  static String chatDiaryEntryLocation(String entryId) =>
      '$chatDiaryRoutePrefix/entry/$entryId';

  static String personDetailLocation(String id) => '/people/$id';

  static String editorSalvageLocation(String token) => '/editor?salvage=$token';
}
