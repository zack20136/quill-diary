import 'package:go_router/go_router.dart';

import '../presentation/editor/pages/editor_page.dart';
import '../presentation/home/pages/home_page.dart';
import '../presentation/people/pages/person_detail_page.dart';
import '../presentation/settings/pages/about_page.dart';
import '../presentation/settings/pages/personalization_page.dart';
import '../presentation/settings/pages/settings_page.dart';
import '../presentation/settings/pages/support_page.dart';

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

  static String personDetailLocation(String id) => '/people/$id';

  static String editorEditLocation(String entryId) => '/editor/$entryId?edit=1';
  static String editorSalvageLocation(String token) => '/editor?salvage=$token';

  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: homeRoute,
      routes: <RouteBase>[
        GoRoute(path: homeRoute, builder: (_, _) => const HomePage()),
        GoRoute(
          path: editorRoute,
          builder: (_, GoRouterState state) => EditorPage(
            salvageToken: state.uri.queryParameters['salvage'],
            startInEditMode: state.uri.queryParameters['salvage'] != null,
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
