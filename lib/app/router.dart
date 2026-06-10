import 'package:go_router/go_router.dart';

import '../features/editor/pages/editor_page.dart';
import '../features/home/pages/home_page.dart';
import '../features/settings/pages/about_page.dart';
import '../features/settings/pages/settings_page.dart';
import '../features/settings/pages/privacy_page.dart';
import '../features/settings/pages/support_page.dart';

/// Central application routes.
///
/// The app keeps routing concerns in one place while feature pages live inside
/// their own modules.
class AppRouter {
  static const String homeRoute = '/';
  static const String editorRoute = '/editor';
  static const String editorDetailRoute = '/editor/:entryId';
  static const String settingsRoute = '/settings';
  static const String aboutRoute = '/settings/about';
  static const String supportRoute = '/settings/support';
  static const String privacyRoute = '/settings/privacy';

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
          builder: (_, GoRouterState state) => EditorPage(
            entryId: state.pathParameters['entryId'],
            startInEditMode: state.uri.queryParameters['edit'] == '1',
          ),
        ),
        GoRoute(
          path: settingsRoute,
          builder: (_, _) => const SettingsPage(),
        ),
        GoRoute(
          path: aboutRoute,
          builder: (_, _) => const SettingsAboutPage(),
        ),
        GoRoute(
          path: supportRoute,
          builder: (_, _) => const SupportPage(),
        ),
        GoRoute(
          path: privacyRoute,
          builder: (_, _) => const PrivacyPage(),
        ),
      ],
    );
  }
}
