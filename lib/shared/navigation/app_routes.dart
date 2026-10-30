/// 設定頁初始定位目標；不自動執行建立金鑰、選檔或登入。
enum SettingsFocusTarget {
  recoveryKey,
  externalRestore;

  static const String queryKey = 'focus';

  String get queryValue => name;

  static SettingsFocusTarget? tryParse(String? raw) {
    return switch (raw?.trim()) {
      'recoveryKey' => SettingsFocusTarget.recoveryKey,
      'externalRestore' => SettingsFocusTarget.externalRestore,
      _ => null,
    };
  }
}

abstract final class AppRoutes {
  static const String homeRoute = '/';
  static const String editorRoute = '/editor';
  static const String editorDetailRoute = '/editor/:entryId';
  static const String personDetailRoute = '/people/:id';
  static const String settingsRoute = '/settings';
  static const String aboutRoute = '/settings/about';
  static const String personalizationRoute = '/settings/personalization';
  static const String supportRoute = '/settings/support';
  static const String chatDiaryRoutePrefix = '/chat-diary';
  static String chatDiaryLocation(String id) => '$chatDiaryRoutePrefix/$id';
  static String newChatDiaryLocation(String id) =>
      '$chatDiaryRoutePrefix/new/$id';
  static String chatDiaryEntryLocation(String entryId) =>
      '$chatDiaryRoutePrefix/entry/$entryId';

  static String personDetailLocation(String id) => '/people/$id';

  static String editorSalvageLocation(String token) => '/editor?salvage=$token';

  static String settingsLocation({SettingsFocusTarget? focus}) {
    if (focus == null) {
      return settingsRoute;
    }
    return '$settingsRoute?${SettingsFocusTarget.queryKey}=${focus.queryValue}';
  }
}
