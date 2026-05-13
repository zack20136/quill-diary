import 'package:go_router/go_router.dart';

import '../presentation/pages/editor_page.dart';
import '../presentation/pages/home_page.dart';
import '../presentation/pages/recovery_page.dart';

class AppRouter {
  static const String homeRoute = '/';
  static const String editorRoute = '/editor';
  static const String recoveryRoute = '/recovery';
  static const String editorDetailRoute = '/editor/:entryId';

  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: homeRoute,
      routes: <RouteBase>[
        GoRoute(
          path: homeRoute,
          builder: (_, __) => const HomePage(),
        ),
        GoRoute(
          path: editorRoute,
          builder: (_, __) => const EditorPage(),
        ),
        GoRoute(
          path: editorDetailRoute,
          builder: (_, GoRouterState state) =>
              EditorPage(entryId: state.pathParameters['entryId']),
        ),
        GoRoute(
          path: recoveryRoute,
          builder: (_, __) => const RecoveryPage(),
        ),
      ],
    );
  }
}
