import 'package:go_router/go_router.dart';

import '../features/editor/pages/editor_page.dart';
import '../features/home/pages/home_page.dart';
import '../features/settings/pages/about_page.dart';
import '../features/settings/pages/personalization_page.dart';
import '../features/settings/pages/settings_page.dart';
import '../features/settings/pages/support_page.dart';

/// 應用程式中央路由。
///
/// 路由集中管理，功能頁面位於各自模組內。
class AppRouter {
  static const String homeRoute = '/';
  static const String editorRoute = '/editor';
  static const String editorDetailRoute = '/editor/:entryId';
  static const String settingsRoute = '/settings';
  static const String aboutRoute = '/settings/about';
  static const String personalizationRoute = '/settings/personalization';
  static const String supportRoute = '/settings/support';
  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: homeRoute,
      routes: <RouteBase>[
        GoRoute(path: homeRoute, builder: (_, _) => const HomePage()),
        GoRoute(path: editorRoute, builder: (_, _) => const EditorPage()),
        GoRoute(
          path: editorDetailRoute,
          builder: (_, GoRouterState state) => EditorPage(
            entryId: state.pathParameters['entryId'],
            startInEditMode: state.uri.queryParameters['edit'] == '1',
          ),
        ),
        GoRoute(path: settingsRoute, builder: (_, _) => const SettingsPage()),
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
