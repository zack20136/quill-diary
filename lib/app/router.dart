import 'package:go_router/go_router.dart';

import '../domain/chat_diary/chat_diary_session.dart';
import '../presentation/chat_diary/chat_diary_page.dart';
import '../presentation/editor/pages/editor_page.dart';
import '../presentation/home/pages/home_page.dart';
import '../presentation/people/pages/person_detail_page.dart';
import '../presentation/settings/pages/about_page.dart';
import '../presentation/settings/pages/personalization_page.dart';
import '../presentation/settings/pages/settings_page.dart';
import '../presentation/settings/pages/support_page.dart';

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

/// 集中定義全站路由與頁面入口。
class AppRouter {
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

  static String editorEditLocation(String entryId) => '/editor/$entryId?edit=1';
  static String editorSalvageLocation(String token) => '/editor?salvage=$token';

  static String settingsLocation({SettingsFocusTarget? focus}) {
    if (focus == null) {
      return settingsRoute;
    }
    return '$settingsRoute?${SettingsFocusTarget.queryKey}=${focus.queryValue}';
  }

  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: homeRoute,
      routes: <RouteBase>[
        GoRoute(path: homeRoute, builder: (_, _) => const HomePage()),
        GoRoute(
          path: '$chatDiaryRoutePrefix/entry/:entryId',
          builder: (_, state) {
            final entryId = state.pathParameters['entryId'] ?? '';
            return RegExp(r'^jrn_[0-9A-HJKMNP-TV-Z]{26}$').hasMatch(entryId)
                ? ChatDiaryPage(entryId: entryId)
                : const HomePage();
          },
        ),
        GoRoute(
          path: '$chatDiaryRoutePrefix/new/:id',
          builder: (_, state) =>
              ChatDiarySession.isValidId(state.pathParameters['id'] ?? '')
              ? ChatDiaryPage(
                  chatId: state.pathParameters['id']!,
                  isNewChat: true,
                )
              : const HomePage(),
        ),
        GoRoute(
          path: '$chatDiaryRoutePrefix/:id',
          builder: (_, state) =>
              ChatDiarySession.isValidId(state.pathParameters['id'] ?? '')
              ? ChatDiaryPage(chatId: state.pathParameters['id']!)
              : const HomePage(),
        ),
        GoRoute(
          path: editorRoute,
          builder: (_, GoRouterState state) => EditorPage(
            salvageToken: state.uri.queryParameters['salvage'],
            chatId:
                ChatDiarySession.isValidId(
                  state.uri.queryParameters['chat'] ?? '',
                )
                ? state.uri.queryParameters['chat']
                : null,
            startInEditMode:
                state.uri.queryParameters['salvage'] != null ||
                state.uri.queryParameters['chat'] != null,
          ),
        ),
        GoRoute(
          path: editorDetailRoute,
          builder: (_, GoRouterState state) => EditorPage(
            entryId: state.pathParameters['entryId'],
            startInEditMode: state.uri.queryParameters['edit'] == '1',
          ),
        ),
        GoRoute(
          path: personDetailRoute,
          builder: (_, GoRouterState state) =>
              PersonDetailPage(personId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: settingsRoute,
          builder: (_, GoRouterState state) => SettingsPage(
            initialFocus: SettingsFocusTarget.tryParse(
              state.uri.queryParameters[SettingsFocusTarget.queryKey],
            ),
          ),
        ),
        GoRoute(path: aboutRoute, builder: (_, _) => const SettingsAboutPage()),
        GoRoute(
          path: personalizationRoute,
          builder: (_, _) => const PersonalizationPage(),
        ),
        GoRoute(path: supportRoute, builder: (_, _) => const SupportPage()),
      ],
    );
  }
}
