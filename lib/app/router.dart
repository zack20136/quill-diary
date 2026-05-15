import 'package:go_router/go_router.dart';

import '../features/editor/pages/editor_page.dart';
import '../features/home/pages/home_page.dart';
import '../features/settings/pages/settings_page.dart';

class AppRouter {
  static const String homeRoute = '/';
  static const String editorRoute = '/editor';
  static const String editorDetailRoute = '/editor/:entryId';
  static const String settingsRoute = '/settings';

  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: homeRoute,
      routes: <RouteBase>[
        GoRoute(
          path: homeRoute,
          builder: (_, _) => const HomePage(),
        ),
        GoRoute(
          path: editorRoute,
          builder: (_, _) => const EditorPage(),
        ),
        GoRoute(
          path: editorDetailRoute,
          builder: (_, GoRouterState state) =>
              EditorPage(entryId: state.pathParameters['entryId']),
        ),
        GoRoute(
          path: settingsRoute,
          builder: (_, _) => const SettingsPage(),
        ),
      ],
    );
  }
}
